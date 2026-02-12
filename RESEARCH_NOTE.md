# research_note_generator
## Project Description

> **Project**: research_note_generator
> **Author**: seokwon
> **Started**: 2026-02-09
> **Last Updated**: 2026-02-11
> **Current Version**: v1

---

## 1. Project Overview

### 1.1 Goal
자동으로 연구 프로젝트의 변경사항을 추적하고 일일 노트를 생성하며, AI 기반 요약을 통해 연구 기록을 체계적으로 관리하는 도구 개발

### 1.2 Key Idea
- Git 저장소 모니터링을 통한 자동 변경사항 추적
- 다중 AI 백엔드 지원 (Claude CLI, Anthropic API, Ollama)
- 자동 우선순위: claude_cli → anthropic_api → ollama (로컬 무료 옵션)
- 대화형 설정 마법사를 통한 간편한 초기 설정
- One-line installer로 curl | bash 설치 지원
- 다중 프로젝트 모니터링 및 일일/주간 알림 기능

### 1.3 Relation to Other Projects
N/A

---

## 2. Data Specification

### 2.1 Input
| Data | Path | Format | Description |
|------|------|--------|-------------|
| 설정 파일 | `config.yaml` | YAML | 프로젝트 경로, AI 백엔드, 알림 설정 등 |
| 환경 변수 | `.env` | ENV | ANTHROPIC_API_KEY 등 민감 정보 |
| 일일 템플릿 | `templates/daily_entry.md` | Markdown | 일일 노트 생성 템플릿 |
| 초기 템플릿 | `templates/initial_note.md` | Markdown | 프로젝트 초기 노트 템플릿 |
| Git 저장소 | 프로젝트 경로 | Git | 변경사항 추적 대상 |

### 2.2 Output
| Artifact | Path | Description |
|----------|------|-------------|
| 연구 노트 | `RESEARCH_NOTE.md` | 프로젝트별 메인 연구 노트 |
| 일일 노트 | `daily/YYYY-MM-DD-research-note.md` | 날짜별 변경사항 기록 |
| 이메일 알림 | N/A | SMTP를 통한 일일/주간 요약 전송 |

---

## 3. Architecture

### 3.1 Overview
```
┌─────────────┐
│   User      │
└──────┬──────┘
       │
       ├─► install.sh (One-line installer)
       │        ↓
       ├─► setup.sh (Interactive wizard)
       │        ↓
       └─► generate_note.py (Main script)
                ↓
       ┌────────┴────────┐
       │                 │
   ┌───▼────┐     ┌─────▼─────┐
   │  Git   │     │ AI Backend│
   │Monitor │     │  (Auto)   │
   └────────┘     └───┬───┬───┘
                      │   │
              ┌───────┘   └────────┐
              │                     │
        claude_cli          anthropic_api
              │                     │
              └──────┬──────────────┘
                     │
                  ollama (fallback)
                     ↓
              Markdown Output
                     ↓
              Email (optional)
```

### 3.2 Components
- **install.sh**: One-line installer - Git clone 및 setup.sh 자동 실행 (install.sh:1)
- **setup.sh**: 대화형 설정 마법사 - Python 버전 확인, 프로젝트 자동 감지, AI 백엔드 설정, 이메일 설정 (setup.sh:1)
- **generate_note.py**: 메인 스크립트 - Git diff 분석, AI 요약 생성, 마크다운 노트 출력 (generate_note.py:1)
- **scripts/setup_cron.sh**: cron 작업 설정 스크립트 (scripts/setup_cron.sh:1)
- **scripts/run_cron.sh**: cron에서 실행되는 wrapper 스크립트 (scripts/run_cron.sh:1)
- **.github/workflows/daily_note.yml**: GitHub Actions 워크플로우 - 자동화된 일일 노트 생성 (.github/workflows/daily_note.yml:1)

### 3.3 Parameters
| Component | Params |
|-----------|--------|
| general | timezone, language, ai_backend |
| ollama | model (llama3.1:8b, llama3.2:3b, gemma2:9b, qwen2.5:7b) |
| projects | name, path, detection, include_patterns, exclude_patterns, note_output, daily_dir |
| note | daily_template, initial_template, max_detailed_files, include_diffs, max_diff_lines |
| notification | enabled, schedule, weekly.send_day, weekly.ai_summary, email.enabled |

