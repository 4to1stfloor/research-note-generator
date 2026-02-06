#!/bin/bash
# ============================================================
# Research Note Generator - Interactive Setup Wizard
# ============================================================
# 프로젝트 폴더에서 실행하면 자동으로 해당 프로젝트를 등록합니다.
#
# 사용법:
#   cd my_project
#   bash /path/to/research-note-generator/setup.sh
#
# 또는 경로를 인자로:
#   bash setup.sh /path/to/my_project
# ============================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.yaml"
ENV_FILE="${SCRIPT_DIR}/.env"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

ok() { echo -e "  ${GREEN}✓${NC} $1"; }
warn() { echo -e "  ${YELLOW}!${NC} $1"; }
fail() { echo -e "  ${RED}✗${NC} $1"; }
info() { echo -e "  ${CYAN}→${NC} $1"; }

# ============================================================
# Step 0: Auto-detect project from current directory
# ============================================================
echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  ${BOLD}Research Note Generator - Setup Wizard${NC}${CYAN}          ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"
echo ""

# Project path: argument > current directory
if [ -n "$1" ] && [ -d "$1" ]; then
    PROJECT_PATH="$(realpath "$1")"
else
    PROJECT_PATH="$(pwd)"
fi

PROJECT_NAME="$(basename "${PROJECT_PATH}")"

# Safety: don't register the generator itself as a project
if [ "${PROJECT_PATH}" = "${SCRIPT_DIR}" ]; then
    fail "현재 디렉토리가 research-note-generator 자체입니다!"
    echo ""
    echo "  사용법: 모니터링할 프로젝트 폴더에서 실행하세요."
    echo ""
    echo -e "    ${CYAN}cd /path/to/my_project${NC}"
    echo -e "    ${CYAN}bash ${SCRIPT_DIR}/setup.sh${NC}"
    echo ""
    echo "  또는 경로를 인자로 전달:"
    echo ""
    echo -e "    ${CYAN}bash setup.sh /path/to/my_project${NC}"
    echo ""
    exit 1
fi

echo -e "  ${BOLD}감지된 프로젝트:${NC}"
echo ""
ok "이름: ${PROJECT_NAME}"
ok "경로: ${PROJECT_PATH}"
echo ""

# Auto-detect file types
PY_COUNT=$(find "${PROJECT_PATH}" -maxdepth 3 -name "*.py" 2>/dev/null | wc -l)
R_COUNT=$(find "${PROJECT_PATH}" -maxdepth 3 -name "*.R" -o -name "*.r" 2>/dev/null | wc -l)
JS_COUNT=$(find "${PROJECT_PATH}" -maxdepth 3 -name "*.js" -o -name "*.ts" -o -name "*.tsx" 2>/dev/null | wc -l)
IPYNB_COUNT=$(find "${PROJECT_PATH}" -maxdepth 3 -name "*.ipynb" 2>/dev/null | wc -l)
SH_COUNT=$(find "${PROJECT_PATH}" -maxdepth 3 -name "*.sh" 2>/dev/null | wc -l)
YAML_COUNT=$(find "${PROJECT_PATH}" -maxdepth 3 -name "*.yaml" -o -name "*.yml" 2>/dev/null | wc -l)

DETECTED_TYPES=""
INCLUDE_PATTERNS=""

if [ "$PY_COUNT" -gt 0 ]; then
    DETECTED_TYPES="${DETECTED_TYPES} .py(${PY_COUNT})"
    INCLUDE_PATTERNS="${INCLUDE_PATTERNS}      - \"**/*.py\"\n"
fi
if [ "$R_COUNT" -gt 0 ]; then
    DETECTED_TYPES="${DETECTED_TYPES} .R(${R_COUNT})"
    INCLUDE_PATTERNS="${INCLUDE_PATTERNS}      - \"**/*.R\"\n"
fi
if [ "$JS_COUNT" -gt 0 ]; then
    DETECTED_TYPES="${DETECTED_TYPES} .js/.ts(${JS_COUNT})"
    INCLUDE_PATTERNS="${INCLUDE_PATTERNS}      - \"**/*.js\"\n      - \"**/*.ts\"\n      - \"**/*.jsx\"\n      - \"**/*.tsx\"\n      - \"**/*.css\"\n      - \"**/*.html\"\n"
fi
if [ "$IPYNB_COUNT" -gt 0 ]; then
    DETECTED_TYPES="${DETECTED_TYPES} .ipynb(${IPYNB_COUNT})"
    INCLUDE_PATTERNS="${INCLUDE_PATTERNS}      - \"**/*.ipynb\"\n"
