#!/bin/bash
# ============================================================
# Research Note Generator - Interactive Setup Wizard
# ============================================================
# 처음 사용하는 분도 쉽게 설정할 수 있도록 도와주는 스크립트입니다.
# 사용법: bash setup.sh
# ============================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.yaml"
ENV_FILE="${SCRIPT_DIR}/.env"
ENV_EXAMPLE="${SCRIPT_DIR}/.env.example"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

print_header() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║  ${BOLD}Research Note Generator - Setup Wizard${NC}${CYAN}          ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_step() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}  Step $1: $2${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

ok() { echo -e "  ${GREEN}✓${NC} $1"; }
warn() { echo -e "  ${YELLOW}!${NC} $1"; }
fail() { echo -e "  ${RED}✗${NC} $1"; }
info() { echo -e "  ${CYAN}→${NC} $1"; }

# ============================================================
# Step 0: Welcome
# ============================================================
print_header
echo -e "  이 스크립트가 자동으로 모든 설정을 해 드립니다."
echo -e "  질문에 답하기만 하면 됩니다!"
echo ""
echo -e "  ${YELLOW}Ctrl+C${NC} 를 누르면 언제든 취소할 수 있습니다."

# ============================================================
# Step 1: Python Check
# ============================================================
print_step "1/5" "Python 환경 확인"

# Find python
PYTHON_CMD=""
if command -v python3 &> /dev/null; then
    PYTHON_CMD="python3"
elif command -v python &> /dev/null; then
    PYTHON_CMD="python"
fi

if [ -z "$PYTHON_CMD" ]; then
    fail "Python이 설치되어 있지 않습니다!"
    echo ""
    echo "  Python 설치 방법:"
    echo "    Ubuntu/Debian : sudo apt install python3 python3-pip"
    echo "    macOS         : brew install python3"
    echo "    Windows       : https://www.python.org/downloads/"
    echo ""
    exit 1
fi

PYTHON_VER=$($PYTHON_CMD --version 2>&1)
ok "Python 발견: ${PYTHON_VER}"

# Check/install pyyaml
if $PYTHON_CMD -c "import yaml" 2>/dev/null; then
    ok "PyYAML 이미 설치됨"
else
    info "PyYAML 설치 중..."
    $PYTHON_CMD -m pip install pyyaml -q 2>/dev/null || pip install pyyaml -q 2>/dev/null
    if $PYTHON_CMD -c "import yaml" 2>/dev/null; then
        ok "PyYAML 설치 완료"
    else
        fail "PyYAML 설치 실패. 수동으로 설치해 주세요: pip install pyyaml"
        exit 1
    fi
fi

# ============================================================
# Step 2: Project Registration
# ============================================================
print_step "2/5" "모니터링할 프로젝트 등록"

echo "  연구노트를 자동 생성할 프로젝트 폴더를 등록합니다."
echo ""

# Project name
read -p "  프로젝트 이름 (영문, 예: my_rnaseq_project): " PROJECT_NAME
PROJECT_NAME="${PROJECT_NAME:-my_project}"
# Remove spaces, special chars
PROJECT_NAME=$(echo "$PROJECT_NAME" | tr ' ' '_' | tr -cd 'a-zA-Z0-9_-')
ok "프로젝트 이름: ${PROJECT_NAME}"

# Project path
echo ""
echo "  프로젝트 폴더 경로를 입력해 주세요."
echo "  (이미 존재하는 폴더여야 합니다)"
echo ""
echo -e "  ${YELLOW}팁:${NC} 상대경로(./${PROJECT_NAME}) 또는 절대경로(/home/user/project) 모두 가능"
echo ""
read -p "  프로젝트 경로 [./${PROJECT_NAME}]: " PROJECT_PATH
PROJECT_PATH="${PROJECT_PATH:-./${PROJECT_NAME}}"

# Resolve to absolute for validation
ABS_PATH=$(cd "${SCRIPT_DIR}" && realpath -m "${PROJECT_PATH}" 2>/dev/null || echo "${PROJECT_PATH}")

if [ -d "${ABS_PATH}" ]; then
    ok "폴더 확인됨: ${ABS_PATH}"
else
    warn "폴더가 존재하지 않습니다: ${ABS_PATH}"
    read -p "  폴더를 생성할까요? (y/n) [y]: " CREATE_DIR
    CREATE_DIR="${CREATE_DIR:-y}"
    if [[ "$CREATE_DIR" =~ ^[yY] ]]; then
        mkdir -p "${ABS_PATH}"
        ok "폴더 생성됨: ${ABS_PATH}"
    else
        fail "폴더 없이는 진행할 수 없습니다."
        exit 1
    fi
fi

# File types
echo ""
echo "  모니터링할 파일 유형을 선택해 주세요:"
echo "    1) Python 프로젝트 (.py, .yaml, .sh, .R)"
echo "    2) 웹 프로젝트 (.js, .ts, .jsx, .tsx, .css, .html)"
echo "    3) 범용 (모든 텍스트 파일)"
echo "    4) 직접 입력"
echo ""
read -p "  선택 [1]: " FILE_TYPE
FILE_TYPE="${FILE_TYPE:-1}"

case $FILE_TYPE in
    1)
        INCLUDE_PATTERNS='      - "**/*.py"\n      - "**/*.R"\n      - "**/*.yaml"\n      - "**/*.yml"\n      - "**/*.sh"\n      - "**/*.ipynb"'
        ok "Python/R 프로젝트 패턴 선택됨"
        ;;
    2)
        INCLUDE_PATTERNS='      - "**/*.js"\n      - "**/*.ts"\n      - "**/*.jsx"\n      - "**/*.tsx"\n      - "**/*.css"\n      - "**/*.html"'
        ok "웹 프로젝트 패턴 선택됨"
        ;;
    3)
        INCLUDE_PATTERNS='      - "**/*.py"\n      - "**/*.js"\n      - "**/*.ts"\n      - "**/*.yaml"\n      - "**/*.json"\n      - "**/*.md"\n      - "**/*.sh"\n      - "**/*.R"'
        ok "범용 패턴 선택됨"
        ;;
    4)
        echo "  확장자를 쉼표로 구분하여 입력 (예: .py,.js,.yaml):"
        read -p "  확장자: " CUSTOM_EXTS
        INCLUDE_PATTERNS=""
        IFS=',' read -ra EXTS <<< "$CUSTOM_EXTS"
        for ext in "${EXTS[@]}"; do
            ext=$(echo "$ext" | tr -d ' ')
            INCLUDE_PATTERNS="${INCLUDE_PATTERNS}      - \"**/*${ext}\"\n"
        done
        ok "사용자 지정 패턴 설정됨"
        ;;
    *)
        INCLUDE_PATTERNS='      - "**/*.py"\n      - "**/*.R"\n      - "**/*.yaml"\n      - "**/*.yml"\n      - "**/*.sh"'
        ok "기본 패턴(Python) 선택됨"
        ;;
