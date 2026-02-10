# 프로젝트 세팅 가이드 (에이전트용)

> 이 문서는 Claude Code 에이전트가 읽고, 사용자와 대화하며 프로젝트에 개발 자동화 시스템을 세팅하기 위한 가이드입니다.
>
> **에이전트 진행 순서**: 이 가이드를 읽기 (URL) → Phase 1~2 진행 → 저장소 클론 → Phase 3~5 진행 → 임시 디렉토리 삭제
>
> **템플릿 저장소**: https://github.com/weperld/claude-dev-template

---

## 개요

이 템플릿은 다음을 제공합니다:
- **7단계 파이프라인**: Plan → Design → Code → Test → Docs → QA → Review
- **Gate 검증 시스템**: 각 단계 통과 조건 + 크로스체크
- **WIP 추적**: WorkID 기반 작업 관리 (WIP-YYYYMMDD-NN)
- **14개 커스텀 명령어**: 신규, 수정, 긴급버그, 상태, 완료, 취소, 작업이어하기, 내보내기, 요약, 커밋, 전송, 푸시, 릴리즈, 명령어
- **에이전트 시스템**: 역할별 에이전트 (analyst, architect, developer, tester, doc-manager, reviewer, coordinator)
- **에러 핸들링**: 롤백 프로토콜, 충돌 방지

---

## 세팅 절차

### Phase 1: 프로젝트 정보 수집

사용자에게 다음 정보를 질문하세요. 한 번에 모든 것을 물어보지 말고, 카테고리별로 나눠서 진행합니다.

#### 1-1. 기본 정보

```
질문할 내용:
- 프로젝트 이름은 무엇인가요?
- 프로젝트를 한 줄로 설명해주세요.
- 프로젝트 루트 경로는 어디인가요? (예: D:\MyProject)
```

#### 1-2. 기술 스택

```
질문할 내용:
- 기술 스택은 무엇인가요? (언어, 프레임워크, 런타임)
  예시: "C#, WPF, .NET 10.0" / "TypeScript, React, Node.js 22" / "Python 3.12, FastAPI"
- 주요 라이브러리는 무엇인가요?
  예시: "NPOI 2.7.5, Newtonsoft.Json 13.0.4" / "axios, zustand, tailwind"
```

#### 1-3. 빌드 및 실행

```
질문할 내용:
- 빌드 명령어는 무엇인가요?
  예시: "dotnet build MyProject/" / "npm run build" / "python -m build"
- 테스트 명령어는 무엇인가요?
  예시: "dotnet test MyProject.Tests/" / "npm test" / "pytest"
- 실행 명령어는 무엇인가요?
  예시: "dotnet run --project MyProject/" / "npm start" / "python main.py"
- 프로젝트 파일명은 무엇인가요?
  예시: "MyProject.csproj" / "package.json" / "pyproject.toml"
```

#### 1-4. 프로젝트 구조

```
질문할 내용 (프로젝트 루트를 직접 확인하여 파악하는 것을 권장):
- 프로젝트 폴더 구조를 설명해주세요.
- 명명 규칙은 무엇인가요?
  예시: "PascalCase 클래스/메서드, _camelCase private 필드"
- 기능 카테고리가 있다면 무엇인가요?
- 출력 포맷이 있다면 무엇인가요?
- CLI 옵션이 있다면 설명해주세요.
- 프로젝트 도메인의 특수 규칙이 있나요?
```

#### 1-5. 언어별 규칙

```
질문할 내용:
- 타입 안전성 관련 규칙이 있나요?
  예시 (C#): "무조건 캐스팅 (Type)cast 남용 금지, dynamic 사용 최소화"
  예시 (TS): "any 사용 금지, strict mode 필수"
  예시 (Python): "type hint 필수, mypy strict 통과"
- 피해야 할 안티패턴이 있나요?
- 코드 검증 시 확인할 체크리스트 항목은 무엇인가요?
```

#### 1-6. 파이프라인 깊이

