#!/usr/bin/env bash

set -euo pipefail

log() {
    echo "•" $*
}

log "Deleting virtual machines"
curl -XDELETE http://172.17.0.1:5555/api/clusters/firekube