---

## 4. Loss / Objective Function

N/A

### 4.2 Evolution
N/A

---

## 5. Code Evolution

| Version | Date | Files | Lines | Key Change |
|---------|------|-------|-------|------------|
| v1 | 2026-02-09 | 14 | ~800 | 초기 릴리즈: AI 백엔드 자동 감지, fnmatch 루트 매칭 수정, full 프로젝트 노트 생성 |

---

## 6. Version History

### 6.1 Version Comparison
| Metric | v1 |
|--------|----|
| AI Backends | 3 (Claude CLI, Anthropic API, Ollama) |
| Supported Languages | Python, Shell, YAML, Markdown |
| Installation Method | One-line curl \| bash |
| Multi-project Support | Yes |

---

## 7. Issues & Solutions

**Issue 1: AI 백엔드 없는 환경에서 사용 불가**
- 증상: Anthropic API 키나 Claude CLI 없이는 요약 생성 불가
- 원인: 유료 서비스 의존성
- 시도: Ollama 통합 (commit 79467cd)
- 해결: Auto-detect 우선순위 설정 (claude_cli → anthropic_api → ollama)

**Issue 2: fnmatch 루트 레벨 파일 매칭 오류**
- 증상: 루트 디렉토리 파일들이 include_patterns에 매칭되지 않음
- 원인: fnmatch 패턴 매칭 로직 오류
- 해결: fnmatch 루트 레벨 매칭 수정 (commit 8c27241)

**Issue 3: curl | bash 설치 시 stdin 문제**
- 증상: 대화형 입력 불가
- 원인: stdin이 파이프로 연결됨
- 해결: exec < /dev/tty로 터미널 복원 (commit a814594, eec58dd)

**Issue 4: Cron 자동 실행 기본값 혼란**
- 증상: 사용자들이 cron 설정을 놓침
- 해결: Y/n으로 기본값을 Yes로 변경 (commit 9808f55)

---

## 8. Configuration

```yaml
general:
  timezone: "Asia/Seoul"
  language: "ko"
  ai_backend: "auto"  # claude_cli → anthropic_api → ollama
  
ollama:
  model: "llama3.1:8b"
  
projects:
  - name: "research_note_generator"
    path: "/home/seokwon/nas1_deep/pro_side_research_note/research_note_generator"
    detection: "git"
    include_patterns: ["**/*.py", "**/*.sh", "**/*.yaml", "**/*.yml", "**/*.md"]
    exclude_patterns: ["**/__pycache__/**", "**/.git/**", "**/*.pyc", "**/results/**", "**/logs/**", "**/daily/**"]
    
note:
  max_detailed_files: 20
  include_diffs: true
  max_diff_lines: 50
  
notification:
  enabled: false
  schedule: "daily"
```

---

## 9. File Structure

```
research_note_generator/
├── .env.example
├── .github/
│   └── workflows/
│       └── daily_note.yml
├── .gitignore
├── README.md
├── RESEARCH_NOTE.md
├── config.yaml
├── daily/
│   └── 2026-02-09-research-note.md
├── generate_note.py
├── install.sh
├── requirements.txt
├── scripts/
│   ├── run_cron.sh
│   └── setup_cron.sh
├── setup.sh
└── templates/
    ├── daily_entry.md
    └── initial_note.md
```

---

## 10. Current Status

### 10.1 State
- 초기 릴리즈 완료 (v1)
- AI 백엔드 자동 감지 및 Ollama 통합 완료
- One-line installer 및 대화형 설정 마법사 구현 완료
- 다중 프로젝트 모니터링 지원
- GitHub Actions 워크플로우 설정 완료

### 10.2 Validation Checklist
- [x] Python 3.8+ 호환성 확인
- [x] Git 저장소 감지 및 diff 추출
- [x] 3개 AI 백엔드 auto-fallback 동작 확인
- [x] 다중 프로젝트 append 모드 동작 확인
- [x] One-line installer (curl | bash) 동작 확인
- [x] Cron 스케줄링 설정
- [ ] SMTP 이메일 알림 테스트
- [ ] 주간 요약 기능 테스트

