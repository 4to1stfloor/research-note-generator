#!/bin/bash
# ============================================================================
# Cron wrapper: loads .env and runs generate_note.py
# - 매일: 일일 노트 생성 + 알림
# - 월요일: 주간 리포트 생성 (7일치 daily 병합 + AI 요약)
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
LOG_FILE="${LOG_DIR}/cron_$(date +%Y%m%d).log"
mkdir -p "${LOG_DIR}"

# Ensure common PATH (cron has minimal PATH)
# Claude CLI: ~/.local/bin (curl install), ~/.claude/bin, npm global paths
export PATH="$HOME/.local/bin:$HOME/.claude/bin:$HOME/.npm-global/bin:$HOME/.nvm/versions/node/$(ls $HOME/.nvm/versions/node/ 2>/dev/null | tail -1)/bin:/usr/local/bin:$PATH" 2>/dev/null

# Load .env (if exists)
if [ -f "${SCRIPT_DIR}/.env" ]; then
    set -a
    source "${SCRIPT_DIR}/.env"
    set +a
fi

cd "${SCRIPT_DIR}"

# 0. Auto-update (git pull)
if [ -d "${SCRIPT_DIR}/.git" ]; then
    git -C "${SCRIPT_DIR}" pull --quiet >> "${LOG_FILE}" 2>&1 || true
fi

# 1. Daily note generation (매일)
echo "=== Daily Run: $(date) ===" >> "${LOG_FILE}"
python3 generate_note.py --send --verbose >> "${LOG_FILE}" 2>&1

# 2. Weekly report on Monday (월요일 = day 1)
if [ "$(date +%u)" = "1" ]; then
    echo "" >> "${LOG_FILE}"
    echo "=== Weekly Run: $(date) ===" >> "${LOG_FILE}"
    python3 generate_note.py --weekly --send --verbose >> "${LOG_FILE}" 2>&1
fi
