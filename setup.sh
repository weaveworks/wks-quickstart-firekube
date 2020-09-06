#!/usr/bin/env bash
unset CDPATH
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "${SCRIPT_DIR}" || exit 1

. lib/functions.sh

. lib/footloose.sh
. lib/ignite.sh
. lib/jk.sh
. lib/wksctl.sh

# user-overrideable via ENV
if command -v sudo >/dev/null 2>&1; then
    sudo="${sudo:-"sudo"}"
else
    sudo="${sudo}"
fi

set -euo pipefail

JK_VERSION=0.3.0
FOOTLOOSE_VERSION=0.6.3
IGNITE_VERSION=0.7.1
WKSCTL_VERSION=0.8.4

config_backend() {
    sed -n -e 's/^backend: *\(.*\)/\1/p' config.yaml
}

set_config_backend() {
    local tmp=.config.yaml.tmp

    sed -e "s/^backend: .*$/backend: ${1}/" config.yaml > "${tmp}" && \
        mv "${tmp}" config.yaml && \
        rm -f "${tmp}"
}

do_footloose() {
    if [ "$(config_backend)" == "ignite" ]; then
        $sudo env "PATH=${PATH}" footloose "${@}"
    else
        footloose "${@}"
    fi
}

if git_current_branch > /dev/null 2>&1; then
    log "Using git branch: $(git_current_branch)"
else
    error "Please checkout a git branch."
fi

git_remote="$(git config --get "branch.$(git_current_branch).remote" || true)" # fallback to "", user may override
git_deploy_key=""
download="yes"
download_force="no"

setup_help() {
    echo "
    setup.sh

    - ensure dependent binaries are available
    - generate a cluster config
    - bootstrap the gitops cluster
    - push the changes to the remote for the cluster to pick up

    optional flags:
        --no-download                 Do not download dependent binaries
        --force-download              Force downloading version-specific dependent binaries
        --git-remote       string     Override the remote used for pushing changes and configuring the cluster
        --git-deploy-key   filepath   Provide a deploy key for private/authenticated repo access
        -h, -help                     Print this help text
    "
}
while test $# -gt 0; do
    case "${1}" in
    --no-download)
        download="no"
        ;;
    --force-download)
        download_force="yes"
        ;;
    --git-remote)
        shift
        git_remote="${1}"
        ;;
    --git-deploy-key)
        shift
        git_deploy_key="--git-deploy-key=${1}"
        log "Using git deploy key: ${1}"
        ;;
    -h|--help)
        setup_help
        exit 0
        ;;
    *)
        setup_help
        error "unknown argument '${1}'"
        ;;
    esac
    shift
done

if [ "${git_remote}" ]; then
    log "Using git remote: ${git_remote}"
else
    error "
Please configure a remote for your current branch:
    git branch --set-upstream-to <remote_name>/$(git_current_branch)

Or use the --git-remote flag:
    ./setup.sh --git-remote <remote_name>

Your repo has the following remotes:
$(git remote -v)"
fi
echo

if [ "${download}" == "yes" ]; then
    mkdir -p "${HOME}/.wks/bin"
    export PATH="${HOME}/.wks/bin:${PATH}"
fi

# On macOS, we only support the docker backend.
if [ "$(goos)" == "darwin" ]; then
    set_config_backend docker
fi

check_command docker
check_version jk "${JK_VERSION}"
check_version footloose "${FOOTLOOSE_VERSION}"
if [ "$(config_backend)" == "ignite" ]; then
    check_version ignite "${IGNITE_VERSION}"
fi
check_version wksctl "${WKSCTL_VERSION}"

log "Creating footloose manifest"
jk generate -f config.yaml setup.js

cluster_key="cluster-key"
if [ ! -f "${cluster_key}" ]; then
    # Create the cluster ssh key with the user credentials.
    log "Creating SSH key"
    ssh-keygen -q -t rsa -b 4096 -C firekube@footloose.mail -f ${cluster_key} -N ""
fi

log "Creating virtual machines"
do_footloose create

log "Creating Cluster API manifests"
status="footloose-status.yaml"
do_footloose status -o json > "${status}"
jk generate -f config.yaml -f "${status}" setup.js
rm -f "${status}"

log "Updating container images and git parameters"
wksctl init --git-url="$(git_http_url "$(git_remote_fetchurl "${git_remote}")")" --git-branch="$(git_current_branch)"

log "Pushing initial cluster configuration"
git add config.yaml footloose.yaml machines.yaml flux.yaml wks-controller.yaml

git diff-index --quiet HEAD || git commit -m "Initial cluster configuration"
git push "${git_remote}" HEAD

log "Installing Kubernetes cluster"
apply_args=(
  "--git-url=$(git_http_url "$(git_remote_fetchurl "${git_remote}")")"
  "--git-branch=$(git_current_branch)"
)
[ "${git_deploy_key}" ] && apply_args+=("${git_deploy_key}")
wksctl apply "${apply_args[@]}"
wksctl kubeconfig
