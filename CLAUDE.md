# MyProject - Claude Code 프로젝트 설정

## 검색 규칙
- 코드 검색 시 AI-grep을 먼저 사용할 것 (상세: `.guides/SEARCH_GUIDE.md`)
- Windows: `PYTHONIOENCODING=utf-8 python .search/ai-grep [command]`

## 프로젝트 개요

프로젝트 설명을 입력하세요

- **기술 스택**: 언어, 프레임워크, 런타임
- **라이브러리**: 주요 라이브러리 목록
- **출력 포맷**: 출력 포맷
- **기능 카테고리**: 기능 카테고리 목록
- **상세 정보**: PROJECT_SUMMARY.md 참조

### 프로젝트 구조

프로젝트 폴더 구조 설명

프로젝트 도메인 규칙

## 아키텍처
- **템플릿 엔진**: `init.ps1` / `init.sh` (설정 기반 프로젝트 파일 생성)
- **프리셋**: `presets/` (사전 정의된 설정 프로필)
- **템플릿 파일**: `*.tmpl` (Mustache 스타일 변수 치환 대상)
- **생성 결과물**: `AGENTS.md`, `PROJECT_SUMMARY.md`, `WORK_IN_PROGRESS.md` 등
- **워크플로우**: `WORKFLOW_PLANNING/` (파이프라인, 게이트, WIP 관리)
- **명령어**: `.claude/commands/` (커스텀 슬래시 명령어)
- **가이드**: `.guides/` (빌드, 코드 스타일, 테스트 등 개발 가이드)

## 핵심 흐름
`template-config.json` 설정 → `init.ps1`/`init.sh` 실행 → `.tmpl` 파일 렌더링 → 프로젝트 파일 생성 → Claude Code 워크플로우 활성화

## 도메인 용어
- **WIP**: Work In Progress, 작업 추적 단위 (`WORK_IN_PROGRESS.md`)
- **Gate**: 파이프라인 단계별 검증 관문 (`WORKFLOW_PLANNING/GATES.md`)
- **파이프라인**: Plan→Design→Code→Test→Docs→QA→Review 워크플로우 (`WORKFLOW_PLANNING/PIPELINE.md`)
- **프리셋**: lite/standard/full 등 사전 정의된 설정 프로필 (`presets/`)

---

## 참조 문서

문서 목록, 개발 가이드, 단축 지시법 → `QUICK_REFERENCE.md` 참조

---

## 절대 규칙 (Hard Blocks)

> AGENTS.md의 절대 규칙 섹션을 반드시 준수하세요.

핵심 규칙 요약:
- **타입 안전성**: 타입 안전성 규칙을 입력하세요
- **빈 catch 블록 금지**: catch(e) {} 사용 금지
- **추측 금지**: 모호한 요청은 반드시 사용자에게 확인

> 이름/값 수정 규칙, 파이프라인 강제 규칙, 수렴 검증 프로토콜 → `.guides/DEVELOPMENT_RULES.md` 참조

---

## 커스텀 명령어

`.claude/commands/` 디렉토리에 명령어가 정의되어 있습니다.
`/project:명령어`로 전체 목록을 확인하세요.

주요 명령어:
- `/project:신규 [--lite|--standard|--full] [기능 설명]` - 새로운 기능 추가
- `/project:수정 [--lite|--standard|--full] [문제 설명]` - 버그 수정 또는 기능 개선
- `/project:간편 [작업 설명]` - 파이프라인 생략, 최소 검증만 수행
- `/project:커밋` - 변경 사항 커밋 (메시지 자동 생성)
- `/project:전송` - 스테이징 → 커밋 → 푸시 한번에
- `/project:상태 전체` - 전체 작업 상태 확인

---

## 워크플로우
Plan→Design→Code→Test→Docs→QA→Review. 상세 프로세스 및 WIP 추적은 `WORKFLOW_PLANNING/INDEX.md` 참조.

---

## 빌드 및 실행

```bash
빌드 명령어

테스트 명령어

실행 명령어

CLI 옵션 설명
```

## 명명 규칙

명명 규칙 설명
