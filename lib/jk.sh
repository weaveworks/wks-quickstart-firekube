# shellcheck shell=bash

jk_help() {
    echo "firekube needs jk to generate configuration manifests."
    echo ""
    echo "Please install jk version ${JK_VERSION} or later:"
    echo ""
    echo "  • GitHub project  : https://github.com/jkcfg/jk"
    echo "  • Latest release  : https://github.com/jkcfg/jk/releases"
    echo "  • Installation    : https://github.com/jkcfg/jk#quick-start"
    echo "  •                 : https://jkcfg.github.io/#/documentation/quick-start"
    echo "  • Required version: ${JK_VERSION}"
}

jk_download() {
    local cmd="${1}"
    local version="${2}"

     do_curl_binary "${cmd}" "https://github.com/jkcfg/jk/releases/download/${version}/jk-$(goos)-$(goarch)"
}

jk_version() {
    local cmd="jk"
    local req="${1}"
    local version

    if ! version="$("${cmd}" version | sed -n -e 's#^version: \(.*\)#\1#p')" || [ -z "${version}" ]; then
        help jk "error running '${cmd} version'."
    fi

    version_check "${cmd}" "${version}" "${req}"
}

