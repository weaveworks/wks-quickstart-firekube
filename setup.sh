#!/usr/bin/env bash

set -euo pipefail

JK_VERSION=0.3.0
FOOTLOOSE_VERSION=0.6.1
IGNITE_VERSION=0.5.3
WKSCTL_VERSION=0.8.0-beta.1

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

goos() {
    local os=$(uname -s)
    case $os in
    Linux*)
        echo linux;;
    Darwin*)
        echo darwin;;
    *)
        error "unknown OS: ${os}";;
    esac
}

arch() {
    echo $(uname -m)
}

goarch() {
    local arch=$(uname -m)
    case $arch in
    armv5*)
        echo "armv5";;
    armv6*)
        echo "armv6";;
    armv7*)
        echo "armv7";;
    aarch64)
        echo "arm64";;
    x86)
        echo "386";;
    x86_64)
        echo "amd64";;
    i686)
        echo "386";;
    i386)
        echo "386";;
    *)
        error "uknown arch: ${arch}";;
    esac
}

mktempdir() {
    echo `mktemp -d 2>/dev/null || mktemp -d -t 'firekube'`
}

do_curl() {
    local path=$1
    local url=$2

    log "Downloading $url"
    curl --progress-bar -fLo $path $url
}

do_curl_binary() {
    local cmd=$1
    local url=$2

    do_curl ~/.wks/bin/$cmd $url
    chmod +x ~/.wks/bin/$cmd
}

do_curl_tarball() {
    local cmd=$1
    local url=$2

    dldir=$(mktempdir)
    mkdir $dldir/$cmd
    do_curl $dldir/$cmd.tar.gz https://github.com/weaveworks/wksctl/releases/download/${version}/wksctl-${version}-$(goos)-$(arch).tar.gz
    tar -C $dldir/$cmd -xvf $dldir/$cmd.tar.gz
    mv $dldir/$cmd/$cmd ~/.wks/bin/$cmd
    rm -rf $dldir
}

clean_version() {
    echo $1 | sed -n -e 's#^\([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\).*#\1#p'
}

