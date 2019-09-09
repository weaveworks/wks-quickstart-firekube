#!/usr/bin/env bash

set -euo pipefail

JK_VERSION=0.3.0
FOOTLOOSE_VERSION=0.6.0
IGNITE_VERSION=0.5.2
WKSCTL_VERSION=0.7.0

log() {
    echo "•" $*
}

error() {
    log "error:" $*
    exit 1
}

command_exists() {
    command -v $1 >/dev/null 2>&1
}

check_command() {
    local cmd=$1

    if ! command_exists $cmd; then
        error "$cmd: command not found, please install $cmd."
    fi
}

# Given $1 and $2 as semantic version numbers like 3.1.2, return [ $1 < $2 ]
version_lt() {
    VERSION_MAJOR=${1%.*.*}``
    REST=${1%.*} VERSION_MINOR=${REST#*.}
    # strip garbage after the patch version
    VERSION_PATCH=$(echo ${1#*.*.} | sed -n -e 's#\([0-9][0-9]*\).*#\1#p')

    MIN_VERSION_MAJOR=${2%.*.*}
    REST=${2%.*} MIN_VERSION_MINOR=${REST#*.}
    MIN_VERSION_PATCH=${2#*.*.}

    if [ \( "$VERSION_MAJOR" -lt "$MIN_VERSION_MAJOR" \) -o \
        \( "$VERSION_MAJOR" -eq "$MIN_VERSION_MAJOR" -a \
        \( "$VERSION_MINOR" -lt "$MIN_VERSION_MINOR" -o \
        \( "$VERSION_MINOR" -eq "$MIN_VERSION_MINOR" -a \
        \( "$VERSION_PATCH" -lt "$MIN_VERSION_PATCH" \) \) \) \) ] ; then
        return 0
    fi
    return 1
}

help() {
    local cmd=$1
    shift
    log "error: $cmd:" $*
    echo
    eval ${cmd}_help
    exit 1
}

version_check() {
    local cmd=$1
    local version=$2
    local req=$3

    log "Found $cmd $version"

    if version_lt $version $req;  then
        help $cmd "Found version $version but $req is the minimum required version."
    fi
}

footloose_help() {
    echo "firekube requires footloose to spawn VMs that will be used as Kubernetes nodes."
    echo ""
    echo "Please install footloose version $FOOTLOOSE_VERSION or later:"
    echo ""
    echo "  • GitHub project  : https://github.com/weaveworks/footloose"
    echo "  • Latest release  : https://github.com/weaveworks/footloose/releases"
    echo "  • Installation    : https://github.com/weaveworks/footloose#install"
    echo "  • Required version: $FOOTLOOSE_VERSION"
}

footloose_version() {
    local cmd="footloose"
    local req=$1
    local version

    if ! version=$($cmd version | sed -n -e 's#^version: \(.*\)#\1#p') || [ -z "$version" ]; then
        help $cmd "error running '$cmd version'."
    fi

    if [ $version == "git" ]; then
        log "$cmd: detected git build, continuing"
        return
    fi

    version_check $cmd $version $req
}

ignite_help() {
    echo "firekube with the ignite backend requires ignite to spawn VMs that will be used as Kubernetes nodes."
    echo ""
    echo "Please install ignite version $IGNITE_VERSION or later:"
    echo ""
    echo "  • GitHub project  : https://github.com/weaveworks/ignite"
    echo "  • Latest release  : https://github.com/weaveworks/ignite/releases"
    echo "  • Installation    : https://github.com/weaveworks/ignite#installing"
    echo "  • Required version: $IGNITE_VERSION"
}

ignite_version() {
    local cmd="ignite"
    local req=$1
    local version

    # ignite currently needs root permissions, even to display its version
    # https://github.com/weaveworks/ignite/issues/406
    if ! version=$(sudo $cmd version -o short | sed -n -e 's#^v\(.*\)#\1#p') || [ -z "$version" ]; then
        help $cmd "error running '$cmd version'."
    fi

    version_check $cmd $version $req
}

jk_help() {
    echo "firekube needs jk to generate configuration manifests."
    echo ""
    echo "Please install jk version $JK_VERSION or later:"
    echo ""
    echo "  • GitHub project  : https://github.com/jkcfg/jk"
    echo "  • Latest release  : https://github.com/jkcfg/jk/releases"
    echo "  • Installation    : https://github.com/jkcfg/jk#quick-start"
    echo "  •                 : https://jkcfg.github.io/#/documentation/quick-start"
    echo "  • Required version: $JK_VERSION"
}

jk_version() {
    local cmd="jk"
    local req=$1
    local version

    if ! version=$($cmd version | sed -n -e 's#^version: \(.*\)#\1#p') || [ -z "$version" ]; then
        help jk "error running '$cmd version'."
    fi

    version_check $cmd $version $req
}

wksctl_help() {
    echo "firekube needs wksctl to install Kubernetes."
    echo ""
    echo "Please install wksctl version $WKSCTL_VERSION or later:"
    echo ""
    echo "  • GitHub project  : https://github.com/weaveworks/wksctl"
    echo "  • Latest release  : https://github.com/weaveworks/wksctl/releases"
    echo "  • Installation    : https://github.com/weaveworks/wksctl/#install-wksctl"
    echo "  • Required version: $WKSCTL_VERSION"
}

wksctl_version() {
    local cmd="wksctl"
    local req=$1
    local version

    if ! version=$($cmd version | sed -n -e 's#^\(.*\)#\1#p') || [ -z "$version" ]; then
        help $cmd "error running '$cmd version'."
    fi

    if [ $version == "undefined" ]; then
        log "$cmd: detected git build, continuing"
        return
    fi

    version_check $cmd $version $req
}

check_version() {
    local cmd=$1
    local req=$2

    if ! command_exists $cmd; then
        log "$cmd: command not found"
        eval ${cmd}_help
        exit 1
    fi

    eval ${cmd}_version $req
}

config_backend() {
    sed -n -e 's/^backend: *\(.*\)/\1/p' config.yaml
}

git_deploy_key=""

while test $# -gt 0; do
    case $1 in
    --git-deploy-key)
        shift
        git_deploy_key="--git-deploy-key $1"
        log "Using git deploy key: $1"
        ;;
    *)
        error "unknown argument '$arg'"
        ;;
    esac
    shift
done

check_command docker
check_version jk $JK_VERSION
check_version footloose $FOOTLOOSE_VERSION
if [ $(config_backend) == "ignite" ]; then
    check_version ignite $IGNITE_VERSION
fi
check_version wksctl $WKSCTL_VERSION

log "Creating footloose manifest"
jk generate -f config.yaml setup.js

sudo=""
if [ $(config_backend) == "ignite" ]; then
    sudo="sudo env PATH=$PATH";
fi

log "Creating virtual machines"
$sudo footloose create

log "Creating Cluster API manifests"
status=footloose-status.yaml
$sudo footloose status -o json > $status
jk generate -f config.yaml -f $status setup.js
rm -f $status

log "Pushing initial cluster configuration"
git add footloose.yaml machines.yaml
git diff-index --quiet HEAD || git commit -m "Initial cluster configuration"
git push

log "Installing Kubernetes cluster"
wksctl apply --git-url $(git config --get remote.origin.url) --git-branch=$( git rev-parse --abbrev-ref HEAD) $git_deploy_key
wksctl kubeconfig