```
질문할 내용:
- 파이프라인 깊이를 선택해주세요:
  1. lite (3단계): Plan → Code → Review - 소규모/빠른 작업
  2. standard (5단계): Plan → Code → Test → Docs → Review - 일반 프로젝트
  3. full (7단계): Plan → Design → Code → Test → Docs → QA → Review - 대규모/엄격한 프로젝트

  권장: 처음 사용한다면 standard, 팀 프로젝트라면 full
```

---

### Phase 2: template-config.json 생성

수집한 정보로 `template-config.json`을 생성합니다.

```json
{
  "project": {
    "name": "[프로젝트 이름]",
    "description": "[프로젝트 설명]",
    "techStack": "[기술 스택]",
    "libraries": "[라이브러리 목록]",
    "buildCommand": "[빌드 명령어]",
    "testCommand": "[테스트 명령어]",
    "runCommand": "[실행 명령어]",
    "projectFile": "[프로젝트 파일명]",
    "projectStructure": "[프로젝트 구조 설명]",
    "namingConventions": "[명명 규칙]",
    "featureCategories": "[기능 카테고리]",
    "outputFormats": "[출력 포맷]",
    "cliOptions": "[CLI 옵션]",
    "domainRules": "[도메인 규칙]"
  },
  "pipeline": {
    "preset": "[lite/standard/full]"
  },
  "languageRules": {
    "typeSafety": "[타입 안전성 규칙]",
    "antiPatterns": "[안티패턴]",
    "architectRules": "[아키텍트용 언어 규칙]",
    "developerRules": "[개발자용 언어 규칙]",
    "validationItems": "[검증 체크리스트 - 마크다운 체크박스 형식]",
    "designReviewItems": "[설계 리뷰 항목]"
  }
}
```

**참고**: `template-config.example.json`에 ExcelBinder 프로젝트의 실제 설정 예시가 있습니다.

---

### Phase 3: 템플릿 복사 및 초기화

#### 준비: 템플릿 저장소 클론

```bash
# 프로젝트 루트에서 실행
git clone https://github.com/weperld/claude-dev-template.git _template_temp
```

#### 방법 A: init.ps1 사용 (Windows PowerShell)

```powershell
# 1. 생성한 template-config.json을 임시 디렉토리에 배치
Copy-Item "[생성한 config 경로]" "_template_temp\template-config.json"

# 2. init.ps1 실행
Set-Location "_template_temp"
.\init.ps1

# 3. 생성된 파일들을 프로젝트 루트로 이동
# 아래 파일/디렉토리를 프로젝트 루트로 복사:
#   - CLAUDE.md, AGENTS.md, AGENT_ROLES.md, PROJECT_SUMMARY.md
#   - QUICK_REFERENCE.md, WORK_IN_PROGRESS.md
#   - WORKFLOW_PLANNING/ (디렉토리 전체)
#   - .claude/commands/ (디렉토리 전체)
#   - .guides/ (디렉토리 전체)
#   - .wips/ (디렉토리 전체, templates/와 active/ 포함)

# 4. 임시 디렉토리 정리
Set-Location ..
Remove-Item "_template_temp" -Recurse -Force
```

#### 방법 B: 에이전트가 직접 수행 (크로스 플랫폼, 권장)

에이전트가 다음 순서로 직접 파일을 생성/복사합니다:

1. **범용 파일 복사** (변수 치환 없이 그대로):
   - `AGENT_ROLES.md` → 프로젝트 루트
   - `WORK_IN_PROGRESS.md` → 프로젝트 루트
   - `WORKFLOW_PLANNING/PIPELINE.md` → 프로젝트 루트
   - `WORKFLOW_PLANNING/AUTO_UPDATE.md` → 프로젝트 루트
   - `WORKFLOW_PLANNING/ERROR_HANDLING.md` → 프로젝트 루트
   - `WORKFLOW_PLANNING/REPORTS.md` → 프로젝트 루트
   - `WORKFLOW_PLANNING/INDEX.md` → 프로젝트 루트
   - `.guides/COMMIT_RULES.md` → 프로젝트 루트
   - `.guides/utils/generate_workid.ps1` → 프로젝트 루트
   - `.guides/utils/generate_workid.py` → 프로젝트 루트
   - `.claude/commands/` 12개 범용 명령어 → 프로젝트 루트