fi
if [ "$SH_COUNT" -gt 0 ]; then
    DETECTED_TYPES="${DETECTED_TYPES} .sh(${SH_COUNT})"
    INCLUDE_PATTERNS="${INCLUDE_PATTERNS}      - \"**/*.sh\"\n"
fi
if [ "$YAML_COUNT" -gt 0 ]; then
    DETECTED_TYPES="${DETECTED_TYPES} .yaml(${YAML_COUNT})"
    INCLUDE_PATTERNS="${INCLUDE_PATTERNS}      - \"**/*.yaml\"\n      - \"**/*.yml\"\n"
fi

# Fallback: if nothing detected, use common patterns
if [ -z "$INCLUDE_PATTERNS" ]; then
    INCLUDE_PATTERNS='      - "**/*.py"\n      - "**/*.R"\n      - "**/*.yaml"\n      - "**/*.yml"\n      - "**/*.sh"\n      - "**/*.ipynb"'
    ok "파일 감지: 없음 (기본 패턴 사용)"
else
    ok "파일 감지:${DETECTED_TYPES}"
fi

# Auto-detect git
DETECT_METHOD="mtime"
if [ -d "${PROJECT_PATH}/.git" ]; then
    DETECT_METHOD="git"
    ok "Git 저장소 감지됨 → git 기반 변경 감지"
else
    ok "일반 폴더 → 파일 수정시간(mtime) 기반 변경 감지"
fi

echo ""
echo -e "  ${YELLOW}Ctrl+C${NC} 를 누르면 취소, ${BOLD}Enter${NC}를 누르면 계속 진행합니다."
read -p "  계속하시겠습니까? (Y/n): " CONFIRM
if [[ "$CONFIRM" =~ ^[nN] ]]; then
    echo "  취소되었습니다."
    exit 0
fi

# ============================================================
# Step 1: Python Check
# ============================================================
echo ""
echo -e "${BLUE}━━━ Step 1/4: Python 환경 확인 ━━━${NC}"
echo ""

PYTHON_CMD=""
if command -v python3 &> /dev/null; then
    PYTHON_CMD="python3"
elif command -v python &> /dev/null; then
    PYTHON_CMD="python"
fi

if [ -z "$PYTHON_CMD" ]; then
    fail "Python이 설치되어 있지 않습니다!"
    echo ""
    echo "  설치 방법:"
    echo "    Ubuntu/Debian : sudo apt install python3 python3-pip"
    echo "    macOS         : brew install python3"
    echo "    Windows       : https://www.python.org/downloads/"
    exit 1
fi

ok "Python: $($PYTHON_CMD --version 2>&1)"

if $PYTHON_CMD -c "import yaml" 2>/dev/null; then
    ok "PyYAML: 설치됨"
else
    info "PyYAML 설치 중..."
    $PYTHON_CMD -m pip install pyyaml -q 2>/dev/null || pip install pyyaml -q 2>/dev/null
    if $PYTHON_CMD -c "import yaml" 2>/dev/null; then
        ok "PyYAML 설치 완료"
    else
        fail "PyYAML 설치 실패. 수동: pip install pyyaml"
        exit 1
    fi
fi

# ============================================================
# Step 2: Notification Setup (optional)
# ============================================================
echo ""
echo -e "${BLUE}━━━ Step 2/4: 이메일 알림 설정 (선택) ━━━${NC}"
echo ""
echo "  변경 감지 시 이메일로 연구노트를 받아볼 수 있습니다."
echo ""
read -p "  이메일 알림을 사용할까요? (y/N): " USE_EMAIL
USE_EMAIL="${USE_EMAIL:-n}"

EMAIL_ENABLED="false"
EMAIL_RECIPIENT=""
NOTIF_ENABLED="false"

if [[ "$USE_EMAIL" =~ ^[yY] ]]; then
    EMAIL_ENABLED="true"
    NOTIF_ENABLED="true"
    echo ""
    echo -e "  ${YELLOW}Gmail 앱 비밀번호 만드는 법:${NC}"
    echo "    1. https://myaccount.google.com/apppasswords 접속"
    echo "    2. 앱 이름 입력 → 만들기"
    echo "    3. 나오는 16자리 비밀번호 복사"
    echo "    (2단계 인증이 꺼져 있으면 먼저 켜야 합니다)"
    echo ""
    read -p "  Gmail 주소: " SMTP_SENDER
    read -p "  앱 비밀번호 (16자리): " SMTP_PASSWORD
    read -p "  수신자 이메일 [${SMTP_SENDER}]: " EMAIL_RECIPIENT
    EMAIL_RECIPIENT="${EMAIL_RECIPIENT:-${SMTP_SENDER}}"

    cat > "${ENV_FILE}" << ENVEOF
