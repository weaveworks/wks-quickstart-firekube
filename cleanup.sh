#!/usr/bin/env bash

# user-overrideable via ENV
if command -v sudo >/dev/null 2>&1; then
    sudo="${sudo:-"sudo"}"
else
    sudo="${sudo}"
fi

set -euo pipefail

log() {
    echo "•" $*
}

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
