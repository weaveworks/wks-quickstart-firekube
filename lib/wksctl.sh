# shellcheck shell=bash

wksctl_help() {
    echo "firekube needs wksctl to install Kubernetes."
    echo ""
    echo "Please install wksctl version ${WKSCTL_VERSION} or later:"
    echo ""
    echo "  • GitHub project  : https://github.com/weaveworks/wksctl"
    echo "  • Latest release  : https://github.com/weaveworks/wksctl/releases"
    echo "  • Installation    : https://github.com/weaveworks/wksctl/#install-wksctl"
    echo "  • Required version: ${WKSCTL_VERSION}"
}

wksctl_download() {
    local cmd="${1}"
    local version="${2}"

    do_curl_tarball "${cmd}" "https://github.com/weaveworks/wksctl/releases/download/v${version}/wksctl-${version}-$(goos)-$(arch).tar.gz"
}

wksctl_version() {
    local cmd="wksctl"
    local req="${1}"
    local version

    if ! version="$("${cmd}" version | sed -n -e 's#^\(.*\)#\1#p')" || [ -z "${version}" ]; then
        help "${cmd}" "error running '${cmd} version'."
    fi

    if [ "${version}" == "undefined" ]; then
        log "${cmd}: detected git build, continuing"
        return
    fi

    version_check "${cmd}" "${version}" "${req}"
}