---

## 11. Quick Reference

### 11.1 Run
```bash
# One-line installation
curl -fsSL https://raw.githubusercontent.com/4to1stfloor/research-note-generator/main/install.sh | bash

# Manual setup
cd /path/to/your/project
bash /path/to/research-note-generator/setup.sh

# Generate note manually
python /path/to/research-note-generator/generate_note.py

# Setup cron (auto-run daily)
bash /path/to/research-note-generator/scripts/setup_cron.sh

# Install Ollama (optional, for free local AI)
curl -fsSL https://ollama.com/install.sh | sh
ollama pull llama3.1:8b
```

---

## Daily Log



---

# 2026-02-09 (Mon)

## Changes Summary

cron 스크립트 수정 작업 진행 중. 주요 변경사항:
- AI 백엔드 의무화: no-AI fallback 모드 제거
- fnmatch 루트 레벨 매칭 수정 및 전체 프로젝트 연구 노트 생성
- Ollama 설치 옵션을 포함한 AI 백엔드 감지 추가
- cron 자동 실행 기본값을 Yes로 변경

현재 `scripts/run_cron.sh`와 `scripts/setup_cron.sh` 파일이 수정 중인 상태.

## Key Changes Detail

**Modified Files:**
- `scripts/run_cron.sh` - cron 실행 스크립트 수정 중
- `scripts/setup_cron.sh` - cron 설정 스크립트 수정 중

**Recent Commits:**
- `6e31c9b`: AI 백엔드를 필수로 만들고 AI 없는 fallback 모드 제거
- `8c27241`: fnmatch 루트 레벨 매칭 버그 수정 + 전체 프로젝트 연구 노트 생성 기능
- `5747a8e`: AI 백엔드 우선순위 재정렬 및 no-AI 가이드 추가
- `79467cd`: Ollama 설치 옵션이 포함된 AI 백엔드 감지 기능 추가
- `9808f55`: cron 자동 실행 기본값을 Yes (Y/n)로 변경

**New Files (Initial Setup):**
프로젝트는 일일 연구 노트 자동 생성 시스템으로, 다음 구성 요소로 이루어짐:
- `generate_note.py`: 메인 노트 생성 스크립트
- `config.yaml`: 프로젝트 설정 파일
- `setup.sh`, `install.sh`: 설치 및 설정 스크립트
- `templates/`: 노트 템플릿 디렉토리
- `.github/workflows/daily_note.yml`: GitHub Actions 워크플로우

## Architecture Updates

**연구 노트 자동 생성 시스템:**
```
research_note_generator/
├── generate_note.py          # 핵심 생성 로직
├── config.yaml               # 프로젝트별 설정
├── setup.sh / install.sh     # 설치 자동화
├── scripts/
│   ├── run_cron.sh          # cron 실행 (수정 중)
│   └── setup_cron.sh        # cron 설정 (수정 중)
├── templates/               # 마크다운 템플릿
└── .github/workflows/       # CI/CD 자동화
```

**주요 설계 특징:**
- Git 기반 변경사항 추적
- AI 백엔드 (OpenAI/Anthropic/Ollama) 필수 사용
- Cron 스케줄링으로 자동 실행
- 이메일 알림 기능 (Gmail SMTP)
- 다중 프로젝트 지원

## Issues & Solutions (증상→원인→시도→해결)

**Issue 1: AI 백엔드 없이 실행 시 품질 저하**
- 증상: AI 없는 fallback 모드에서 단순 diff 기반 노트 생성으로 품질 저하
- 원인: AI 분석 없이는 의미 있는 인사이트 생성 불가
- 시도: AI 백엔드를 옵션으로 제공
- 해결: `6e31c9b` 커밋에서 AI 백엔드를 필수로 변경, fallback 모드 제거

