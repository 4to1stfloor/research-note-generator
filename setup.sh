#!/bin/bash
# ============================================================
# Research Note Generator - Interactive Setup Wizard
# ============================================================
# 프로젝트 폴더에서 실행하면 자동으로 해당 프로젝트를 등록합니다.
# 기존 config가 있으면 프로젝트를 추가합니다 (덮어쓰지 않음).
#
# 사용법:
#   cd my_project && bash /path/to/setup.sh
#   cd another_project && bash /path/to/setup.sh   ← 추가 등록
# ============================================================

set -e

# curl | bash 로 실행 시 stdin이 파이프이므로 터미널로 복원
if [ ! -t 0 ]; then
    exec < /dev/tty
fi

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
# Auto-detect project
# ============================================================
echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  ${BOLD}Research Note Generator - Setup${NC}${CYAN}                 ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"
echo ""

# Project path: argument > current directory
if [ -n "$1" ] && [ -d "$1" ]; then
    PROJECT_PATH="$(realpath "$1")"
else
    PROJECT_PATH="$(pwd)"
fi

PROJECT_NAME="$(basename "${PROJECT_PATH}")"

# Safety check
if [ "${PROJECT_PATH}" = "${SCRIPT_DIR}" ]; then
    fail "현재 디렉토리가 research-note-generator 자체입니다!"
    echo ""
    echo -e "  ${CYAN}cd /path/to/my_project${NC}"
    echo -e "  ${CYAN}bash ${SCRIPT_DIR}/setup.sh${NC}"
    exit 1
fi

echo -e "  ${BOLD}감지된 프로젝트:${NC}"
echo ""
ok "이름: ${PROJECT_NAME}"
ok "경로: ${PROJECT_PATH}"

# Auto-detect file types
PY_COUNT=$(find "${PROJECT_PATH}" -maxdepth 3 -name "*.py" 2>/dev/null | wc -l)
R_COUNT=$(find "${PROJECT_PATH}" -maxdepth 3 \( -name "*.R" -o -name "*.r" \) 2>/dev/null | wc -l)
JS_COUNT=$(find "${PROJECT_PATH}" -maxdepth 3 \( -name "*.js" -o -name "*.ts" -o -name "*.tsx" \) 2>/dev/null | wc -l)
IPYNB_COUNT=$(find "${PROJECT_PATH}" -maxdepth 3 -name "*.ipynb" 2>/dev/null | wc -l)
SH_COUNT=$(find "${PROJECT_PATH}" -maxdepth 3 -name "*.sh" 2>/dev/null | wc -l)
YAML_COUNT=$(find "${PROJECT_PATH}" -maxdepth 3 \( -name "*.yaml" -o -name "*.yml" \) 2>/dev/null | wc -l)

DETECTED_TYPES=""
INCLUDE_LIST=""

add_pattern() { INCLUDE_LIST="${INCLUDE_LIST}\"$1\", "; }

if [ "$PY_COUNT" -gt 0 ]; then DETECTED_TYPES="${DETECTED_TYPES} .py(${PY_COUNT})"; add_pattern "**/*.py"; fi
if [ "$R_COUNT" -gt 0 ]; then DETECTED_TYPES="${DETECTED_TYPES} .R(${R_COUNT})"; add_pattern "**/*.R"; fi
if [ "$JS_COUNT" -gt 0 ]; then
    DETECTED_TYPES="${DETECTED_TYPES} .js/.ts(${JS_COUNT})"
    add_pattern "**/*.js"; add_pattern "**/*.ts"; add_pattern "**/*.jsx"; add_pattern "**/*.tsx"
    add_pattern "**/*.css"; add_pattern "**/*.html"
fi
if [ "$IPYNB_COUNT" -gt 0 ]; then DETECTED_TYPES="${DETECTED_TYPES} .ipynb(${IPYNB_COUNT})"; add_pattern "**/*.ipynb"; fi
if [ "$SH_COUNT" -gt 0 ]; then DETECTED_TYPES="${DETECTED_TYPES} .sh(${SH_COUNT})"; add_pattern "**/*.sh"; fi
if [ "$YAML_COUNT" -gt 0 ]; then DETECTED_TYPES="${DETECTED_TYPES} .yaml(${YAML_COUNT})"; add_pattern "**/*.yaml"; add_pattern "**/*.yml"; fi

# Fallback
if [ -z "$INCLUDE_LIST" ]; then
    INCLUDE_LIST='"**/*.py", "**/*.R", "**/*.yaml", "**/*.yml", "**/*.sh", "**/*.ipynb"'
    ok "파일 감지: 없음 (기본 패턴 사용)"
else
    INCLUDE_LIST="${INCLUDE_LIST%, }"  # Remove trailing comma
    ok "파일 감지:${DETECTED_TYPES}"
