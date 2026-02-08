# research_note_generator
## Project Description

> **Project**: research_note_generator
> **Author**: seokwon
> **Started**: 2026-02-09
> **Last Updated**: 2026-02-09
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

<!-- 날짜별 엔트리가 여기 아래에 최신순으로 쌓입니다 -->