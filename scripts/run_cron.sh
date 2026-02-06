#!/bin/bash
# Cron wrapper: loads .env and runs generate_note.py
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
mkdir -p "${LOG_DIR}"

# Load .env
set -a
source "${SCRIPT_DIR}/.env"
set +a

cd "${SCRIPT_DIR}"
python3 generate_note.py --send --verbose >> "${LOG_DIR}/cron_$(date +%Y%m%d).log" 2>&1
