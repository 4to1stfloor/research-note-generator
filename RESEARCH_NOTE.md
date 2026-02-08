# research_note_generator
## Project Description

> **Project**: research_note_generator
> **Author**: seokwon
> **Started**: 2026-02-09
> **Last Updated**: 2026-02-09
> **Current Version**: v1.0
> **Repository**: https://github.com/4to1stfloor/research-note-generator
> **Total**: 13 files, 2,449 lines

---

## 1. Project Overview

### 1.1 Goal
프로젝트의 변경사항을 자동으로 감지하여 체계적인 연구노트를 생성하는 CLI 도구. 연구자가 매일 수동으로 작성해야 하는 연구노트를 자동화하여, 코드 변경 → 감지 → AI 분석 → 노트 생성 → 알림 발송까지 전 과정을 처리한다.

### 1.2 Key Idea
- **변경 감지**: Git diff 또는 파일 mtime 기반으로 프로젝트 변경사항 자동 감지
- **AI 요약**: Claude CLI / Anthropic API / Ollama(로컬 LLM) 자동 감지 후 변경사항 분석/요약
- **다중 출력**: 개별 daily 파일 + 누적 RESEARCH_NOTE.md + 주간 리포트
- **알림**: Email(Gmail SMTP) / Slack DM 자동 발송
- **원클릭 설치**: `curl ... | bash` 한 줄로 설치부터 프로젝트 등록까지 완료

### 1.3 Relation to Other Projects
- 기존 연구노트 도구(Notion, Obsidian 등)와 달리 **코드 변경 자동 추적**에 특화
- GitHub Actions/Cron 연동으로 완전 자동화 가능
- AI 백엔드 없이도 구조화된 템플릿으로 동작 (graceful degradation)

---

## 2. Data Specification

### 2.1 Input
| Data | Path | Format | Description |
|------|------|--------|-------------|
| 프로젝트 소스코드 | 사용자 지정 경로 | .py, .R, .sh, .yaml 등 | 변경 감지 대상 |
| config.yaml | `~/.research-note-generator/config.yaml` | YAML | 프로젝트 등록, AI 설정, 알림 설정 |
| .env | `~/.research-note-generator/.env` | env | SMTP 인증, API 키 등 시크릿 |
| Git history | `.git/` | Git | 커밋 로그, diff 정보 |

### 2.2 Output
| Artifact | Path | Description |
|----------|------|-------------|
| RESEARCH_NOTE.md | `{project}/RESEARCH_NOTE.md` | 누적 연구노트 (초기 템플릿 + daily 엔트리) |
| Daily entry | `{project}/daily/YYYY-MM-DD-research-note.md` | 일별 개별 파일 |
| Weekly report | `{project}/daily/YYYY-MM-DD-weekly-report.md` | 주간 요약 리포트 |
| State files | `.state/` | 변경 감지 상태, idle 추적 |

---

## 3. Architecture

### 3.1 Overview
```
[프로젝트 소스코드]
        │
        ▼
┌─────────────────┐    ┌──────────────┐
│ ChangeDetector   │◀──│ config.yaml  │
│  - git diff      │    └──────────────┘
│  - mtime scan    │
└────────┬────────┘
         │ changes dict
         ▼
┌─────────────────┐    ┌──────────────┐
│ NoteGenerator    │◀──│ AIBackend    │
│  - structured    │    │ (auto-detect)│
│  - claude_cli    │    │ 1. Claude CLI│
│  - anthropic_api │    │ 2. API       │
│  - ollama        │    │ 3. Ollama    │
└────────┬────────┘    │ 4. none      │
         │ entry md     └──────────────┘
         ▼
┌─────────────────┐    ┌──────────────┐
│ File Writer      │    │ Notifier     │
│  - daily file    │    │ - Email SMTP │
│  - append to     │    │ - Slack DM   │
│    RESEARCH_NOTE │    └──────────────┘
└─────────────────┘
```

