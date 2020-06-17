# shellcheck shell=bash

log() {
    echo "•" "$@"
}

error() {
    log "error:" "$@"
    exit 1
}

command_exists() {
    command -v "${1}" >/dev/null 2>&1
}

check_command() {
    local cmd="${1}"

    if ! command_exists "${cmd}"; then
        error "${cmd}: command not found, please install ${cmd}."
    fi
}

goos() {
    local os
    os="$(uname -s)"
    case "${os}" in
    Linux*)
        echo linux;;
    Darwin*)
        echo darwin;;
    *)
        error "unknown OS: ${os}";;
    esac
}

arch() {
    uname -m
}

goarch() {
    local arch
    arch="$(uname -m)"
    case "${arch}" in
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
    mktemp -d 2>/dev/null || mktemp -d -t 'firekube'
}

do_curl() {
    local path="${1}"
    local url="${2}"

    log "Downloading ${url}"
    curl --progress-bar -fLo "${path}" "${url}"
}

do_curl_binary() {
    local cmd="${1}"
    local url="${2}"

    do_curl "${HOME}/.wks/bin/${cmd}" "${url}"
    chmod +x "${HOME}/.wks/bin/${cmd}"
}

do_curl_tarball() {
    local cmd="${1}"
    local url="${2}"

    dldir="$(mktempdir)"
    mkdir "${dldir}/${cmd}"
    do_curl "${dldir}/${cmd}.tar.gz" "${url}"
    tar -C "${dldir}/${cmd}" -xvf "${dldir}/${cmd}.tar.gz"
    mv "${dldir}/${cmd}/${cmd}" "${HOME}/.wks/bin/${cmd}"
    rm -rf "${dldir}"
}

clean_version() {
    echo "${1}" | sed -n -e 's#^\([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\).*#\1#p'
}

# Given "${1}" and $2 as semantic version numbers like 3.1.2, return [ "${1}" < $2 ]
version_lt() {
    # clean up the version string
    local a
    a="$(clean_version "${1}")"
    local b
    b="$(clean_version "${2}")"

    A_MAJOR="${a%.*.*}"
    REST="${a%.*}" A_MINOR="${REST#*.}"
    A_PATCH="${a#*.*.}"

    B_MAJOR="${b%.*.*}"
    REST="${b%.*}" B_MINOR="${REST#*.}"
    B_PATCH="${b#*.*.}"

    [ "${A_MAJOR}" -lt "${B_MAJOR}" ] && return 0
    [ "${A_MAJOR}" -gt "${B_MAJOR}" ] && return 1

    [ "${A_MINOR}" -lt "${B_MINOR}" ] && return 0
    [ "${A_MINOR}" -gt "${B_MINOR}" ] && return 1

    [ "${A_PATCH}" -lt "${B_PATCH}" ]
}

download() {
    local cmd="${1}"
    local version="${2}"

    eval "${cmd}_download" "${cmd}" "${version}"
}

help() {
    local cmd="${1}"
    shift
    log "error: ${cmd}:" "$@"
    echo
    eval "${cmd}_help"
    exit 1
}

version_check() {
    local cmd="${1}"
    local version="${2}"
    local req="${3}"

    log "Found ${cmd} ${version}"

    if version_lt "${version}" "${req}";  then
        help "${cmd}" "Found version ${version} but ${req} is the minimum required version."
    fi
}

check_version() {
    local cmd="${1}"
    local req="${2}"

    if ! command_exists "${cmd}" || [ "${download_force}" == "yes" ]; then
        if [ "${download}" == "yes" ]; then
            download "${cmd}" "${req}"
        else
            log "${cmd}: command not found"
            eval "${cmd}_help"
            exit 1
        fi
    fi

    eval "${cmd}_version" "${req}"
}

git_ssh_url() {
    # shellcheck disable=SC2001
    echo "${1}" | sed -e 's#^https://github.com/#git@github.com:#'
}

git_http_url() {
    # shellcheck disable=SC2001
    echo "${1}" | sed -e 's#^git@github.com:#https://github.com/#'
}

git_current_branch() {
    # Fails when not on a branch unlike: `git name-rev --name-only HEAD`
    git symbolic-ref --short HEAD
}

git_remote_fetchurl() {
    git config --get "remote.${1}.url"
}

parse_yaml() {
   local prefix=$2
   local s='[[:space:]]*' w='[a-zA-Z0-9_]*' fs=$(echo @|tr @ '\034')
   sed -ne "s|^\($s\)\($w\)$s:$s\"\(.*\)\"$s\$|\1$fs\2$fs\3|p" \
        -e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1$fs\2$fs\3|p"  $1 |
   awk -F$fs '{
      indent = length($1)/2;
      vname[indent] = $2;
      for (i in vname) {if (i > indent) {delete vname[i]}}
      if (length($3) > 0) {
         vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("_")}
         printf("%s%s%s=\"%s\"\n", "'$prefix'", vn, $2, $3);
      }
   }'
}

set_config_backend() {
    local tmp=.config.yaml.tmp

    sed -e "s/^backend: .*$/backend: ${1}/" config.yaml > "${tmp}" && \
        mv "${tmp}" config.yaml && \
        rm -f "${tmp}"
}

set_docker_version() {
    local tmp=.config.yaml.tmp

    sed -e "s/\bversion: .*$/version: ${1}/" cluster.yaml > "${tmp}" && \
        mv "${tmp}" cluster.yaml && \
        rm -f "${tmp}"
}

do_footloose() {
    if [ "$config_backend" == "ignite" ]; then
        $sudo env "PATH=${PATH}" footloose "${@}"
    else
        footloose "${@}"
    fi
}

set_wksctl_version() {
    local tmp=.config.yaml.tmp

    awk -v repl="image: ${1}" '/image:/ && /wksctl/ {
        sub(/image.*/, repl) } 1' wks-controller.yaml > "${tmp}" && \
        mv "${tmp}" wks-controller.yaml && \
        rm -f "${tmp}"
}

set_flux_version() {
    local tmp=.config.yaml.tmp

    awk -v repl="image: ${1}" '/image:/ && /memcached/ {
        sub(/image.*/, repl) } 1' flux.yaml > "${tmp}" && \
        mv "${tmp}" flux.yaml && \
        rm -f "${tmp}"
    awk -v repl="image: ${2}" '/image:/ && /flux/ {
        sub(/image.*/, repl) } 1' flux.yaml > "${tmp}" && \
        mv "${tmp}" flux.yaml && \
        rm -f "${tmp}"
    awk -v repl="git-url=${3}" '/git-url=/ {
        sub(/git-url=.*/, repl) } 1' flux.yaml > "${tmp}" && \
        mv "${tmp}" flux.yaml && \
        rm -f "${tmp}"
}