2. **템플릿 파일 치환 후 생성** (`.tmpl` 파일의 `{{변수}}`를 치환):
   - `CLAUDE.md.tmpl` → `CLAUDE.md`
   - `AGENTS.md.tmpl` → `AGENTS.md`
   - `PROJECT_SUMMARY.md.tmpl` → `PROJECT_SUMMARY.md`
   - `QUICK_REFERENCE.md.tmpl` → `QUICK_REFERENCE.md`
   - `WORKFLOW_PLANNING/GATES.md.tmpl` → `WORKFLOW_PLANNING/GATES.md`
   - `.claude/commands/릴리즈.md.tmpl` → `.claude/commands/릴리즈.md`
   - `.claude/commands/명령어.md.tmpl` → `.claude/commands/명령어.md`
   - `.guides/WORKFLOW_GUIDE.md.tmpl` → `.guides/WORKFLOW_GUIDE.md`
   - `.guides/PLANNING_TEMPLATE.md.tmpl` → `.guides/PLANNING_TEMPLATE.md`

3. **WIP 템플릿 생성** (`META-TEMPLATE.md` + `stages.json` 조합):
   - 프리셋에 포함된 각 스테이지별로 WIP 템플릿 생성
   - `.wips/templates/WIP-{Stage}-YYYYMMDD-NN.md`

4. **디렉토리 구조 생성**:
   - `.wips/active/{Stage}/` (각 스테이지별)
   - `.wips/archive/`

5. **스켈레톤 파일 복사** (사용자가 내용을 채울 파일):
   - `.guides/BUILD_GUIDE.example.md` → `.guides/BUILD_GUIDE.md`
   - `.guides/CODE_STYLE.example.md` → `.guides/CODE_STYLE.md`
   - `.guides/TECHNICAL_RULES.example.md` → `.guides/TECHNICAL_RULES.md`
   - `.guides/TEST_GUIDE.example.md` → `.guides/TEST_GUIDE.md`

---

### Phase 4: 스켈레톤 가이드 작성

생성된 4개의 스켈레톤 파일은 프로젝트에 맞게 내용을 채워야 합니다.
사용자와 함께 또는 프로젝트 코드를 분석하여 작성합니다.

| 파일 | 내용 | 작성 방법 |
|------|------|-----------|
| `.guides/BUILD_GUIDE.md` | 빌드, 실행, 배포, 의존성 | 프로젝트 빌드 시스템 분석 |
| `.guides/CODE_STYLE.md` | 명명규칙, 아키텍처, 패턴 | 기존 코드 분석 + 사용자 확인 |
| `.guides/TECHNICAL_RULES.md` | 필수 규칙, 라이브러리 규칙 | 사용자 인터뷰 |
| `.guides/TEST_GUIDE.md` | 테스트 프레임워크, 패턴, 커버리지 | 테스트 코드 분석 |

**에이전트 팁**: 프로젝트의 기존 코드를 분석하여 자동으로 초안을 작성한 후, 사용자에게 검토를 요청하면 효율적입니다.

---

### Phase 5: 검증

세팅 완료 후 다음을 확인합니다:

1. **파일 존재 확인**:
   - `CLAUDE.md` - 진입점 (프로젝트 루트)
   - `AGENTS.md` - 에이전트 규칙
   - `.claude/commands/` - 14개 명령어 파일
   - `WORKFLOW_PLANNING/` - 5개 모듈
   - `.wips/` - 템플릿 + active 디렉토리
   - `.guides/` - 가이드 파일들

2. **변수 치환 확인**:
   ```
   생성된 파일에서 {{로 시작하는 미치환 변수가 없는지 확인
   ```

