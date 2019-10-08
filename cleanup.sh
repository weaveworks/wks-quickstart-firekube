#!/usr/bin/env bash
unset CDPATH
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "${SCRIPT_DIR}" || exit 1

set -euo pipefail

log() {
    echo "•" $*
}

log "Deleting virtual machines"
export PATH=~/.wks/bin:$PATH
sudo env "PATH=$PATH" footloose delete
