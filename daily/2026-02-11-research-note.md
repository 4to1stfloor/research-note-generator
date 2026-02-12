# research_note_generator - Daily Research Note
> **Date**: 2026-02-11 (Wed)
> **Project**: research_note_generator


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