# Given $1 and $2 as semantic version numbers like 3.1.2, return [ $1 < $2 ]
version_lt() {
    # clean up the version string
    local a=$(clean_version $1)
    local b=$(clean_version $2)

    VERSION_MAJOR=${a%.*.*}
    REST=${a%.*} VERSION_MINOR=${REST#*.}
    VERSION_PATCH=${a#*.*.}

    MIN_VERSION_MAJOR=${b%.*.*}
    REST=${b%.*} MIN_VERSION_MINOR=${REST#*.}
    MIN_VERSION_PATCH=${b#*.*.}

    if [ \( "$VERSION_MAJOR" -lt "$MIN_VERSION_MAJOR" \) -o \
        \( "$VERSION_MAJOR" -eq "$MIN_VERSION_MAJOR" -a \
        \( "$VERSION_MINOR" -lt "$MIN_VERSION_MINOR" -o \
        \( "$VERSION_MINOR" -eq "$MIN_VERSION_MINOR" -a \
        \( "$VERSION_PATCH" -lt "$MIN_VERSION_PATCH" \) \) \) \) ] ; then
        return 0
    fi
    return 1
}

download() {
    local cmd=$1
    local version=$2

    eval ${cmd}_download $cmd $version
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

footloose_download() {
    local cmd=$1
    local version=$2

    os=$(goos)
    case $os in
    linux)
        do_curl_binary $cmd https://github.com/weaveworks/footloose/releases/download/${version}/footloose-${version}-${os}-$(arch)
        ;;
    darwin)
        do_curl_tarball $cmd https://github.com/weaveworks/footloose/releases/download/${version}/footloose-${version}-${os}-$(arch).tar.gz
        ;;
    *)
        error "unknown OS: $os"
        ;;
    esac
}

footloose_version() {
    local cmd="footloose"
    local req=$1
    local version

    if ! version=$($cmd version | sed -n -e 's#^version: \([0-9g][0-9\.it]*\)$#\1#p') || [ -z "$version" ]; then
        help $cmd "error running '$cmd version'."
    fi

    if [ "$version" == "git" ]; then
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

ignite_download() {
    local cmd=$1
    local version=$2

    do_curl_binary $cmd https://github.com/weaveworks/ignite/releases/download/v${version}/ignite-$(goarch)
}

ignite_version() {
    local cmd="ignite"
    local req=$1
    local version

    if ! version=$($cmd version -o short | sed -n -e 's#^v\(.*\)#\1#p') || [ -z "$version" ]; then
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

jk_download() {
    local cmd=$1
    local version=$2

     do_curl_binary $cmd https://github.com/jkcfg/jk/releases/download/${version}/jk-$(goos)-$(goarch)
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

wksctl_download() {
    local cmd=$1
    local version=$2

    do_curl_tarball $cmd https://github.com/weaveworks/wksctl/releases/download/${version}/wksctl-${version}-$(goos)-$(arch).tar.gz
}

wksctl_version() {
    local cmd="wksctl"
    local req=$1
    local version

    if ! version=$($cmd version | sed -n -e 's#^\(.*\)#\1#p') || [ -z "$version" ]; then
        help $cmd "error running '$cmd version'."
    fi

    if [ "$version" == "undefined" ]; then
        log "$cmd: detected git build, continuing"
        return
    fi

    version_check $cmd $version $req
}

check_version() {
    local cmd=$1
    local req=$2

    if ! command_exists $cmd || [ $download_force == "yes" ]; then
        if [ $download == "yes" ]; then
            download $cmd $req
        else
            log "$cmd: command not found"
            eval ${cmd}_help
            exit 1
        fi
    fi

    eval ${cmd}_version $req
}

git_ssh_url() {
    echo $1 | sed -e 's#^https://github.com/#git@github.com:#'
}

git_http_url() {
    echo $1 | sed -e 's#^git@github.com:#https://github.com/#'
}

config_backend() {
    sed -n -e 's/^backend: *\(.*\)/\1/p' config.yaml
}

set_config_backend() {
    sed -i -e "s/^backend: .*$/backend: $1/" config.yaml
}

git_deploy_key=""
download="yes"
download_force="no"

while test $# -gt 0; do
    case $1 in
    --no-download)
        download="no"
        ;;
    --force-download)
        download_force="yes"
        ;;
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

if [ $download == "yes" ]; then
    mkdir -p ~/.wks/bin
    export PATH=~/.wks/bin:$PATH
fi

# On macOS, we only support the docker backend.
if [ $(goos) == "darwin" ]; then
    set_config_backend docker
fi

check_command docker
check_version jk $JK_VERSION
check_version footloose $FOOTLOOSE_VERSION
sudo=""
if [ $(config_backend) == "ignite" ]; then
    sudo="sudo env PATH=$PATH";
    check_version ignite $IGNITE_VERSION
fi
check_version wksctl $WKSCTL_VERSION

log "Creating footloose manifest"
jk generate -f config.yaml setup.js

cluster_key="cluster-key"
if [ ! -f "$cluster_key" ]; then
    # Create the cluster ssh key with the user credentials.
    log "Creating SSH key"
    ssh-keygen -q -t rsa -b 4096 -C firekube@footloose.mail -f $cluster_key -N ""
fi

log "Creating virtual machines"
$sudo footloose create

log "Creating Cluster API manifests"
status=footloose-status.yaml
$sudo footloose status -o json > $status
jk generate -f config.yaml -f $status setup.js
rm -f $status

log "Updating container images and git parameters"
wksctl init --git-url=$(git_http_url $(git config --get remote.origin.url)) --git-branch=$(git rev-parse --abbrev-ref HEAD)

log "Pushing initial cluster configuration"
git add footloose.yaml machines.yaml flux.yaml wks-controller.yaml

git diff-index --quiet HEAD || git commit -m "Initial cluster configuration"
git push

log "Installing Kubernetes cluster"
wksctl apply --git-url=$(git_http_url $(git config --get remote.origin.url)) --git-branch=$(git rev-parse --abbrev-ref HEAD) $git_deploy_key
wksctl kubeconfig