esac

# Detection method
echo ""
echo "  변경 감지 방법:"
echo "    1) auto  - 자동 선택 (권장)"
echo "    2) git   - Git 커밋 기반 (git 프로젝트만)"
echo "    3) mtime - 파일 수정시간 기반"
echo ""
read -p "  선택 [1]: " DETECT_METHOD
case $DETECT_METHOD in
    2) DETECT_METHOD="git" ;;
    3) DETECT_METHOD="mtime" ;;
    *) DETECT_METHOD="auto" ;;
esac
ok "변경 감지: ${DETECT_METHOD}"

# ============================================================
# Step 3: Notification Setup
# ============================================================
print_step "3/5" "알림 설정 (선택사항)"

echo "  변경 감지 시 이메일로 연구노트를 받아볼 수 있습니다."
echo ""
read -p "  이메일 알림을 사용할까요? (y/n) [n]: " USE_EMAIL
USE_EMAIL="${USE_EMAIL:-n}"

EMAIL_ENABLED="false"
EMAIL_RECIPIENT=""
NOTIF_ENABLED="false"

if [[ "$USE_EMAIL" =~ ^[yY] ]]; then
    EMAIL_ENABLED="true"
    NOTIF_ENABLED="true"
    echo ""
    echo -e "  ${YELLOW}Gmail App Password 설정 방법:${NC}"
    echo "    1. Google 계정 로그인 → 보안"
    echo "    2. '2단계 인증' 활성화 (이미 되어 있으면 건너뛰기)"
    echo "    3. 검색창에 '앱 비밀번호' 검색 또는 아래 링크 접속:"
    echo -e "       ${CYAN}https://myaccount.google.com/apppasswords${NC}"
    echo "    4. 앱 이름: research-note → 만들기"
    echo "    5. 나오는 16자리 비밀번호를 아래에 입력"
    echo ""
    read -p "  Gmail 주소: " SMTP_SENDER
    read -p "  앱 비밀번호 (16자리, 예: xxxx xxxx xxxx xxxx): " SMTP_PASSWORD
    read -p "  수신자 이메일 [${SMTP_SENDER}]: " EMAIL_RECIPIENT
    EMAIL_RECIPIENT="${EMAIL_RECIPIENT:-${SMTP_SENDER}}"

    # Write .env
    cat > "${ENV_FILE}" << ENVEOF
