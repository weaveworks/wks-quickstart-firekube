#!/usr/bin/env bash
unset CDPATH
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "${SCRIPT_DIR}" || exit 1

. lib/functions.sh

# user-overrideable via ENV
if command -v sudo >/dev/null 2>&1; then
    sudo="${sudo:-"sudo"}"
else
    sudo="${sudo}"
fi

set -euo pipefail

config_backend() {
    sed -n -e 's/^backend: *\(.*\)/\1/p' config.yaml
}

do_footloose() {
    if [ "$(config_backend)" == "ignite" ]; then
        $sudo env "PATH=${PATH}" footloose "${@}"
    else
        footloose "${@}"
    fi
}

log "Deleting virtual machines"
export PATH=~/.wks/bin:${PATH}
do_footloose delete
