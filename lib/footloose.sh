# shellcheck shell=bash

footloose_help() {
    echo "firekube requires footloose to spawn VMs that will be used as Kubernetes nodes."
    echo ""
    echo "Please install footloose version ${FOOTLOOSE_VERSION} or later:"
    echo ""
    echo "  • GitHub project  : https://github.com/weaveworks/footloose"
    echo "  • Latest release  : https://github.com/weaveworks/footloose/releases"
    echo "  • Installation    : https://github.com/weaveworks/footloose#install"
    echo "  • Required version: ${FOOTLOOSE_VERSION}"
}

footloose_download() {
    local cmd="${1}"
    local version="${2}"

    os="$(goos)"
    case "${os}" in
    linux)
        do_curl_binary "${cmd}" "https://github.com/weaveworks/footloose/releases/download/${version}/footloose-${version}-${os}-$(arch)"
        ;;
    darwin)
        do_curl_tarball "${cmd}" "https://github.com/weaveworks/footloose/releases/download/${version}/footloose-${version}-${os}-$(arch).tar.gz"
        ;;
    *)
        error "unknown OS: ${os}"
        ;;
    esac
}

footloose_version() {
    local cmd="footloose"
    local req="${1}"
    local version

    if ! version="$("${cmd}" version | sed -n -e 's#^version: \([0-9g][0-9\.it]*\)$#\1#p')" || [ -z "${version}" ]; then
        help "${cmd}" "error running '${cmd} version'."
    fi

    if [ "${version}" == "git" ]; then
        log "${cmd}: detected git build, continuing"
        return
    fi

    version_check "${cmd}" "${version}" "${req}"
}
