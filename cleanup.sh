#!/usr/bin/env bash

set -euo pipefail

log() {
    echo "•" $*
}

log "Deleting virtual machines"
export PATH=~/.wks/bin:$PATH
sudo env "PATH=$PATH" footloose delete