### 3.2 Components
| Module | Class/Function | File:Line | Description |
|--------|---------------|-----------|-------------|
| 변경 감지 | `ChangeDetector` | generate_note.py:60 | Git diff / mtime 기반 변경 파일 탐지 |
| Idle 감지 | `IdleDetector` | generate_note.py:258 | N일간 변경 없으면 자동 중단/재개 |
| AI 백엔드 | `AIBackend` | generate_note.py:308 | Claude/API/Ollama 자동 감지 |
| 노트 생성 | `NoteGenerator` | generate_note.py:389 | AI 요약 또는 구조화 템플릿으로 daily entry 생성 |
| 주간 리포트 | `WeeklyReporter` | generate_note.py:640 | 7일치 daily 병합 + AI 요약 |
| 알림 | `Notifier` | generate_note.py:762 | Email(SMTP) / Slack(Bot Token) 발송 |
| 설치 마법사 | `setup.sh` | setup.sh | 인터랙티브 4단계 설정 |
| 원클릭 설치 | `install.sh` | install.sh | curl 파이프 설치 |

### 3.3 Parameters
| Component | Params |
|-----------|--------|
| ChangeDetector | detection: git/mtime/auto, include_patterns, exclude_patterns |
| AIBackend | ai_backend: auto/claude_cli/anthropic_api/ollama/none, ollama.model |
| NoteGenerator | max_detailed_files: 20, include_diffs: true, max_diff_lines: 50 |
| IdleDetector | pause_after_days: 7, notify_on_pause: true, auto_resume: true |
| Notifier | email.smtp_host, email.smtp_port, email.use_tls, slack.bot_token_env |

---

## 4. Loss / Objective Function

N/A - 개발 도구 프로젝트 (ML 모델 없음)

---

## 5. Code Evolution

| Version | Date | Files | Lines | Key Change |
|---------|------|-------|-------|------------|
| b4837af | 2026-02-09 | 10 | ~1,800 | Initial commit: 핵심 기능 전체 구현 |
| 85a998b | 2026-02-09 | 11 | ~2,100 | setup.sh 인터랙티브 마법사 추가 |
| 95645e9 | 2026-02-09 | 11 | ~2,200 | setup.sh 자동감지 방식으로 재설계 |
| 5c86fed | 2026-02-09 | 12 | ~2,250 | install.sh 원클릭 설치 추가 |
| 0307563 | 2026-02-09 | 12 | ~2,300 | 다중 프로젝트 config append + 이메일 간소화 |
| 6ee2227 | 2026-02-09 | 12 | ~2,350 | 수신/발신 이메일 분리 |
| eec58dd | 2026-02-09 | 12 | ~2,350 | curl pipe stdin 호환성 수정 |
| 5747a8e | 2026-02-09 | 13 | ~2,449 | AI 백엔드 4단계 우선순위 + Ollama 설치 옵션 |

---

## 6. Version History

### 6.1 Feature Timeline
| Feature | Commit | Status |
|---------|--------|--------|
| 변경 감지 (git/mtime) | b4837af | Done |
| AI 요약 (Claude/API/Ollama) | b4837af | Done |
| Email 알림 (Gmail SMTP) | b4837af | Done |
| Slack 알림 | b4837af | Done |
| 주간 리포트 | b4837af | Done |
| 유휴 감지 (auto-pause/resume) | b4837af | Done |
| GitHub Actions | b4837af | Done |
| Cron 자동 설정 | b4837af | Done |
| 인터랙티브 setup 마법사 | 85a998b | Done |
| 원클릭 curl 설치 | 5c86fed | Done |
| 다중 프로젝트 지원 | 0307563 | Done |
| Ollama 자동 설치 옵션 | 79467cd | Done |

---

## 7. Issues & Solutions