**Issue 2: fnmatch 루트 레벨 파일 매칭 실패**
- 증상: 루트 디렉토리의 파일들이 패턴 매칭에서 누락
- 원인: fnmatch 패턴이 경로 구분자를 고려하지 못함
- 해결: `8c27241` 커밋에서 루트 레벨 매칭 로직 수정 및 전체 프로젝트 노트 생성 기능 추가

**Issue 3: Cron 자동 실행 설정 불편**
- 증상: 사용자가 cron 자동 실행을 원하는데 기본값이 No
- 원인: 보수적인 기본값 설정
- 해결: `9808f55` 커밋에서 기본값을 Yes (Y/n)로 변경

## Training / Experiment Status

N/A - 이 프로젝트는 연구 노트 생성 도구로, 모델 학습이나 실험을 수행하지 않음.

## Lessons Learned

1. **AI 통합의 중요성**: 단순 diff 기반 접근보다 LLM을 활용한 분석이 훨씬 의미 있는 인사이트 제공. 옵션으로 제공하기보다는 필수 요구사항으로 만드는 것이 품질 보장에 효과적.

2. **fnmatch 패턴 매칭의 함정**: 파일 경로 매칭 시 루트 레벨과 하위 디렉토리를 다르게 처리해야 함. 경로 구분자를 고려한 패턴 설계 필요.

3. **UX 기본값의 중요성**: 사용자 대다수가 원하는 옵션을 기본값으로 설정하면 설정 과정이 더 직관적. cron 자동 실행을 opt-out 방식으로 변경하여 사용성 개선.

4. **점진적 개선**: 초기 커밋부터 현재까지 사용자 피드백을 반영한 15개의 커밋으로 지속적 개선. 설치 프로세스 단순화 (one-line installer), 이메일 설정 가이드 개선, multi-project 지원 등.

---

---

# 2026-02-10 (Tue)

## Changes Summary

| 구분 | 파일 | 변경 요약 |
|------|------|-----------|
| NEW | `.github/workflows/daily_note.yml` | GitHub Actions 워크플로우 (일간/주간 리포트 자동화) |
| NEW | `README.md` | 프로젝트 문서 (설치, 사용법, 설정) |
| NEW | `config.yaml` | 프로젝트 설정 파일 (경로, 이메일, AI 백엔드) |
| NEW | `generate_note.py` | 핵심 노트 생성 스크립트 (git 분석, AI 요약) |
| NEW | `install.sh` | 원라인 설치 스크립트 (curl pipe 호환) |
| NEW | `scripts/run_cron.sh` | cron 실행 스크립트 |
| NEW | `scripts/setup_cron.sh` | cron 작업 설정 스크립트 |
| NEW | `setup.sh` | 대화형 설정 마법사 |
| NEW | `templates/daily_entry.md` | 일간 엔트리 템플릿 |
| NEW | `templates/initial_note.md` | 초기 노트 템플릿 |

## Key Changes Detail

### 프로젝트 초기 구조 완성
- **자동화된 연구 노트 생성기**: git 변경사항 기반으로 일간/주간 연구 노트 자동 생성
- **AI 백엔드 지원**: Claude API, Ollama (로컬), OpenAI 순으로 자동 감지
- **다중 프로젝트 지원**: 하나의 설정 파일로 여러 프로젝트 관리 가능

### 주요 기능
- `generate_note.py`: git diff/log 분석 → AI 요약 → 마크다운 생성
- `setup.sh`: 프로젝트 자동 감지, 이메일 설정, AI 백엔드 선택
- GitHub Actions: daily (매일 23:50 KST), weekly (월요일 00:00 KST)

## Architecture Updates

```
research_note_generator/
├── generate_note.py      # 핵심 로직 (git 분석 + AI 요약)
├── config.yaml           # 프로젝트/이메일/AI 설정
├── templates/            # 마크다운 템플릿
├── scripts/              # cron 관련 스크립트
├── .github/workflows/    # CI/CD 자동화
└── setup.sh / install.sh # 설치 스크립트
```

## Issues & Solutions (증상→원인→시도→해결)

### 1. curl pipe에서 stdin 문제
- **증상**: `curl -fsSL ... | bash` 실행 시 대화형 입력 불가
- **원인**: stdin이 curl 출력으로 점유됨
- **시도**: 다양한 fd 리디렉션 방식
- **해결**: `exec < /dev/tty`로 stdin 복원 (a814594, eec58dd)

