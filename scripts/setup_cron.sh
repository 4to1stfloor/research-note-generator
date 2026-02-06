#!/bin/bash
# ============================================================================
# Research Note Generator - Cron Setup Script
# ============================================================================
# Sets up a daily cron job to run the research note generator at midnight.
#
# Usage:
#   bash scripts/setup_cron.sh          # Install cron job
#   bash scripts/setup_cron.sh remove   # Remove cron job
#   bash scripts/setup_cron.sh status   # Check cron status
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PYTHON_BIN="${PYTHON_BIN:-python3}"
CRON_COMMENT="# research-note-generator"
LOG_DIR="${SCRIPT_DIR}/logs"

# Cron schedule: midnight KST (00:00)
CRON_SCHEDULE="0 0 * * *"

# Use wrapper script (handles .env loading with spaces in passwords)
CRON_CMD="/bin/bash ${SCRIPT_DIR}/scripts/run_cron.sh ${CRON_COMMENT}"

setup_cron() {
    echo "=== Research Note Generator - Cron Setup ==="
    echo ""
    echo "Script dir : ${SCRIPT_DIR}"
    echo "Python     : ${PYTHON_BIN}"
    echo "Schedule   : ${CRON_SCHEDULE} (daily at midnight)"
    echo "Log dir    : ${LOG_DIR}"
    echo ""

    # Create log directory
    mkdir -p "${LOG_DIR}"

    # Check if cron job already exists
    if crontab -l 2>/dev/null | grep -q "research-note-generator"; then
        echo "[WARN] Cron job already exists. Updating..."
        # Remove existing job
        crontab -l 2>/dev/null | grep -v "research-note-generator" | crontab -
    fi

    # Add new cron job
    (crontab -l 2>/dev/null; echo "${CRON_SCHEDULE} ${CRON_CMD}") | crontab -

    echo "[OK] Cron job installed!"
    echo ""
    echo "Current crontab:"
    crontab -l 2>/dev/null | grep "research-note-generator"
    echo ""
    echo "To check logs:"
    echo "  ls -la ${LOG_DIR}/"
    echo "  tail -f ${LOG_DIR}/cron_\$(date +%Y%m%d).log"
}

remove_cron() {
    echo "Removing research-note-generator cron job..."
    if crontab -l 2>/dev/null | grep -q "research-note-generator"; then
        crontab -l 2>/dev/null | grep -v "research-note-generator" | crontab -
        echo "[OK] Cron job removed."
    else
        echo "[INFO] No cron job found."
    fi
}

status_cron() {
    echo "=== Cron Status ==="
    if crontab -l 2>/dev/null | grep -q "research-note-generator"; then
        echo "[ACTIVE] Cron job is installed:"
        crontab -l 2>/dev/null | grep "research-note-generator"
    else
        echo "[INACTIVE] No cron job found."
    fi

    echo ""
    echo "=== Recent Logs ==="
    if [ -d "${LOG_DIR}" ]; then
        ls -lt "${LOG_DIR}/" 2>/dev/null | head -5
    else
        echo "No logs yet."
    fi
}

# Main
case "${1:-install}" in
    install|setup)
        setup_cron
        ;;
    remove|uninstall)
        remove_cron
        ;;
    status)
        status_cron
        ;;
    *)
        echo "Usage: $0 {install|remove|status}"
        exit 1
        ;;
esac
