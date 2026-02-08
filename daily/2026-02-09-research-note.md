# research_note_generator - Daily Research Note
> **Date**: 2026-02-09 (Mon)
> **Project**: research_note_generator


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