### 2. AI 백엔드 필수화
- **증상**: AI 없이 실행 시 의미 없는 노트 생성
- **원인**: fallback 모드가 단순 파일 목록만 출력
- **시도**: no-AI 가이드 추가
- **해결**: AI 백엔드를 필수로 변경, Ollama 설치 옵션 제공 (6e31c9b)

### 3. HTML 주석 제거 문제
- **증상**: 생성된 노트에 `<!-- -->` 주석 잔존
- **원인**: AI가 템플릿 주석을 그대로 출력
- **해결**: AI 프롬프트에 주석 제거 명시 (c6fcf1a)

## Training / Experiment Status

| 항목 | 상태 | 비고 |
|------|------|------|
| Claude API 연동 | ✅ 완료 | 기본 백엔드 |
| Ollama 연동 | ✅ 완료 | 로컬 대안 |
| GitHub Actions | ✅ 완료 | 일간/주간 자동화 |
| 이메일 발송 | ✅ 완료 | SMTP 지원 |

## Lessons Learned

1. **curl pipe 호환성**: 설치 스크립트 작성 시 `exec < /dev/tty` 패턴 필수
2. **AI 의존성 명확화**: fallback 없이 명확한 요구사항 제시가 사용자 경험에 유리
3. **fnmatch 패턴**: 루트 레벨 파일 매칭 시 `**` 패턴과 명시적 파일명 패턴 병행 필요

---

---

# 2026-02-10 (Tue)

## Changes Summary

| 카테고리 | 파일 | 변경 요약 |
|---------|------|----------|
| CI/CD | `.github/workflows/daily_note.yml` | GitHub Actions 워크플로우로 일일 노트 자동 생성 |
| Core | `generate_note.py` | AI 기반 연구 노트 생성 메인 스크립트 |
| Config | `config.yaml` | 프로젝트 설정 (경로, 이메일, AI 백엔드) |
| Setup | `setup.sh`, `install.sh` | 대화형 설정 마법사 및 원라인 설치 스크립트 |
| Scripts | `scripts/run_cron.sh`, `scripts/setup_cron.sh` | Cron 기반 자동 실행 스크립트 |
| Templates | `templates/daily_entry.md`, `templates/initial_note.md` | 일일/초기 노트 템플릿 |
| Docs | `README.md` | 프로젝트 문서 |

## Key Changes Detail

### AI 백엔드 필수화 (6e31c9b)
- No-AI 폴백 모드 완전 제거
- Claude API, Ollama, OpenAI 중 하나 필수 사용
- AI 없이는 의미 있는 연구 노트 생성 불가능하다는 판단

### Cron 스케줄 조정 (c26adb8)
- 00:00 → 23:59로 변경
- 하루 마무리 시점에 해당일 작업 내용 캡처

### 주간 리포트 기능 추가 (2627742)
- 월요일에 daily + weekly 모두 생성
- 주간 단위 회고 지원

## Architecture Updates

```
research_note_generator/
├── generate_note.py      # 메인 진입점 (git diff 분석 → AI 요약)
├── config.yaml           # 프로젝트별 설정
├── setup.sh              # 대화형 설정 (curl | bash 지원)
├── scripts/
│   ├── run_cron.sh       # 크론 실행 래퍼
│   └── setup_cron.sh     # 크론 등록 스크립트
└── templates/            # 마크다운 템플릿
```

- **AI 백엔드 우선순위**: Claude API → Ollama → OpenAI
- **설치 방식**: `curl -sL ... | bash` 원라인 설치 지원

## Issues & Solutions

| 증상 | 원인 | 시도 | 해결 |
|------|------|------|------|
| curl 파이프 시 사용자 입력 불가 | stdin이 curl 출력에 연결됨 | - | `/dev/tty`에서 stdin 리다이렉트 (eec58dd) |
| echo 색상 코드 출력 안됨 | `-e` 플래그 누락 | - | echo에 `-e` 플래그 추가 (fb7d66d) |
| 섹션 7 HTML 주석 잔존 | AI가 템플릿 주석 제거 안함 | 프롬프트 수정 | AI에게 주석 제거 명시적 지시 (c6fcf1a) |

