#!/usr/bin/env bash

set -euo pipefail

log() {
    echo "•" $*
}

log "Deleting virtual machines"
curl -XDELETE http://$(ps -ef | grep foot | grep -v grep | awk '{print $11}')/api/clusters/firekube
