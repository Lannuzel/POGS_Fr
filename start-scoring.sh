#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${POGS_LOG_DIR:-/var/log}"
mkdir -p "$LOG_DIR"
cd "$SCRIPT_DIR/POGS/others/ScoringServer"
exec python3 server.py >> "$LOG_DIR/scoring.log" 2>&1