## Training / Experiment Status

| 실험명 | 상태 | 비고 |
|--------|------|------|
| N/A | - | 본 프로젝트는 도구 개발 프로젝트 |

## Lessons Learned

- **curl 파이프 설치 시 stdin 처리**: 대화형 스크립트는 반드시 `/dev/tty`에서 입력받아야 함
- **크론 타이밍**: 일일 기록은 자정 직전(23:59)이 해당일 작업 캡처에 유리
- **AI 필수 의존성**: 의미 있는 자동 요약에는 AI가 필수, 폴백 모드는 오히려 혼란 유발

---

---

# 2026-02-10 (Tue)

## Changes Summary
NEW: 10 files, 2637 lines

## Key Changes Detail
* feat: add weekly report to cron (daily + weekly on Monday)
* feat: make AI backend mandatory, remove no-AI fallback mode
* fix: change cron schedule from 00:00 to 23:59

## Architecture Updates
* Separate sender/receiver emails in setup wizard
* Improve email setup: detailed step-by-step app password guide

## Issues & Solutions
* None reported

## Training / Experiment Status
* Not applicable

## Lessons Learned
* None reported

---

---

# 2026-02-11 (Wed)

## Changes Summary
NEW (10):
  + .github/workflows/daily_note.yml
  + README.md
  + config.yaml
  + generate_note.py
  + install.sh
  + scripts/run_cron.sh
  + scripts/setup_cron.sh
  + setup.sh
  + templates/daily_entry.md
  + templates/initial_note.md

## Key Changes Detail
  ecc4f45 fix: remove timeout limit for Claude CLI in daily generation
  dcaa98a fix: add missing 'path' and 'date' keys in mtime backfill
  311cc95 feat: add mtime-based backfill for non-git folders
  c89494a fix: remove placeholder comment even when backfill is skipped

## Architecture Updates
  fb4a710 feat: add placeholder removal and git history backfill
  9918dd7 fix: improve init output cleaning (remove AI preamble)
  3410ebe fix: remove first daily note generation on install
  cbd1b45 fix: remove timeout limit for init (allow infinite wait)

## Issues & Solutions
  c26adb8 fix: change cron schedule from 00:00 to 23:59
  c6fcf1a fix: ensure AI removes HTML comments in section 7

## Training / Experiment Status
  fd24c81 fix: move init/daily generation after setup complete message
  2627742 feat: add weekly report to cron (daily + weekly on Monday)

## Lessons Learned
  6e31c9b feat: make AI backend mandatory, remove no-AI fallback mode
  8c27241 feat: fix fnmatch root-level matching + generate full project research note

---

---

# 2026-02-11 (Wed)

## Changes Summary
NEW (10):
  + .github/workflows/daily_note.yml
  + README.md
  + config.yaml
  + generate_note.py
  + install.sh
  + scripts/run_cron.sh
  + scripts/setup_cron.sh
  + setup.sh
  + templates/daily_entry.md
  + templates/initial_note.md

## Key Changes Detail
COMMITS:
  ecc4f45 fix: remove timeout limit for Claude CLI in daily generation
  dcaa98a fix: add missing 'path' and 'date' keys in mtime backfill
  311cc95 feat: add mtime-based backfill for non-git folders
  c89494a fix: remove placeholder comment even when backfill is skipped
  fb4a710 feat: add placeholder removal and git history backfill
  9918dd7 fix: improve init output cleaning (remove AI preamble)
  3410ebe fix: remove first daily note generation on install
  cbd1b45 fix: remove timeout limit for init (allow infinite wait)
  9f18608 fix: GitHub Actions workflow directory path error
  c26adb8 fix: change cron schedule from 00:00 to 23:59

## Architecture Updates
STATS: 10 files, 2859 lines

## Issues & Solutions
None reported

## Training / Experiment Status
Not applicable

## Lessons Learned
None noted

---

---

# 2026-02-11 (Wed)