fi

DETECT_METHOD="mtime"
if [ -d "${PROJECT_PATH}/.git" ]; then
    DETECT_METHOD="git"
    ok "Git 저장소 → git 변경 감지"
else
    ok "일반 폴더 → mtime 변경 감지"
fi

# Check if already registered
if [ -f "${CONFIG_FILE}" ]; then
    PYTHON_CMD=""
    command -v python3 &>/dev/null && PYTHON_CMD="python3" || { command -v python &>/dev/null && PYTHON_CMD="python"; }
    if [ -n "$PYTHON_CMD" ]; then
        ALREADY=$($PYTHON_CMD -c "
import yaml
with open('${CONFIG_FILE}') as f:
    c = yaml.safe_load(f)
names = [p['name'] for p in c.get('projects', [])]
print('yes' if '${PROJECT_NAME}' in names else 'no')
" 2>/dev/null || echo "no")
        if [ "$ALREADY" = "yes" ]; then
            echo ""
            warn "'${PROJECT_NAME}'은 이미 등록되어 있습니다."
            read -p "  건너뛰고 바로 실행할까요? (Y/n): " SKIP_SETUP
            if [[ ! "$SKIP_SETUP" =~ ^[nN] ]]; then
                echo ""
                info "변경 감지 실행 중..."
                $PYTHON_CMD "${SCRIPT_DIR}/generate_note.py" --project "${PROJECT_NAME}" --verbose 2>&1 | while IFS= read -r line; do echo "  $line"; done
                echo ""
                ok "완료!"
                exit 0
            fi
        fi
    fi
fi

echo ""
read -p "  계속 진행? (Y/n): " CONFIRM
if [[ "$CONFIRM" =~ ^[nN] ]]; then echo "  취소됨."; exit 0; fi

# ============================================================
# Step 1: Python Check
# ============================================================
echo ""
echo -e "${BLUE}━━━ Step 1/3: Python 확인 ━━━${NC}"
echo ""

PYTHON_CMD=""
command -v python3 &>/dev/null && PYTHON_CMD="python3" || { command -v python &>/dev/null && PYTHON_CMD="python"; }

if [ -z "$PYTHON_CMD" ]; then
    fail "Python이 설치되어 있지 않습니다!"
    echo "    Ubuntu: sudo apt install python3 python3-pip"
    echo "    macOS : brew install python3"
    exit 1
fi
ok "Python: $($PYTHON_CMD --version 2>&1)"

if $PYTHON_CMD -c "import yaml" 2>/dev/null; then
    ok "PyYAML: OK"
else
    info "PyYAML 설치 중..."
    $PYTHON_CMD -m pip install pyyaml -q 2>/dev/null || pip install pyyaml -q 2>/dev/null
    $PYTHON_CMD -c "import yaml" 2>/dev/null && ok "PyYAML 설치 완료" || { fail "PyYAML 설치 실패: pip install pyyaml"; exit 1; }
fi

# ============================================================
# Step 2: Email (simplified)
# ============================================================
echo ""
echo -e "${BLUE}━━━ Step 2/3: 이메일 알림 ━━━${NC}"
echo ""

EMAIL_RECIPIENT=""
NOTIF_ENABLED="false"
EMAIL_ENABLED="false"

# Check if .env already has credentials
HAS_CREDENTIALS="false"
if [ -f "${ENV_FILE}" ]; then
    set -a; source "${ENV_FILE}" 2>/dev/null; set +a
    if [ -n "${SMTP_SENDER:-}" ] && [ -n "${SMTP_PASSWORD:-}" ]; then
        HAS_CREDENTIALS="true"
    fi
fi

echo "  연구노트를 이메일로 받아볼 수 있습니다."
echo ""
read -p "  수신 이메일 (받을 주소, 건너뛰려면 Enter): " EMAIL_RECIPIENT

if [ -n "$EMAIL_RECIPIENT" ]; then
    EMAIL_ENABLED="true"
    NOTIF_ENABLED="true"
    ok "수신: ${EMAIL_RECIPIENT}"

    if [ "$HAS_CREDENTIALS" = "true" ]; then
        ok "발신: ${SMTP_SENDER} (기존 설정 사용)"
    else
        echo ""
        read -p "  발신 Gmail (보낼 주소): " SMTP_SENDER

        if [ -z "$SMTP_SENDER" ]; then
            warn "발신 이메일 미입력 → 이메일 알림 건너뜀"
            EMAIL_ENABLED="false"
            NOTIF_ENABLED="false"
            EMAIL_RECIPIENT=""
        else
            ok "발신: ${SMTP_SENDER}"
            echo ""
            echo -e "  ${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo -e "  ${BOLD}  ${SMTP_SENDER} 의 앱 비밀번호 만들기${NC}"
            echo -e "  ${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo ""
            echo "  이메일 발송을 위해 Gmail '앱 비밀번호'가 필요합니다."
            echo "  (Gmail 일반 비밀번호가 아닌, 앱 전용 비밀번호입니다)"
            echo "  (처음 한 번만 만들면 됩니다)"
            echo ""
            echo -e "  ${BOLD}[Step 1]${NC} ${SMTP_SENDER} 으로 Google에 로그인한 상태에서"
            echo -e "          아래 링크를 브라우저에서 열어주세요:"
            echo ""
            echo -e "          ${CYAN}https://myaccount.google.com/security${NC}"
            echo ""
            echo -e "  ${BOLD}[Step 2]${NC} 페이지에서 ${BOLD}'2단계 인증'${NC} 항목을 찾아주세요."
            echo "          → '사용'으로 되어 있으면 OK, 다음 단계로"
            echo "          → '사용 안함'이면 클릭해서 먼저 활성화해주세요"
            echo ""
            echo -e "  ${BOLD}[Step 3]${NC} 2단계 인증이 켜졌으면, 아래 링크로 이동:"
            echo ""
            echo -e "          ${CYAN}https://myaccount.google.com/apppasswords${NC}"
            echo ""
            echo -e "          → 앱 이름에 아무거나 입력 (예: ${CYAN}research-note${NC})"
            echo -e "          → ${BOLD}'만들기'${NC} 버튼 클릭"
            echo ""
            echo -e "  ${BOLD}[Step 4]${NC} 화면에 나오는 ${BOLD}16자리 비밀번호${NC}를 복사해주세요."
            echo -e "          (예: ${CYAN}abcd efgh ijkl mnop${NC})"
            echo ""
            echo -e "          ${RED}이 비밀번호는 창을 닫으면 다시 볼 수 없습니다!${NC}"
            echo -e "          복사한 뒤 바로 아래에 붙여넣기 해주세요."
            echo ""
            echo -e "  ${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo ""
            read -p "  앱 비밀번호 붙여넣기: " SMTP_PASSWORD

            if [ -n "$SMTP_PASSWORD" ]; then
                cat > "${ENV_FILE}" << ENVEOF
SMTP_SENDER="${SMTP_SENDER}"
SMTP_PASSWORD="${SMTP_PASSWORD}"
ENVEOF
                chmod 600 "${ENV_FILE}"
                echo ""
                ok "이메일 설정 완료!"
                ok "발신: ${SMTP_SENDER} → 수신: ${EMAIL_RECIPIENT}"
                info "앱 비밀번호는 .env 파일에 저장됨 (git에 포함 안 됨)"
            else
                warn "앱 비밀번호 미입력 → 이메일 알림 건너뜀"
                warn "나중에 설정: cp .env.example .env 후 편집"
                EMAIL_ENABLED="false"
                NOTIF_ENABLED="false"
                EMAIL_RECIPIENT=""
            fi
        fi
    fi
else
    ok "건너뜀 (로컬 기록만 생성됩니다)"
fi

# ============================================================
# Step 3: Config (append or create)
# ============================================================
echo ""
echo -e "${BLUE}━━━ Step 3/3: 설정 저장 ━━━${NC}"
echo ""

# Build include patterns as Python list string
INCLUDE_PY_LIST="[${INCLUDE_LIST}]"
EXCLUDE_PY_LIST='["**/__pycache__/**", "**/.git/**", "**/*.pyc", "**/results/**", "**/logs/**", "**/daily/**", "**/node_modules/**"]'

if [ -f "${CONFIG_FILE}" ]; then
    # Append project to existing config
    $PYTHON_CMD << PYEOF
import yaml, sys

with open("${CONFIG_FILE}", "r") as f:
    config = yaml.safe_load(f) or {}

# Ensure projects list exists
if "projects" not in config:
    config["projects"] = []

# Remove existing project with same name (update)
config["projects"] = [p for p in config["projects"] if p.get("name") != "${PROJECT_NAME}"]

# Add new project
config["projects"].append({
    "name": "${PROJECT_NAME}",
    "path": "${PROJECT_PATH}",
    "detection": "${DETECT_METHOD}",
    "include_patterns": ${INCLUDE_PY_LIST},
    "exclude_patterns": ${EXCLUDE_PY_LIST},
    "note_output": "${PROJECT_PATH}/RESEARCH_NOTE.md",
    "daily_dir": "${PROJECT_PATH}/daily",
})

# Update notification settings if email was set
if "${EMAIL_ENABLED}" == "true":
    if "notification" not in config:
        config["notification"] = {}
    config["notification"]["enabled"] = True
    config["notification"]["schedule"] = config["notification"].get("schedule", "daily")
    if "email" not in config["notification"]:
        config["notification"]["email"] = {}
    config["notification"]["email"]["enabled"] = True
    config["notification"]["email"]["smtp_host"] = "smtp.gmail.com"
    config["notification"]["email"]["smtp_port"] = 587
    config["notification"]["email"]["use_tls"] = True
    config["notification"]["email"]["sender_env"] = "SMTP_SENDER"
    config["notification"]["email"]["password_env"] = "SMTP_PASSWORD"
    # Add recipient if not already in list
    recipients = config["notification"]["email"].get("recipients", [])
    if "${EMAIL_RECIPIENT}" not in recipients:
        recipients.append("${EMAIL_RECIPIENT}")
    config["notification"]["email"]["recipients"] = recipients

with open("${CONFIG_FILE}", "w") as f:
    yaml.dump(config, f, default_flow_style=False, allow_unicode=True, sort_keys=False)

n = len(config["projects"])
print(f"  OK: config.yaml 업데이트 ({n}개 프로젝트 등록)")
PYEOF
else
    # Create new config
    $PYTHON_CMD << PYEOF
import yaml

config = {
    "general": {
        "timezone": "Asia/Seoul",
        "language": "ko",
        "ai_backend": "auto",
        "ollama": {"model": "llama3.1:8b"},
    },
    "projects": [{
        "name": "${PROJECT_NAME}",
        "path": "${PROJECT_PATH}",
        "detection": "${DETECT_METHOD}",
        "include_patterns": ${INCLUDE_PY_LIST},
        "exclude_patterns": ${EXCLUDE_PY_LIST},
        "note_output": "${PROJECT_PATH}/RESEARCH_NOTE.md",
        "daily_dir": "${PROJECT_PATH}/daily",
    }],
    "note": {
        "daily_template": "./templates/daily_entry.md",
        "initial_template": "./templates/initial_note.md",
        "max_detailed_files": 20,
        "include_diffs": True,
        "max_diff_lines": 50,
    },
    "notification": {
        "enabled": $( [ "$NOTIF_ENABLED" = "true" ] && echo "True" || echo "False" ),
        "schedule": "daily",
        "weekly": {"send_day": "monday", "ai_summary": True},
        "email": {
            "enabled": $( [ "$EMAIL_ENABLED" = "true" ] && echo "True" || echo "False" ),
            "smtp_host": "smtp.gmail.com",
            "smtp_port": 587,
            "use_tls": True,
            "sender_env": "SMTP_SENDER",
            "password_env": "SMTP_PASSWORD",
            "recipients": [$( [ -n "$EMAIL_RECIPIENT" ] && echo "\"$EMAIL_RECIPIENT\"" || echo "")],
        },
        "slack": {
            "enabled": False,
            "bot_token_env": "SLACK_BOT_TOKEN",
            "recipients": ["U0123456789"],
        },
    },
    "idle": {
        "enabled": True,
        "pause_after_days": 7,
        "notify_on_pause": True,
        "auto_resume": True,
    },
    "state": {"state_dir": "./.state"},
}

with open("${CONFIG_FILE}", "w") as f:
    yaml.dump(config, f, default_flow_style=False, allow_unicode=True, sort_keys=False)

print("  OK: config.yaml 생성")
PYEOF
fi

# ============================================================
# Initialize & first run
# ============================================================
echo ""
info "RESEARCH_NOTE.md 생성 중..."
$PYTHON_CMD "${SCRIPT_DIR}/generate_note.py" --init "${PROJECT_NAME}" 2>&1 | while IFS= read -r line; do echo "  $line"; done

echo ""
info "첫 번째 변경 감지..."
$PYTHON_CMD "${SCRIPT_DIR}/generate_note.py" --project "${PROJECT_NAME}" --verbose 2>&1 | while IFS= read -r line; do echo "  $line"; done

# ============================================================
# Cron (optional)
# ============================================================
echo ""
echo -e "${BLUE}━━━ 매일 자동 실행 (선택) ━━━${NC}"
echo ""
read -p "  매일 자정 자동 실행? (Y/n): " AUTO_RUN
if [[ ! "$AUTO_RUN" =~ ^[nN] ]]; then
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
if [ "$EMAIL_ENABLED" = "true" ]; then
echo -e "  ${BOLD}이메일:${NC}   ${EMAIL_RECIPIENT}"
fi
echo ""
echo -e "  다른 프로젝트도 추가하려면:"
echo -e "    ${CYAN}cd /path/to/other_project${NC}"
echo -e "    ${CYAN}curl -fsSL https://raw.githubusercontent.com/4to1stfloor/research-note-generator/main/install.sh | bash${NC}"
echo ""