### Issue 1: curl pipe에서 read 명령 실패
- **증상**: `curl ... | bash`로 설치 시 인터랙티브 프롬프트가 안 나오고 즉시 종료
- **원인**: stdin이 curl 파이프에 연결되어 `read`가 EOF을 만남 + `set -e`로 즉시 종료
- **시도**: install.sh에서 `exec bash setup.sh < /dev/tty` 추가
- **해결**: setup.sh 자체에 `if [ ! -t 0 ]; then exec < /dev/tty; fi` 추가 (이중 안전장치)

### Issue 2: echo 색상 코드 깨짐
- **증상**: 앱 비밀번호 가이드에서 `\033[0;36m` 등 raw escape 코드 출력
- **원인**: `echo -e` 대신 `echo`로 출력한 줄에서 색상 변수 미해석
- **해결**: 색상 변수 사용하는 모든 echo에 `-e` 플래그 추가

### Issue 3: fnmatch 루트 파일 미매칭
- **증상**: `**/*.yaml` 패턴이 `config.yaml` (루트 레벨)을 매칭하지 못함
- **원인**: `fnmatch`에서 `**/`이 최소 1개 디렉토리를 요구
- **해결**: `_match()`에서 `**/` prefix 제거 후 추가 매칭 시도

### Issue 4: config.yaml 덮어쓰기
- **증상**: 두 번째 프로젝트 등록 시 첫 번째 프로젝트 설정 날아감
- **원인**: setup.sh가 config.yaml을 매번 새로 생성
- **해결**: Python YAML 파싱으로 기존 config 읽기 → 프로젝트 append → 저장

---

## 8. Configuration

```yaml
general:
  timezone: "Asia/Seoul"
  language: "ko"
  ai_backend: "auto"  # auto → claude_cli → anthropic_api → ollama → none
  ollama:
    model: "llama3.1:8b"

projects:
  - name: "research_note_generator"
    path: "/home/seokwon/.../research_note_generator"
    detection: "git"
    include_patterns: ["**/*.py", "**/*.sh", "**/*.yaml", "**/*.yml", "**/*.md"]
    exclude_patterns: ["**/__pycache__/**", "**/.git/**", ...]

notification:
  enabled: true/false
  email:
    enabled: true/false
    smtp_host: "smtp.gmail.com"
    recipients: ["receiver@gmail.com"]

idle:
  enabled: true
  pause_after_days: 7
  auto_resume: true
```

---

## 9. File Structure

