# research_note_generator - Daily Research Note
> **Date**: 2026-02-09 (Mon)
> **Project**: research_note_generator


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