SMTP_SENDER="${SMTP_SENDER}"
SMTP_PASSWORD="${SMTP_PASSWORD}"
ENVEOF
    chmod 600 "${ENV_FILE}"
    ok ".env 생성 완료"
else
    ok "건너뜀 (나중에 설정 가능)"
fi

# ============================================================
# Step 3: Write config.yaml
# ============================================================
echo ""
echo -e "${BLUE}━━━ Step 3/4: 설정 파일 생성 ━━━${NC}"
echo ""

cat > "${CONFIG_FILE}" << CFGEOF
# Research Note Generator Configuration
# setup.sh로 자동 생성됨 ($(date +%Y-%m-%d))
# 프로젝트: ${PROJECT_NAME} (${PROJECT_PATH})

general:
  timezone: "Asia/Seoul"
  language: "ko"
  ai_backend: "auto"
  ollama:
    model: "llama3.1:8b"

projects:
  - name: "${PROJECT_NAME}"
    path: "${PROJECT_PATH}"
    detection: "${DETECT_METHOD}"
    include_patterns:
$(echo -e "${INCLUDE_PATTERNS}")
    exclude_patterns:
      - "**/__pycache__/**"
      - "**/.git/**"
      - "**/*.pyc"
      - "**/results/**"
      - "**/logs/**"
      - "**/daily/**"
      - "**/node_modules/**"
    note_output: "${PROJECT_PATH}/RESEARCH_NOTE.md"
    daily_dir: "${PROJECT_PATH}/daily"

note:
  daily_template: "./templates/daily_entry.md"
  initial_template: "./templates/initial_note.md"
  max_detailed_files: 20
  include_diffs: true
  max_diff_lines: 50

notification:
  enabled: ${NOTIF_ENABLED}
  schedule: "daily"
  weekly:
    send_day: "monday"
    ai_summary: true
  email:
    enabled: ${EMAIL_ENABLED}
    smtp_host: "smtp.gmail.com"
    smtp_port: 587
    use_tls: true
    sender_env: "SMTP_SENDER"
    password_env: "SMTP_PASSWORD"
    recipients:
      - "${EMAIL_RECIPIENT:-your-email@gmail.com}"
  slack:
    enabled: false
    bot_token_env: "SLACK_BOT_TOKEN"
    recipients:
      - "U0123456789"

idle:
  enabled: true
  pause_after_days: 7
  notify_on_pause: true
  auto_resume: true

state:
  state_dir: "./.state"
CFGEOF

ok "config.yaml 생성"

# ============================================================
# Step 4: Initialize & First Run
# ============================================================
echo ""
echo -e "${BLUE}━━━ Step 4/4: 초기 노트 생성 ━━━${NC}"
echo ""

info "RESEARCH_NOTE.md 생성 중..."
$PYTHON_CMD "${SCRIPT_DIR}/generate_note.py" --init "${PROJECT_NAME}" 2>&1 | while IFS= read -r line; do
    echo "  $line"
done

echo ""
info "첫 번째 변경 감지..."
$PYTHON_CMD "${SCRIPT_DIR}/generate_note.py" --project "${PROJECT_NAME}" --verbose 2>&1 | while IFS= read -r line; do
    echo "  $line"
done

# ============================================================
# Optional: cron
# ============================================================
echo ""
echo -e "${BLUE}━━━ 자동 실행 (선택) ━━━${NC}"
echo ""
echo "  매일 자정에 자동으로 실행할까요?"
echo "    1) cron 등록 (매일 자정)"
echo "    2) 건너뛰기"
echo ""
read -p "  선택 [2]: " AUTO_RUN
if [ "${AUTO_RUN:-2}" = "1" ]; then
    bash "${SCRIPT_DIR}/scripts/setup_cron.sh" install
fi

# ============================================================
# Done
# ============================================================
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ${BOLD}설정 완료!${NC}${GREEN}                                      ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${BOLD}프로젝트:${NC} ${PROJECT_NAME}"
echo -e "  ${BOLD}경로:${NC}     ${PROJECT_PATH}"
echo -e "  ${BOLD}노트:${NC}     ${PROJECT_PATH}/RESEARCH_NOTE.md"
echo ""
echo "  자주 쓰는 명령어 (${SCRIPT_DIR} 에서 실행):"
echo ""
echo -e "    ${CYAN}python3 generate_note.py${NC}                    일일 노트 생성"
echo -e "    ${CYAN}python3 generate_note.py --send${NC}             노트 + 이메일"
echo -e "    ${CYAN}python3 generate_note.py --weekly${NC}           주간 리포트"
echo -e "    ${CYAN}python3 generate_note.py --dry-run -v${NC}       미리보기"
echo ""
