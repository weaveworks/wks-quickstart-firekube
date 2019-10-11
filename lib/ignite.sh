# shellcheck shell=bash

ignite_help() {
    echo "firekube with the ignite backend requires ignite to spawn VMs that will be used as Kubernetes nodes."
    echo ""
    echo "Please install ignite version ${IGNITE_VERSION} or later:"
    echo ""
    echo "  • GitHub project  : https://github.com/weaveworks/ignite"
    echo "  • Latest release  : https://github.com/weaveworks/ignite/releases"
    echo "  • Installation    : https://github.com/weaveworks/ignite#installing"
    echo "  • Required version: ${IGNITE_VERSION}"
}

ignite_download() {
    local cmd="${1}"
    local version="${2}"

    do_curl_binary "${cmd}" "https://github.com/weaveworks/ignite/releases/download/v${version}/ignite-$(goarch)"
}

ignite_version() {
    local cmd="ignite"
    local req="${1}"
    local version

    if ! version="$("${cmd}" version -o short | sed -n -e 's#^v\(.*\)#\1#p')" || [ -z "${version}" ]; then
        help "${cmd}" "error running '${cmd} version'."
    fi

    version_check "${cmd}" "${version}" "${req}"
}

