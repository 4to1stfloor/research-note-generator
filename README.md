# Research Note Generator

프로젝트 변경사항을 자동으로 감지하여 체계적인 연구노트를 생성하는 도구.

## Features

- **자동 변경 감지**: Git diff 또는 파일 수정시간(mtime) 기반
- **일일 연구노트**: 날짜별 자동 생성 (개별 daily 파일 + 누적 RESEARCH_NOTE.md)
- **주간 리포트**: 7일치 daily 노트를 자동 병합 + AI 요약
- **AI 분석 (선택)**: Claude CLI / Anthropic API / Ollama(로컬 LLM) 자동 감지
- **알림**: Email(Gmail SMTP) / Slack DM 자동 발송
- **유휴 감지**: N일간 변경 없으면 자동 중단, 변경 시 자동 재개
- **다중 프로젝트**: config에 여러 프로젝트 등록 가능

## Quick Start

내 프로젝트 폴더에서 이 한 줄만 실행하면 끝:

```bash
cd my_project
curl -fsSL https://raw.githubusercontent.com/4to1stfloor/research-note-generator/main/install.sh | bash
```

`git clone`, `pip install` 등 **전부 자동**으로 처리됩니다.

자동으로 되는 것:
- 도구 설치 (`~/.research-note-generator/`)
- 현재 폴더를 프로젝트로 자동 등록
- 파일 유형 자동 감지 (.py, .R, .js 등)
- Git 저장소 여부 자동 판별
- Python/PyYAML 설치 확인
- 이메일 알림 설정 (선택)
- RESEARCH_NOTE.md 자동 생성
- 매일 자동 실행 설정 (선택)

---

## Manual Setup (직접 설정하기)

### 1. 클론 & 설치

```bash
git clone https://github.com/4to1stfloor/research-note-generator.git
cd research-note-generator
pip install pyyaml
```

### 2. 설정

```bash
# config.yaml 수정: 모니터링할 프로젝트 경로 설정
vi config.yaml

# (선택) 이메일 알림 사용 시: .env 파일 생성
cp .env.example .env
vi .env  # SMTP_SENDER, SMTP_PASSWORD 입력
```

`config.yaml`에서 프로젝트를 등록:

```yaml
projects:
  - name: "my_project"
    path: "./my_project"       # 또는 절대 경로
    detection: "mtime"         # git | mtime | auto
    include_patterns:
      - "**/*.py"
      - "**/*.yaml"
    exclude_patterns:
      - "**/__pycache__/**"
    note_output: "./my_project/RESEARCH_NOTE.md"
    daily_dir: "./my_project/daily"
```

### 3. 실행

```bash
# 초기 노트 생성 (최초 1회)
python generate_note.py --init my_project

# 일일 노트 생성
python generate_note.py

# 특정 프로젝트만
python generate_note.py --project my_project

# 미리보기 (파일 변경 없음)
python generate_note.py --dry-run --verbose

# 알림(이메일/슬랙) 포함 실행
python generate_note.py --send

# 주간 리포트 생성
python generate_note.py --weekly
```

## AI Backend

`config.yaml`의 `ai_backend` 설정으로 AI 요약 기능을 사용할 수 있습니다.
`"auto"` 모드(기본값)에서는 아래 순서대로 자동 감지합니다:

| 우선순위 | Backend | 설명 | 필요 조건 |
|---------|---------|------|----------|
| 1 | `claude_cli` | Claude Code CLI 사용 | Claude 구독 + CLI 설치 |
| 2 | `ollama` | 로컬 LLM (무료) | Ollama 설치 + 모델 pull |
| 3 | `anthropic_api` | Anthropic API | API Key |
| 4 | `none` | AI 없이 구조화된 템플릿만 | 없음 |

AI 없이도 변경 감지, 노트 생성, 알림 등 모든 핵심 기능이 동작합니다.

### Ollama (로컬 LLM) 사용

```bash
# Ollama 설치
curl -fsSL https://ollama.com/install.sh | sh

# 모델 다운로드
ollama pull llama3.1:8b

# config.yaml에서 설정
# ai_backend: "auto"  (자동 감지) 또는 "ollama" (직접 지정)
```

## Notifications

### Email (Gmail SMTP)

1. Gmail 2단계 인증 활성화
2. [앱 비밀번호](https://myaccount.google.com/apppasswords) 생성 (16자리)
3. `.env` 파일에 입력:
   ```
   SMTP_SENDER="your-email@gmail.com"
   SMTP_PASSWORD="xxxx xxxx xxxx xxxx"
   ```
4. `config.yaml`에서 `notification.enabled: true`, `email.enabled: true` 설정

### Slack DM

1. [Slack App](https://api.slack.com/apps) 생성 → Bot Token 발급
2. `.env`에 `SLACK_BOT_TOKEN="xoxb-..."` 입력
3. `config.yaml`에서 `slack.enabled: true`, `recipients`에 User ID 입력

## Automation

### Option A: Cron (로컬)

```bash
# cron job 설치 (매일 자정 실행)
bash scripts/setup_cron.sh install

# 상태 확인
bash scripts/setup_cron.sh status

# 제거
bash scripts/setup_cron.sh remove
```

### Option B: GitHub Actions

1. 이 저장소를 GitHub에 push
2. (선택) `Settings > Secrets > Actions`에서:
   - `ANTHROPIC_API_KEY` - API 사용 시
   - `SMTP_SENDER`, `SMTP_PASSWORD` - 이메일 사용 시
3. 매일 자정(KST)에 자동 실행
4. 수동 실행: `Actions > Daily Research Note Generator > Run workflow`

Claude/API가 없으면 GitHub Actions에서 자동으로 Ollama를 설치하여 AI 요약을 수행합니다.

## Generated Note Structure

### RESEARCH_NOTE.md (초기 생성)

```
1. Project Overview (목표, 핵심 아이디어)
2. Data Specification (입출력 데이터 명세)
3. Architecture (모델 구조도, 컴포넌트, 파라미터)
4. Loss / Objective Function
5. Code Evolution (코드 규모 변화 추적)
6. Version History (버전별 비교표)
7. Issues & Solutions (증상 → 원인 → 시도 → 해결)
8. Configuration
9. File Structure
10. Current Status (체크리스트)
11. Quick Reference (실행 명령어)
12. Lessons Learned
Daily Log (날짜별 자동 엔트리)
```

### Daily Entry (자동 생성)

```
# YYYY-MM-DD (Day)
## Changes Summary
## Key Changes Detail
## Architecture Updates
## Issues & Solutions
## Training / Experiment Status
## Lessons Learned
```

## File Structure

```
research-note-generator/
├── setup.sh                   # 초보자용 설정 마법사
├── generate_note.py           # 메인 스크립트
├── config.yaml                # 설정 파일
├── .env.example               # 환경변수 템플릿
├── .gitignore
├── README.md
├── requirements.txt
├── templates/
│   ├── initial_note.md        # 초기 노트 템플릿
│   └── daily_entry.md         # 일일 엔트리 템플릿
├── scripts/
│   ├── setup_cron.sh          # Cron 자동 설정
│   └── run_cron.sh            # Cron 실행 래퍼
└── .github/
    └── workflows/
        └── daily_note.yml     # GitHub Actions
```

## Requirements

- Python 3.8+
- PyYAML (`pip install pyyaml`)
- Git (git 기반 변경 감지 시)
- (선택) Claude Code CLI
- (선택) Ollama
- (선택) `anthropic` Python SDK

## License

MIT
