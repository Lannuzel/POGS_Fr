#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${POGS_LOG_DIR:-/var/log}"
mkdir -p "$LOG_DIR"
cd "$SCRIPT_DIR/POGS"
exec java \
    ${POGS_PLUGIN_DIR:+-Dplugin.dir="$POGS_PLUGIN_DIR"} \
    -jar target/pogs-0.0.1-SNAPSHOT.jar \
    >> "$LOG_DIR/pogs.log" 2>&1
