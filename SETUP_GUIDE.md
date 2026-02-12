# 프로젝트 세팅 가이드 (에이전트용)

> 이 문서는 Claude Code 에이전트가 읽고, 사용자와 대화하며 프로젝트에 개발 자동화 시스템을 세팅하기 위한 가이드입니다.
>
> **에이전트 진행 순서**: 이 가이드를 읽기 (URL) → Phase 1~2 진행 → 저장소 클론 → Phase 3~5 진행 → 임시 디렉토리 삭제
>
> **템플릿 저장소**: https://github.com/weperld/claude-dev-template

---

## 개요

이 템플릿은 다음을 제공합니다:
- **개발 파이프라인**: 프리셋별 3~7단계 (lite/standard/full)
- **Gate 검증 시스템**: 각 단계 통과 조건 + 크로스체크
- **WIP 추적**: WorkID 기반 작업 관리 (WIP-YYYYMMDD-NNN)
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

#### 프리셋 비교표

| 프리셋 | 단계 수 | 포함 단계 | 권장 대상 |
|--------|---------|----------|-----------|
| lite | 3단계 | Plan → Code → Review | 소규모/빠른 작업, 프로토타이핑 |
| standard | 5단계 | Plan → Code → Test → Docs → Review | 일반 프로젝트, 중규모 개발 |
| full | 7단계 | Plan → Design → Code → Test → Docs → QA → Review | 대규모/엄격한 프로젝트, 팀 개발 |

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

#### 방법 A-1: init.ps1 사용 (Windows PowerShell)

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
#   - reports/ (디렉토리)
#   - WORK_HISTORY.json

# 4. 임시 디렉토리 정리
Set-Location ..
Remove-Item "_template_temp" -Recurse -Force
```

#### 방법 A-2: init.sh 사용 (Linux/macOS Bash)

```bash
# 의존성: jq (brew install jq / apt-get install jq)

# 1. 생성한 template-config.json을 임시 디렉토리에 배치
cp "[생성한 config 경로]" "_template_temp/template-config.json"

# 2. init.sh 실행
cd "_template_temp"
chmod +x init.sh
./init.sh

# 3. 생성된 파일들을 프로젝트 루트로 이동 (방법 A-1과 동일한 파일 목록)

