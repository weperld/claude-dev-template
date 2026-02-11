# Claude Code 개발 자동화 템플릿

Claude Code와 함께 사용하는 개발 자동화 시스템입니다.
파이프라인, Gate 검증, WIP 추적, 커스텀 명령어를 프로젝트에 세팅합니다.

---

## Quick Setup

### For Human

아래 텍스트를 복사하여 **새 프로젝트의 Claude Code**에 붙여넣기 하세요.
그 이후로는 에이전트의 질문에 답하기만 하면 세팅이 완료됩니다.

```
개발 자동화 시스템을 현재 프로젝트에 세팅해줘.
세팅 가이드: https://raw.githubusercontent.com/weperld/claude-dev-template/main/SETUP_GUIDE.md
```

> 에이전트가 세팅 가이드를 읽고 프로젝트 정보를 질문합니다.
> 답변을 마치면 에이전트가 템플릿 저장소를 클론하여 자동 세팅합니다.

---

### For Agent

> 이 섹션은 에이전트가 읽는 부분입니다. Human은 건너뛰어도 됩니다.

**에이전트 세팅 절차:**

1. **세팅 가이드 읽기**: 위 URL 또는 이 저장소의 `SETUP_GUIDE.md`를 읽으세요.
   - 가이드에 Phase 1~5 전체 절차가 정의되어 있습니다.

2. **템플릿 파일 가져오기**: 이 저장소를 사용자 프로젝트의 임시 디렉토리에 클론하세요.
   ```bash
   git clone https://github.com/weperld/claude-dev-template.git _template_temp
   ```

3. **SETUP_GUIDE.md의 Phase 1~5를 순서대로 진행**:
   - Phase 1: 사용자에게 프로젝트 정보 질문
   - Phase 2: `template-config.json` 생성
   - Phase 3: 템플릿 파일 복사 및 변수 치환 (init.ps1/init.sh 또는 직접 수행)
   - Phase 4: 스켈레톤 가이드 작성 (사용자와 함께)
   - Phase 5: 검증

4. **정리**: 세팅 완료 후 임시 디렉토리 `_template_temp/` 삭제

**참고 파일:**
- `SETUP_GUIDE.md` - 전체 세팅 절차 및 변수 치환 참조표
- `template-config.example.json` - ExcelBinder 프로젝트 실제 설정 예시

---

## 포함 내용

### 파이프라인 (3가지 프리셋)

| 프리셋 | 단계 | 용도 |
|--------|------|------|
| **lite** | Plan → Code → Review | 소규모/빠른 작업 |
| **standard** | Plan → Code → Test → Docs → Review | 일반 프로젝트 |
| **full** | Plan → Design → Code → Test → Docs → QA → Review | 대규모/엄격한 프로젝트 |

### 커스텀 명령어 (14개)

| 명령어 | 용도 |
|--------|------|
| `/project:신규` | 새 기능 추가 (파이프라인 전체 실행) |
| `/project:수정` | 버그 수정 또는 기능 개선 |
| `/project:긴급버그` | 긴급 핫픽스 |
| `/project:상태` | 작업 상태 확인 |
| `/project:완료` | WIP 작업 완료 처리 |
| `/project:취소` | WIP 작업 취소 |
| `/project:작업이어하기` | 이전 작업 재개 |
| `/project:내보내기` | 완료/취소 작업 아카이브 |
| `/project:요약` | 프로젝트 3줄 요약 |
| `/project:커밋` | 변경 사항 커밋 (메시지 자동 생성) |
| `/project:전송` | 스테이징 → 커밋 → 푸시 |
| `/project:푸시` | 원격 저장소 푸시 |
| `/project:릴리즈` | 버전 태그 생성 및 릴리즈 |
| `/project:명령어` | 명령어 목록 조회 |

### 시스템 구성

- **Gate 검증**: 각 파이프라인 단계의 통과 조건 + 크로스체크
- **수렴 검증**: 분석/계획/설계 단계에서 필수 보완 사항 0건까지 반복 점검
- **WIP 추적**: WorkID 기반 작업 관리 (WIP-YYYYMMDD-NNN)
- **에이전트 시스템**: 역할별 에이전트 (analyst, architect, developer, tester, reviewer 등)
- **에러 핸들링**: 롤백 프로토콜, 충돌 방지
- **자동 업데이트**: 상태 전이, 진행률 추적

---

## 수동 세팅

에이전트 없이 직접 세팅하려면:

1. 이 저장소를 클론
2. `template-config.json`을 프로젝트에 맞게 수정 (참고: `template-config.example.json`)
3. 초기화 스크립트 실행:
   - Windows: `.\init.ps1` (PowerShell)
   - Linux/macOS: `./init.sh` (Bash, jq 필요)
4. 생성된 파일들을 프로젝트 루트로 복사
5. `.guides/` 스켈레톤 파일 내용 작성

---

## 디렉토리 구조

```
claude-dev-template/
├── SETUP_GUIDE.md                # 에이전트용 세팅 가이드
├── template-config.json          # 설정 파일 (빈 템플릿)
├── template-config.example.json  # 설정 예시 (ExcelBinder 기준)
├── init.ps1                      # 초기화 스크립트 (Windows PowerShell)
├── init.sh                       # 초기화 스크립트 (Linux/macOS Bash)
├── METHOD_B_REFERENCE.md         # 방법 B 수동 치환 참조 가이드
├── README.md                     # 이 파일
│
├── *.md.tmpl                     # 변수 치환 템플릿 (11개)
├── *.md                          # 범용 파일 (그대로 복사)
│
├── .claude/commands/             # 커스텀 명령어 14개
├── .guides/                      # 개발 가이드 + 스켈레톤
├── .wips/                        # WIP 메타 템플릿 + 설정
├── presets/                      # 파이프라인 프리셋 (lite/standard/full)
└── WORKFLOW_PLANNING/            # 워크플로우 모듈 (6개)
```

---

## 라이선스

이 템플릿은 자유롭게 사용 가능합니다.