3. **명령어 동작 확인**:
   ```
   /project:명령어 → 전체 목록 출력되는지 확인
   /project:상태 전체 → 빈 상태 정상 출력되는지 확인
   ```

4. **빌드 확인**:
   ```
   설정된 빌드 명령어가 정상 동작하는지 확인
   ```

---

## 변수 치환 참조표

### template-config.json → .tmpl 파일 매핑

| 변수 | config 경로 | 사용되는 파일 |
|------|------------|--------------|
| `{{PROJECT_NAME}}` | project.name | CLAUDE.md, QUICK_REFERENCE.md, 명령어.md 등 |
| `{{PROJECT_DESCRIPTION}}` | project.description | CLAUDE.md |
| `{{TECH_STACK}}` | project.techStack | CLAUDE.md, AGENTS.md |
| `{{LIBRARIES}}` | project.libraries | CLAUDE.md |
| `{{BUILD_COMMAND}}` | project.buildCommand | 릴리즈.md, CLAUDE.md |
| `{{TEST_COMMAND}}` | project.testCommand | CLAUDE.md |
| `{{RUN_COMMAND}}` | project.runCommand | CLAUDE.md |
| `{{PROJECT_FILE}}` | project.projectFile | WORKFLOW_GUIDE.md |
| `{{PROJECT_STRUCTURE}}` | project.projectStructure | CLAUDE.md |
| `{{NAMING_CONVENTIONS}}` | project.namingConventions | CLAUDE.md |
| `{{FEATURE_CATEGORIES}}` | project.featureCategories | CLAUDE.md |
| `{{OUTPUT_FORMATS}}` | project.outputFormats | CLAUDE.md |
| `{{CLI_OPTIONS}}` | project.cliOptions | CLAUDE.md |
| `{{DOMAIN_RULES}}` | project.domainRules | CLAUDE.md |
| `{{TYPE_SAFETY_RULES}}` | languageRules.typeSafety | AGENTS.md |
| `{{TYPE_SAFETY_ANTIPATTERNS}}` | languageRules.antiPatterns | AGENTS.md |
| `{{ARCHITECT_LANG_RULES}}` | languageRules.architectRules | AGENTS.md |
| `{{DEVELOPER_LANG_RULES}}` | languageRules.developerRules | AGENTS.md |
| `{{VALIDATION_ITEMS}}` | languageRules.validationItems | AGENTS.md, GATES.md, WIP |
| `{{DESIGN_REVIEW_ITEMS}}` | languageRules.designReviewItems | AGENTS.md |
| `{{HARD_BLOCKS_SUMMARY}}` | (자동 생성) | CLAUDE.md |
| `{{ABSOLUTE_RULES_SUMMARY}}` | (자동 생성) | AGENTS.md |

### stages.json → META-TEMPLATE.md 매핑

| 변수 | stages.json 경로 | 설명 |
|------|-----------------|------|
| `{{STAGE}}` | (키 이름) | Plan, Design, Code 등 |
| `{{AGENT}}` | {stage}.agent | 담당 에이전트 |
| `{{CROSSCHECK_AGENT}}` | {stage}.crosscheckAgent | 크로스체크 에이전트 |
| `{{GATE}}` | {stage}.gate | Gate 이름 |
| `{{LANG_RULES}}` | {stage}.langRules | 언어별 규칙 ({{VALIDATION_ITEMS}} 참조) |
| `{{STAGE_STEP1}}` | {stage}.step1 | 1단계 작업 |
| `{{STAGE_STEP2}}` | {stage}.step2 | 2단계 작업 |
| `{{STAGE_STEP3}}` | {stage}.step3 | 3단계 작업 |
| `{{STAGE_RESULTS}}` | {stage}.results | 결과물 섹션 |

---

## 참고: ExcelBinder 실제 설정 예시

`template-config.example.json` 파일에 ExcelBinder 프로젝트의 실제 설정이 포함되어 있습니다.
새 프로젝트 설정 시 참고 자료로 활용하세요.