# 4. 임시 디렉토리 정리
cd ..
rm -rf "_template_temp"
```

#### 방법 B: 에이전트가 직접 수행 (init 스크립트 사용 불가 시)

> **참고**: 방법 B는 50개 이상의 변수 치환과 동적 컨텐츠 생성이 필요합니다.
> 가능하면 **방법 A-1 또는 A-2 사용을 권장**합니다.
> 방법 B를 사용해야 하는 경우, [METHOD_B_REFERENCE.md](METHOD_B_REFERENCE.md)에서 상세 알고리즘과 예시를 참고하세요.

에이전트가 다음 순서로 직접 파일을 생성/복사합니다:

1. **범용 파일 복사** (변수 치환 없이 그대로):
   - `AGENT_ROLES.md` → 프로젝트 루트
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
   - `WORK_IN_PROGRESS.md.tmpl` → `WORK_IN_PROGRESS.md`
   - `WORKFLOW_PLANNING/PIPELINE.md.tmpl` → `WORKFLOW_PLANNING/PIPELINE.md`

3. **WIP 템플릿 생성** (`META-TEMPLATE.md` + `stages.json` 조합):
   - 프리셋에 포함된 각 스테이지별로 WIP 템플릿 생성
   - `.wips/templates/WIP-{Stage}-YYYYMMDD-NNN.md`

4. **디렉토리 구조 및 초기 파일 생성**:
   - `.wips/active/{Stage}/` (각 스테이지별, .gitkeep 포함)
   - `.wips/archive/`
   - `reports/` (.gitkeep 포함)
   - `WORK_HISTORY.json` (초기값: `{"completed_works":[],"cancelled_works":[]}`)

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
   - `WORKFLOW_PLANNING/` - 6개 모듈
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

## 커스텀 프리셋 가이드

기본 프리셋(lite/standard/full) 외에 프로젝트에 맞는 커스텀 프리셋을 만들 수 있습니다.

### 프리셋 파일 구조

`presets/` 디렉토리에 JSON 파일을 생성합니다:

```json
{
  "name": "프리셋 표시명",
  "description": "프리셋 설명",
  "stages": ["Stage1", "Stage2", ..., "Review"],
  "agents": {
    "Stage1": { "agent": "에이전트명", "crosscheckAgent": "크로스체크 에이전트명", "gate": "Gate-1" },
    "Stage2": { "agent": "에이전트명", "crosscheckAgent": "크로스체크 에이전트명", "gate": "Gate-2" },
    "Review": { "agent": "coordinator명", "crosscheckAgent": null, "gate": "Gate-N" }
  }
}
```

### 필수 규칙

1. **stages 배열**: 마지막 단계는 반드시 `crosscheckAgent: null`인 최종 검토 단계여야 합니다.
2. **stages.json 참조**: `stages` 배열의 모든 단계명은 `.wips/stages.json`에 정의되어 있어야 합니다.
3. **gate 번호**: Gate-1부터 순서대로 부여합니다 (실제 치환 시 자동 계산되므로 참고용).
4. **agents 키**: stages 배열의 각 단계와 1:1 매핑되어야 합니다.

### 새 스테이지 추가 방법

기존 stages.json에 없는 단계를 사용하려면:

1. `.wips/stages.json`에 새 스테이지 메타데이터를 추가합니다:
   ```json
   "NewStage": {
     "agent": "기본 에이전트명",
     "crosscheckAgent": "기본 크로스체크 에이전트명",
     "summary": "단계 요약 설명",
     "koreanName": "한국어명",
     "rollbackTo": "롤백 대상 단계명 또는 null",
     "gateChecks": ["검증 항목 1", "검증 항목 2"],
     "langRules": "",
     "step1": "- [ ] 체크리스트 항목",
     "step2": "- [ ] 체크리스트 항목",
     "step3": "- [ ] 체크리스트 항목",
     "results": "## 결과 템플릿"
   }
   ```
2. 프리셋 JSON의 `stages` 배열과 `agents` 객체에 해당 단계를 추가합니다.
3. init 스크립트를 실행하면 자동으로 WIP 템플릿과 동적 변수가 생성됩니다.

### 사용 방법

`template-config.json`에서 프리셋명을 지정합니다:
```json
{
  "pipeline": {
    "preset": "커스텀프리셋파일명"
  }
}
```

> **주의**: `stages.json`에 정의되지 않은 스테이지를 프리셋에 포함하면 경고와 함께 해당 단계가 건너뛰어집니다.

---

## 변수 치환 참조표

### A. 사용자 설정 변수 (template-config.json → .tmpl)

config에서 직접 대입되는 변수입니다. 필수(R) / 선택(O) 구분에 유의하세요.

| 변수 | config 경로 | 필수 | 사용되는 파일 |
|------|------------|:----:|--------------|
| `{{PROJECT_NAME}}` | project.name | R | CLAUDE.md, PROJECT_SUMMARY.md, AGENTS.md, 명령어.md 등 |
| `{{PROJECT_DESCRIPTION}}` | project.description | R | CLAUDE.md |
| `{{TECH_STACK}}` | project.techStack | R | CLAUDE.md, AGENTS.md |
| `{{LIBRARIES}}` | project.libraries | R | CLAUDE.md |
| `{{BUILD_COMMAND}}` | project.buildCommand | R | CLAUDE.md, QUICK_REFERENCE.md, 릴리즈.md |
| `{{TEST_COMMAND}}` | project.testCommand | R | CLAUDE.md |
| `{{RUN_COMMAND}}` | project.runCommand | R | CLAUDE.md, QUICK_REFERENCE.md |
| `{{PROJECT_FILE}}` | project.projectFile | R | WORKFLOW_GUIDE.md |
| `{{PROJECT_STRUCTURE}}` | project.projectStructure | R | CLAUDE.md, QUICK_REFERENCE.md |
| `{{NAMING_CONVENTIONS}}` | project.namingConventions | R | CLAUDE.md, QUICK_REFERENCE.md |
| `{{FEATURE_CATEGORIES}}` | project.featureCategories | R | CLAUDE.md, GATES.md |
| `{{OUTPUT_FORMATS}}` | project.outputFormats | R | CLAUDE.md |
| `{{CLI_OPTIONS}}` | project.cliOptions | R | CLAUDE.md, QUICK_REFERENCE.md |
| `{{DOMAIN_RULES}}` | project.domainRules | R | CLAUDE.md |
| `{{TYPE_SAFETY_RULES}}` | languageRules.typeSafety | R | AGENTS.md |
| `{{TYPE_SAFETY_ANTIPATTERNS}}` | languageRules.antiPatterns | R | AGENTS.md |
| `{{ARCHITECT_LANG_RULES}}` | languageRules.architectRules | R | AGENTS.md |
| `{{DEVELOPER_LANG_RULES}}` | languageRules.developerRules | R | AGENTS.md |
| `{{VALIDATION_ITEMS}}` | languageRules.validationItems | R | AGENTS.md, GATES.md, WIP |
| `{{DESIGN_REVIEW_ITEMS}}` | languageRules.designReviewItems | R | (Reserve: 치환 등록됨, 현재 .tmpl 미사용) |
| `{{BUILD_ERROR_CHECKLIST}}` | languageRules.buildErrorChecklist | O | QUICK_REFERENCE.md |
| `{{RUNTIME_ERROR_CHECKLIST}}` | languageRules.runtimeErrorChecklist | O | QUICK_REFERENCE.md |
| `{{TECHNICAL_PRINCIPLES}}` | languageRules.technicalPrinciples | O | QUICK_REFERENCE.md |
| `{{CODE_PATTERNS}}` | languageRules.codePatterns | O | QUICK_REFERENCE.md |

### B. 자동 생성 변수 (init 스크립트가 동적으로 생성)

preset + stages.json 조합으로 init 스크립트가 자동 생성하는 변수입니다.
방법 B 사용 시 에이전트가 직접 생성해야 합니다 ([METHOD_B_REFERENCE.md](METHOD_B_REFERENCE.md) 참고).

| 변수 | 생성 로직 | 사용되는 파일 |
|------|----------|--------------|
| `{{COMMAND_COUNT}}` | 고정값 "14" | CLAUDE.md |
| `{{HARD_BLOCKS_SUMMARY}}` | typeSafety + 고정 규칙 조합 | (Reserve: ABSOLUTE_RULES_SUMMARY와 동일 값, 현재 .tmpl 미사용) |
| `{{ABSOLUTE_RULES_SUMMARY}}` | HARD_BLOCKS_SUMMARY와 동일 | CLAUDE.md |
| `{{PIPELINE_ARROW}}` | 스테이지명을 " → "로 연결 | CLAUDE.md, AGENTS.md |
| `{{GATED_PIPELINE_ARROW}}` | 스테이지명과 Gate를 교차 배치 | GATES.md |
| `{{STAGE_COUNT}}` | 프리셋 스테이지 수 | PIPELINE.md |
| `{{PIPELINE_STAGES_LIST}}` | 번호+한글명+요약 목록 | PIPELINE.md |
| `{{PIPELINE_WORKFLOW_AUTO}}` | 자동화 모드 워크플로우 | PIPELINE.md |
| `{{WIP_COMPLETED_STEPS}}` | 체크박스 형태 완료 단계 목록 | WORK_IN_PROGRESS.md |
| `{{WIP_VALIDATION_GATES}}` | Gate별 검증 섹션 | WORK_IN_PROGRESS.md |
| `{{GATE_OVERVIEW_TABLE}}` | Gate 요약 테이블 (롤백 포함) | GATES.md |
| `{{GATE_DETAILS}}` | Gate별 상세 체크리스트 | GATES.md |
| `{{CROSS_STAGE_REVIEW_ROWS}}` | 에이전트 크로스체크 테이블 행 | AGENTS.md |
| `{{WIP_FOLDER_TREE}}` | .wips/ 디렉토리 트리 | AGENTS.md |
| `{{AGENT_STAGE_TABLE}}` | 에이전트-스테이지 매핑 테이블 | AGENTS.md |
| `{{CONVERGENCE_STAGES_TEXT}}` | convergence=true 스테이지의 한글명을 "/"로 연결 + " 단계" | CLAUDE.md, GATES.md, PIPELINE.md |
| `{{CONVERGENCE_STAGES_LIST}}` | convergence=true 스테이지 목록 + 설명 (마크다운 리스트) | GATES.md |

### C. 별칭 변수 (다른 변수와 동일한 값)

| 변수 | 원본 | 설명 |
|------|------|------|
| `{{LANG_RULES}}` | = `{{VALIDATION_ITEMS}}` | WIP 템플릿 내 언어별 규칙 |
| `{{LANGUAGE_SPECIFIC_GATE_CHECKS}}` | = `{{VALIDATION_ITEMS}}` | GATES.md 내 Gate 체크 항목 |
| `{{PROJECT_FILE_STRUCTURE}}` | = `{{PROJECT_STRUCTURE}}` | GATES.md 내 프로젝트 구조 |
| `{{PROJECT_EXAMPLES}}` | = `{{PROJECT_STRUCTURE}}` | PLANNING_TEMPLATE.md 내 프로젝트 예시 |

### D. WIP 템플릿 변수 (stages.json → META-TEMPLATE.md)

스테이지별로 반복 생성되는 WIP 템플릿 내부 변수입니다.

| 변수 | stages.json 경로 | 설명 |
|------|-----------------|------|
| `{{STAGE}}` | (키 이름) | Plan, Design, Code 등 |
| `{{AGENT}}` | {stage}.agent | 담당 에이전트 |
| `{{CROSSCHECK_AGENT}}` | {stage}.crosscheckAgent | 크로스체크 에이전트 |
| `{{GATE}}` | (프리셋 기반 위치 번호) | Gate-1, Gate-2 등 |
| `{{STAGE_STEP1}}` | {stage}.step1 | 1단계 작업 |
| `{{STAGE_STEP2}}` | {stage}.step2 | 2단계 작업 |
| `{{STAGE_STEP3}}` | {stage}.step3 | 3단계 작업 |
| `{{STAGE_RESULTS}}` | {stage}.results | 결과물 섹션 |

---

## 참고: ExcelBinder 실제 설정 예시

`template-config.example.json` 파일에 ExcelBinder 프로젝트의 실제 설정이 포함되어 있습니다.
새 프로젝트 설정 시 참고 자료로 활용하세요.