```
research-note-generator/
├── generate_note.py           # 메인 스크립트 (1,107 lines)
│   ├── ChangeDetector         #   변경 감지 (git/mtime)
│   ├── IdleDetector           #   유휴 감지 (auto-pause)
│   ├── AIBackend              #   AI 백엔드 자동 감지
│   ├── NoteGenerator          #   노트 생성 (AI/템플릿)
│   ├── WeeklyReporter         #   주간 리포트
│   └── Notifier               #   이메일/슬랙 알림
├── setup.sh                   # 인터랙티브 설정 마법사 (430 lines)
├── install.sh                 # 원클릭 curl 설치 (51 lines)
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

---

## 10. Current Status

### 10.1 State
v1.0 개발 완료, GitHub 배포 완료

### 10.2 Validation Checklist
- [x] 변경 감지: git diff 기반
- [x] 변경 감지: mtime 기반
- [x] AI 요약: Claude CLI
- [x] AI 요약: Ollama 로컬 LLM
- [x] AI 요약: Anthropic API
- [x] AI 없이 구조화된 템플릿
- [x] 일일 노트 자동 생성
- [x] 주간 리포트 생성
- [x] Email 알림 (Gmail SMTP)
- [x] Slack 알림
- [x] 유휴 감지 (자동 중단/재개)
- [x] 원클릭 설치 (`curl | bash`)
- [x] 다중 프로젝트 지원
- [x] GitHub Actions CI/CD
- [x] Cron 자동 설정

---

## 11. Quick Reference

### 11.1 설치 (새 프로젝트 폴더에서)
```bash
curl -fsSL https://raw.githubusercontent.com/4to1stfloor/research-note-generator/main/install.sh | bash
```

### 11.2 일일 실행
```bash
python3 ~/.research-note-generator/generate_note.py --project my_project --verbose
```

### 11.3 주간 리포트
```bash
python3 ~/.research-note-generator/generate_note.py --weekly
```

### 11.4 알림 포함 실행
```bash
python3 ~/.research-note-generator/generate_note.py --send
```

---

## 12. Lessons Learned

### 12.1 What Worked
- **원클릭 설치 패턴**: `curl | bash` + `exec < /dev/tty`로 파이프에서도 인터랙티브 동작
- **AI 폴백 체인**: claude_cli → api → ollama → none 순서의 graceful degradation
- **자동 감지**: 파일 유형, Git 여부, AI 백엔드 모두 자동으로 감지하여 사용자 입력 최소화
- **다중 프로젝트 append**: Python YAML 파싱으로 기존 설정 유지하면서 프로젝트 추가

### 12.2 What Didn't Work
- **fnmatch의 `**` 패턴**: 표준 라이브러리 fnmatch는 glob의 `**`를 제대로 처리하지 못함 → 별도 로직 필요
- **SSH 접근**: 서버 환경에서 SSH 포트가 차단되어 GitHub HTTPS + PAT 방식으로 전환
- **GitHub CDN 캐시**: `raw.githubusercontent.com`의 5분 캐시로 인해 push 직후 curl 테스트 실패

### 12.3 Key Insights
- stdin 파이프 문제는 `exec < /dev/tty`로 해결 가능 (POSIX 표준)
- 초보자 UX에서 "폴더 경로 입력"보다 "해당 폴더로 이동 후 실행"이 훨씬 직관적
- 이메일 설정은 수신/발신 분리가 필수 (같은 주소라도 명시적 분리가 UX에 좋음)
- `set -e` 환경에서 `read`는 EOF 시 non-zero 반환하여 스크립트 종료시킬 수 있음

---

## Daily Log

<!-- 날짜별 엔트리가 여기 아래에 최신순으로 쌓입니다 -->

---

# 2026-02-09 (Mon)

## Changes Summary

프로젝트 설정 관리 개선 및 AI 백엔드 감지 우선순위 재정립 작업을 수행했다. 설정 파일에서 프로젝트 경로를 절대 경로로 변경하고, AI 백엔드 감지 순서를 재구성하여 사용성을 개선했다. 또한 파일 패턴 매칭 로직에서 루트 레벨 파일 매칭 지원을 추가했다.

**Modified**: `config.yaml`, `generate_note.py`, `setup.sh` (3개 파일)  
**Key commits**: 
- `5747a8e` feat: reorder AI backend priority and add no-AI guidance
- `79467cd` feat: add AI backend detection with Ollama install option

## Key Changes Detail

### 1. 프로젝트 설정 업데이트 (`config.yaml`)
- 프로젝트명을 `my_project` → `research_note_generator`로 변경
- 상대 경로를 절대 경로로 변경 (`/home/seokwon/nas1_deep/pro_side_research_note/research_note_generator`)
- 파일 패턴에서 `**/*.R` 제거, `**/*.md` 추가
- `note_output` 및 `daily_dir` 경로를 절대 경로로 명시

### 2. 파일 매칭 로직 개선 (`generate_note.py:197-202`)
```python
# **/ prefix 처리 추가: **/*.py가 루트의 main.py도 매칭하도록
if p.startswith("**/") and fnmatch.fnmatch(fp, p[3:]):
    return True