SMTP_SENDER="${SMTP_SENDER}"
SMTP_PASSWORD="${SMTP_PASSWORD}"
ENVEOF
    chmod 600 "${ENV_FILE}"
    ok ".env 파일 생성됨 (비밀번호 안전하게 저장)"
else
    ok "이메일 알림 건너뜀 (나중에 config.yaml에서 활성화 가능)"
fi

# ============================================================
# Step 4: Write config.yaml
# ============================================================
print_step "4/5" "설정 파일 생성"

cat > "${CONFIG_FILE}" << CFGEOF
# Research Note Generator Configuration
# setup.sh로 자동 생성됨 ($(date +%Y-%m-%d))

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

ok "config.yaml 생성 완료"

# ============================================================
# Step 5: Initialize & First Run
# ============================================================
print_step "5/5" "초기 노트 생성 & 첫 실행"

info "RESEARCH_NOTE.md 초기화 중..."
$PYTHON_CMD "${SCRIPT_DIR}/generate_note.py" --init "${PROJECT_NAME}" 2>&1 | while read line; do
    echo "  $line"
done

echo ""
info "첫 번째 변경 감지 실행 중..."
$PYTHON_CMD "${SCRIPT_DIR}/generate_note.py" --project "${PROJECT_NAME}" --verbose 2>&1 | while read line; do
    echo "  $line"
done

# ============================================================
# Auto-run setup
# ============================================================
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}  자동 실행 설정 (선택사항)${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "  매일 자정에 자동으로 실행하시겠습니까?"
echo "    1) cron 설정 (매일 자정 실행)"
echo "    2) 건너뛰기 (나중에 설정)"
echo ""
read -p "  선택 [2]: " AUTO_RUN
AUTO_RUN="${AUTO_RUN:-2}"

if [ "$AUTO_RUN" = "1" ]; then
    bash "${SCRIPT_DIR}/scripts/setup_cron.sh" install
fi

# ============================================================
# Done!
# ============================================================
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ${BOLD}설정 완료!${NC}${GREEN}                                      ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════╝${NC}"
echo ""
echo "  생성된 파일:"
ok "config.yaml         - 설정 파일"
if [ -f "${ENV_FILE}" ]; then
ok ".env                - 이메일 비밀번호 (git에 포함 안 됨)"
fi
ok "${PROJECT_PATH}/RESEARCH_NOTE.md  - 연구노트"
echo ""
echo "  자주 쓰는 명령어:"
echo -e "    ${CYAN}python3 generate_note.py${NC}                    일일 노트 생성"
echo -e "    ${CYAN}python3 generate_note.py --send${NC}             노트 생성 + 이메일 발송"
echo -e "    ${CYAN}python3 generate_note.py --weekly${NC}           주간 리포트 생성"
echo -e "    ${CYAN}python3 generate_note.py --dry-run --verbose${NC} 미리보기"
echo ""
echo -e "  자세한 설명: ${CYAN}cat README.md${NC}"
echo ""