## Changes Summary
| 구분 | 파일 | 변경 |
|------|------|------|
| NEW | `.github/workflows/daily_note.yml` | GitHub Actions 워크플로우 |
| NEW | `README.md` | 프로젝트 문서화 |
| NEW | `config.yaml` | 설정 파일 |
| NEW | `generate_note.py` | 메인 노트 생성 스크립트 |
| NEW | `install.sh` | 원라인 설치 스크립트 |
| NEW | `scripts/run_cron.sh` | 크론 실행 스크립트 |
| NEW | `scripts/setup_cron.sh` | 크론 설정 스크립트 |
| NEW | `setup.sh` | 대화형 설정 마법사 |
| NEW | `templates/daily_entry.md` | 일일 노트 템플릿 |
| NEW | `templates/initial_note.md` | 초기 노트 템플릿 |

## Key Changes Detail
- **Research Note Generator 프로젝트 초기 구축 완료**: Git 변경사항을 기반으로 일일 연구 노트를 자동 생성하는 도구
- **AI 백엔드 통합**: Claude CLI를 기본 AI 백엔드로 사용하여 노트 생성
- **mtime 기반 백필 기능**: Git이 아닌 폴더에서도 파일 수정 시간 기반으로 변경 이력 추적 가능
- **GitHub Actions 워크플로우**: 매일 23:59에 자동으로 노트 생성 및 커밋
- **원라인 설치 지원**: `curl | bash` 방식의 간편 설치 스크립트 제공

## Architecture Updates
```
research_note_generator/
├── .github/workflows/    # CI/CD 자동화
│   └── daily_note.yml    # 일일 노트 생성 워크플로우
├── scripts/              # 유틸리티 스크립트
│   ├── run_cron.sh       # 크론 작업 실행
│   └── setup_cron.sh     # 크론 설정
├── templates/            # 마크다운 템플릿
│   ├── daily_entry.md    # 일일 항목 템플릿
│   └── initial_note.md   # 초기 노트 템플릿
├── config.yaml           # 프로젝트 설정
├── generate_note.py      # 핵심 생성 로직
├── setup.sh              # 대화형 설정
└── install.sh            # 원라인 설치
```

## Issues & Solutions
| 증상 | 원인 | 시도 | 해결 |
|------|------|------|------|
| Claude CLI 타임아웃 발생 | 긴 노트 생성 시 기본 타임아웃 초과 | 타임아웃 값 증가 | 타임아웃 제한 완전 제거 (`ecc4f45`) |
| mtime 백필 시 KeyError | `path`와 `date` 키 누락 | 딕셔너리 구조 확인 | 누락된 키 추가 (`dcaa98a`) |
| curl 파이프 시 stdin 문제 | `curl \| bash` 실행 시 stdin이 curl 출력으로 연결됨 | - | `/dev/tty`에서 stdin 복원 (`a814594`) |
| AI 응답에 불필요한 프리앰블 포함 | AI가 인사말/설명 추가 | 프롬프트 개선 | 출력 클리닝 로직 추가 (`9918dd7`) |

## Training / Experiment Status
| 항목 | 상태 | 비고 |
|------|------|------|
| 프로젝트 초기화 | ✅ 완료 | 28개 커밋으로 안정화 |
| AI 백엔드 통합 | ✅ 완료 | Claude CLI 사용 |
| GitHub Actions | ✅ 완료 | 매일 23:59 실행 |
| 주간 리포트 | ✅ 완료 | 월요일 자동 생성 |

## Lessons Learned
- **AI 출력 신뢰성**: AI 응답은 항상 후처리가 필요함 - 프리앰블 제거, HTML 코멘트 정리 등
- **타임아웃 설계**: AI 기반 작업은 실행 시간 예측이 어려우므로 무제한 또는 넉넉한 타임아웃 설정 권장
- **curl 파이프 패턴**: `curl | bash` 설치 스크립트에서 사용자 입력이 필요한 경우 `/dev/tty` 리다이렉션 필수
- **점진적 기능 추가**: No-AI 폴백 모드를 제거하고 AI 백엔드를 필수로 전환하여 코드 복잡도 감소

---

