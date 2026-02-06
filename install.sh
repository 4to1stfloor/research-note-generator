#!/bin/bash
# ============================================================
# Research Note Generator - One-Line Installer
# ============================================================
# 사용법: 프로젝트 폴더에서 아래 한 줄 실행
#
#   curl -fsSL https://raw.githubusercontent.com/4to1stfloor/research-note-generator/main/install.sh | bash
#
# 이 스크립트가 하는 일:
#   1. ~/.research-note-generator/ 에 도구 설치 (또는 업데이트)
#   2. 현재 폴더를 프로젝트로 자동 등록
#   3. setup.sh 실행 (Python 확인, 이메일 설정 등)
# ============================================================

set -e

INSTALL_DIR="${HOME}/.research-note-generator"
REPO_URL="https://github.com/4to1stfloor/research-note-generator.git"

# Colors
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  ${BOLD}Research Note Generator - Installer${NC}${CYAN}             ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"
echo ""

# Remember where we are (this is the project directory)
PROJECT_DIR="$(pwd)"
echo -e "  ${GREEN}✓${NC} 프로젝트 감지: ${BOLD}$(basename "${PROJECT_DIR}")${NC} (${PROJECT_DIR})"

# Step 1: Clone or update
if [ -d "${INSTALL_DIR}/.git" ]; then
    echo -e "  ${GREEN}✓${NC} 이미 설치됨 → 업데이트 중..."
    cd "${INSTALL_DIR}" && git pull -q origin main 2>/dev/null || true
else
    echo -e "  ${CYAN}→${NC} 설치 중... (${INSTALL_DIR})"
    git clone -q "${REPO_URL}" "${INSTALL_DIR}" 2>/dev/null
fi
echo -e "  ${GREEN}✓${NC} 설치 완료"

# Step 2: Go back to project dir and run setup
cd "${PROJECT_DIR}"
echo ""

exec bash "${INSTALL_DIR}/setup.sh"