```
- 기존: `**/*.py` 패턴이 루트 레벨 파일 미매칭
- 개선: prefix 제거 후 추가 매칭 시도로 루트 파일도 포함

### 3. AI 백엔드 감지 우선순위 재설계 (`setup.sh:178-224`)

**변경 전**: Claude CLI → Ollama 순서  
**변경 후**: 4단계 우선순위 체계
1. **Claude Code CLI** (`claude` 명령어 존재)
2. **Anthropic API Key** (환경변수 또는 `.env` 파일)
3. **Ollama** (로컬 LLM, 모델 자동 다운로드)
4. **없음** → Ollama 설치 제안

```bash
# Anthropic API Key 감지 로직 추가
elif [ -n "${ANTHROPIC_API_KEY:-}" ] || ([ -f "${ENV_FILE}" ] && grep -q "ANTHROPIC_API_KEY" "${ENV_FILE}"); then
    AI_DETECTED="anthropic_api"
```

- Ollama 미설치 시 인터랙티브 설치 프롬프트 개선
- AI 백엔드 없을 때 "구조화된 템플릿만 생성" 안내 추가

## Architecture Updates

### 파일 매칭 알고리즘 확장
`ChangeDetector._match()` 메서드에서 glob 패턴 해석 방식을 개선하여 `**/` prefix가 있는 패턴이 디렉토리 깊이와 무관하게 매칭되도록 보장했다. 이는 monorepo 구조에서 루트 레벨 설정 파일을 감지하는 데 유용하다.

### AI 백엔드 우선순위 체계
1. **CLI 우선**: 설치된 도구 활용 (가장 빠름)
2. **API 차선**: 환경변수 기반 (네트워크 필요)
3. **로컬 폴백**: Ollama (프라이버시 우선)
4. **설치 유도**: 사용자 선택권 제공

이 구조는 사용자 환경에 따라 자동으로 최적 경로를 선택하며, 명시적인 우선순위 메시지로 투명성을 높였다.

## Issues & Solutions (증상→원인→시도→해결)

### 문제 1: 루트 레벨 파일 미감지
- **증상**: `setup.sh`, `config.yaml` 등 루트 파일이 `**/*.sh`, `**/*.yaml` 패턴으로 매칭 안 됨
- **원인**: `fnmatch`가 `**/` prefix를 디렉토리 구분자로만 해석, 빈 경로 매칭 안 함
- **시도**: 패턴 정규화, 명시적 루트 경로 추가
- **해결**: prefix 제거 후 추가 매칭 단계 구현 (`generate_note.py:200-202`)

### 문제 2: AI 백엔드 감지 순서 비직관적
- **증상**: Anthropic API Key가 있어도 Ollama 먼저 체크되어 혼란
- **원인**: 감지 순서가 명확한 우선순위 기준 없이 구성됨
- **시도**: 주석 추가만으로 개선 시도
- **해결**: 순서 재배치 + 우선순위 숫자 라벨링으로 명확화 (`setup.sh:178-199`)

## Training / Experiment Status

N/A - 이 프로젝트는 개발 도구이므로 훈련/실험 단계 없음

## Lessons Learned

1. **Glob 패턴의 함정**: `**/` prefix는 "0개 이상의 디렉토리"를 의미하지만, `fnmatch`는 이를 암묵적으로 처리하지 않는다. 명시적인 edge case 처리가 필수다.

2. **사용자 경험의 투명성**: AI 백엔드 감지에서 "무엇이 감지되었는지"뿐 아니라 "왜 이것이 선택되었는지(우선순위)"를 보여주는 것이 사용자 신뢰를 높인다.

3. **설정 파일 경로 전략**: 상대 경로는 실행 위치에 따라 불안정하다. CI/CD 및 cron 환경에서는 절대 경로가 안전하다. 템플릿에는 상대 경로, 실제 사용 시 절대 경로로 변환하는 것이 좋은 패턴이다.

4. **폴백 체인 설계**: 여러 옵션을 지원할 때는 명확한 우선순위 + 각 단계의 실패 시 다음 단계로 자동 이동하는 체인 구조가 강건하다. 사용자 개입 최소화가 핵심이다.

---

