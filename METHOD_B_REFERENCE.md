# 방법 B 참조 가이드: 수동 변수 치환

> init 스크립트(init.ps1/init.sh)를 사용할 수 없는 환경에서 에이전트가 직접 변수를 치환할 때 참조하는 문서입니다.

---

## 1. 개요

방법 B는 `.tmpl` 파일의 `{{변수명}}`을 에이전트가 직접 치환하는 방식입니다.
단순 치환 변수는 `template-config.json` 값을 그대로 대입하면 되지만, **동적 변수**는 프리셋과 stages.json을 조합하여 생성해야 합니다.

### 필요 입력 파일

| 파일 | 용도 |
|------|------|
| `template-config.json` | 프로젝트 설정 (사용자 입력) |
| `presets/{preset}.json` | 파이프라인 프리셋 (stages, agents) |
| `.wips/stages.json` | 스테이지 메타데이터 (summary, gateChecks 등) |

### 치환 순서 (중요)

```
1단계: 동적 변수 생성 (프리셋 + stages.json 조합)
2단계: 동적 변수를 .tmpl 파일에 삽입
3단계: 나머지 단순 치환 변수를 .tmpl 파일에 삽입
```

> **주의**: 동적 변수 내부에 `{{LANGUAGE_SPECIFIC_GATE_CHECKS}}` 등 중첩 변수가 포함될 수 있습니다.
> 동적 변수를 **먼저** 삽입해야 중첩 변수가 3단계에서 정상 해결됩니다.

---

## 2. 변수 카테고리 분류

### A. 단순 치환 변수 (~24개)

`template-config.json` 값을 그대로 대입합니다. 알고리즘 불필요.

| 변수명 | config 경로 |
|--------|------------|
| `{{PROJECT_NAME}}` | `project.name` |
| `{{PROJECT_DESCRIPTION}}` | `project.description` |
| `{{TECH_STACK}}` | `project.techStack` |
| `{{LIBRARIES}}` | `project.libraries` |
| `{{BUILD_COMMAND}}` | `project.buildCommand` |
| `{{TEST_COMMAND}}` | `project.testCommand` |
| `{{RUN_COMMAND}}` | `project.runCommand` |
| `{{PROJECT_FILE}}` | `project.projectFile` |
| `{{PROJECT_STRUCTURE}}` | `project.projectStructure` |
| `{{NAMING_CONVENTIONS}}` | `project.namingConventions` |
| `{{FEATURE_CATEGORIES}}` | `project.featureCategories` |
| `{{OUTPUT_FORMATS}}` | `project.outputFormats` |
| `{{CLI_OPTIONS}}` | `project.cliOptions` |
| `{{DOMAIN_RULES}}` | `project.domainRules` |
| `{{TYPE_SAFETY_RULES}}` | `languageRules.typeSafety` |
| `{{TYPE_SAFETY_ANTIPATTERNS}}` | `languageRules.antiPatterns` |
| `{{ARCHITECT_LANG_RULES}}` | `languageRules.architectRules` |
| `{{DEVELOPER_LANG_RULES}}` | `languageRules.developerRules` |
| `{{VALIDATION_ITEMS}}` | `languageRules.validationItems` |
| `{{DESIGN_REVIEW_ITEMS}}` | `languageRules.designReviewItems` |
| `{{BUILD_ERROR_CHECKLIST}}` | `languageRules.buildErrorChecklist` (선택) |
| `{{RUNTIME_ERROR_CHECKLIST}}` | `languageRules.runtimeErrorChecklist` (선택) |
| `{{TECHNICAL_PRINCIPLES}}` | `languageRules.technicalPrinciples` (선택) |
| `{{CODE_PATTERNS}}` | `languageRules.codePatterns` (선택) |

> 선택 필드가 config에 없으면 빈 문자열로 치환합니다.

### B. 동적 파이프라인 변수 (~14개)

프리셋 + stages.json을 조합하여 생성해야 합니다. **섹션 3에서 각각의 알고리즘을 설명합니다.**

| 변수명 | 사용처 |
|--------|--------|
| `{{PIPELINE_ARROW}}` | CLAUDE.md, PIPELINE.md 등 |
| `{{GATED_PIPELINE_ARROW}}` | CLAUDE.md, PIPELINE.md 등 |
| `{{STAGE_COUNT}}` | CLAUDE.md 등 |
| `{{PIPELINE_STAGES_LIST}}` | CLAUDE.md, PIPELINE.md 등 |
| `{{WIP_COMPLETED_STEPS}}` | WORK_IN_PROGRESS.md |
| `{{WIP_VALIDATION_GATES}}` | WORK_IN_PROGRESS.md |
| `{{GATE_OVERVIEW_TABLE}}` | GATES.md |
| `{{GATE_DETAILS}}` | GATES.md |
| `{{CROSS_STAGE_REVIEW_ROWS}}` | AGENTS.md |
| `{{WIP_FOLDER_TREE}}` | AGENTS.md |
| `{{AGENT_STAGE_TABLE}}` | AGENTS.md |
| `{{PIPELINE_WORKFLOW_AUTO}}` | PIPELINE.md |
| `{{CONVERGENCE_STAGES_TEXT}}` | CLAUDE.md, GATES.md, PIPELINE.md |
| `{{CONVERGENCE_STAGES_LIST}}` | GATES.md |

### C. 별칭 변수 (~4개)

다른 변수와 동일한 값을 사용합니다.

| 별칭 | 원본 |
|------|------|
| `{{LANG_RULES}}` | `{{VALIDATION_ITEMS}}` (= `languageRules.validationItems`) |
| `{{LANGUAGE_SPECIFIC_GATE_CHECKS}}` | `{{VALIDATION_ITEMS}}` (= `languageRules.validationItems`) |
| `{{PROJECT_FILE_STRUCTURE}}` | `{{PROJECT_STRUCTURE}}` (= `project.projectStructure`) |
| `{{PROJECT_EXAMPLES}}` | `{{PROJECT_STRUCTURE}}` (= `project.projectStructure`) |

### D. WIP 템플릿 변수 (~8개)

스테이지별 WIP 템플릿(`.wips/templates/`)에서 사용됩니다.
각 스테이지의 stages.json 데이터에서 추출합니다.

| 변수명 | stages.json 경로 | 설명 |
|--------|-----------------|------|
| `{{STAGE}}` | 스테이지 키 이름 | 예: "Plan", "Code" |
| `{{AGENT}}` | `{stage}.agent` (프리셋 우선) | 예: "analyst", "developer" |
| `{{CROSSCHECK_AGENT}}` | `{stage}.crosscheckAgent` (프리셋 우선) | 예: "architect", "tester" |
| `{{GATE}}` | `Gate-{index+1}` | 예: "Gate-1" |
| `{{STAGE_STEP1}}` | `{stage}.step1` | 1단계 체크리스트 |
| `{{STAGE_STEP2}}` | `{stage}.step2` | 2단계 체크리스트 |
| `{{STAGE_STEP3}}` | `{stage}.step3` | 3단계 체크리스트 |
| `{{STAGE_RESULTS}}` | `{stage}.results` | 결과 템플릿 |
| `{{LANG_RULES}}` | `{stage}.langRules` | 스테이지별 언어 규칙 |

### E. 기타 고정 변수

| 변수명 | 값 | 설명 |
|--------|-----|------|
| `{{COMMAND_COUNT}}` | `.claude/commands/` 내 `.md` 파일 수 | 커스텀 명령어 개수 |

---

## 3. 동적 변수 생성 알고리즘

### 사전 준비: 병합 데이터 생성

모든 동적 변수는 **mergedStages** 배열을 기반으로 생성됩니다.
먼저 이 배열을 만드세요.

**입력**: 프리셋의 `stages[]` + `agents{}`, stages.json의 메타데이터

```
mergedStages = []

FOR i = 0 TO preset.stages.length - 1:
    stageName = preset.stages[i]
    presetAgent = preset.agents[stageName]
    stageMetadata = stagesJson[stageName]

    IF stageMetadata가 없으면:
        경고 출력 후 건너뛰기

    gateName = "Gate-{i + 1}"
    rollbackTo = Resolve-RollbackTarget(stageMetadata.rollbackTo, preset.stages, i)

    mergedStages.push({
        Name: stageName,
        Index: i,
        Agent: presetAgent.agent ?? stageMetadata.agent,
        CrosscheckAgent: presetAgent.crosscheckAgent ?? stageMetadata.crosscheckAgent,
        Gate: gateName,
        Summary: stageMetadata.summary,
        KoreanName: stageMetadata.koreanName,
        GateChecks: stageMetadata.gateChecks,
        RollbackTo: rollbackTo
    })
```

**롤백 대상 해결 알고리즘** (`Resolve-RollbackTarget`):

```
FUNCTION Resolve-RollbackTarget(target, availableStages, currentIndex):
    IF target이 null이거나 빈 문자열:
        RETURN availableStages[currentIndex]   # 자기 자신으로 롤백
    IF target이 availableStages에 포함됨:
        RETURN target                           # 지정된 대상으로 롤백
    ELSE:
        RETURN availableStages[currentIndex - 1] # 이전 단계로 폴백
        (이전 단계가 없으면 availableStages[0])
```

> **주의**: `rollbackTo`에 "Design" 같은 값이 있어도 lite 프리셋(Plan,Code,Review)에는
> "Design"이 없으므로 이전 단계("Plan")로 폴백됩니다.

---

### 3-1. PIPELINE_ARROW

스테이지 이름을 `→`로 연결합니다.

```
PIPELINE_ARROW = stages.join(" → ")
```

**standard 프리셋 예시 출력:**
```
Plan → Code → Test → Docs → Review
```

---

### 3-2. GATED_PIPELINE_ARROW

스테이지와 게이트를 번갈아 배치하고, 마지막에 "완료"를 추가합니다.

```
parts = []
FOR EACH ms IN mergedStages:
    parts.push(ms.Name)
    parts.push("[" + ms.Gate + "]")
parts.push("완료")

GATED_PIPELINE_ARROW = parts.join(" → ")
```

**standard 프리셋 예시 출력:**
```
Plan → [Gate-1] → Code → [Gate-2] → Test → [Gate-3] → Docs → [Gate-4] → Review → [Gate-5] → 완료
```

---

### 3-3. STAGE_COUNT

```
STAGE_COUNT = stages.length (문자열)
```

**standard 프리셋 예시 출력:** `5`

---

### 3-4. PIPELINE_STAGES_LIST

번호가 매겨진 단계 목록입니다.

```
lines = []
FOR i = 0 TO mergedStages.length - 1:
    ms = mergedStages[i]
    lines.push("{i+1}. {ms.Name} ({ms.KoreanName}): {ms.Summary}")

PIPELINE_STAGES_LIST = lines.join("\n")
```

**standard 프리셋 예시 출력:**
```
1. Plan (계획): 기획서 분석, 유형 판단, 계획 수립
2. Code (코딩): 코드 구현, 빌드 확인
3. Test (테스트): 단위 테스트 자동 생성, 기능 테스트, 빌드 테스트
4. Docs (문서화): 각 단계별 문서 업데이트, API 문서 생성
5. Review (최종검토): 전체 결과물 종합 검토, 최종 승인
```

---

### 3-5. WIP_COMPLETED_STEPS

WORK_IN_PROGRESS.md용 체크리스트입니다.

```
lines = []
FOR i = 0 TO mergedStages.length - 1:
    ms = mergedStages[i]
    lines.push("- [ ] {i+1}. {ms.Name} ({ms.KoreanName}): {ms.Summary}")

WIP_COMPLETED_STEPS = lines.join("\n")
```

**standard 프리셋 예시 출력:**
```
- [ ] 1. Plan (계획): 기획서 분석, 유형 판단, 계획 수립
- [ ] 2. Code (코딩): 코드 구현, 빌드 확인
- [ ] 3. Test (테스트): 단위 테스트 자동 생성, 기능 테스트, 빌드 테스트
- [ ] 4. Docs (문서화): 각 단계별 문서 업데이트, API 문서 생성
- [ ] 5. Review (최종검토): 전체 결과물 종합 검토, 최종 승인
```

---

### 3-6. WIP_VALIDATION_GATES

WORK_IN_PROGRESS.md용 Gate 검증 섹션입니다.

```
lines = []
FOR i = 0 TO mergedStages.length - 1:
    ms = mergedStages[i]
    nextStage = (i < length - 1) ? mergedStages[i+1].Name : "완료"

    lines.push("- [ ] **{ms.Gate}**: {ms.Name} → {nextStage}")
    lines.push("  - [ ] 1차 자체 검증 ({ms.Agent})")
    lines.push("  - [ ] 2차 자체 검증 ({ms.Agent})")

    IF ms.CrosscheckAgent != null:
        lines.push("  - [ ] 크로스체크 ({ms.CrosscheckAgent})")
    ELSE:
        lines.push("  - [ ] 사용자 승인")

    lines.push("  - 상태: 대기 중")

    IF i < length - 1:
        lines.push("")  # 빈 줄 구분

WIP_VALIDATION_GATES = lines.join("\n")
```

**standard 프리셋 예시 출력:**
```
- [ ] **Gate-1**: Plan → Code
  - [ ] 1차 자체 검증 (analyst)
  - [ ] 2차 자체 검증 (analyst)
  - [ ] 크로스체크 (architect)
  - 상태: 대기 중

- [ ] **Gate-2**: Code → Test
  - [ ] 1차 자체 검증 (developer)
  - [ ] 2차 자체 검증 (developer)
  - [ ] 크로스체크 (tester)
  - 상태: 대기 중

- [ ] **Gate-3**: Test → Docs
  - [ ] 1차 자체 검증 (tester)
  - [ ] 2차 자체 검증 (tester)
  - [ ] 크로스체크 (developer)
  - 상태: 대기 중

- [ ] **Gate-4**: Docs → Review
  - [ ] 1차 자체 검증 (doc-manager)
  - [ ] 2차 자체 검증 (doc-manager)
  - [ ] 크로스체크 (reviewer)
  - 상태: 대기 중

- [ ] **Gate-5**: Review → 완료
  - [ ] 1차 자체 검증 (reviewer)
  - [ ] 2차 자체 검증 (reviewer)
  - [ ] 사용자 승인
  - 상태: 대기 중
```

---

### 3-7. GATE_OVERVIEW_TABLE

GATES.md용 게이트 개요 테이블 행입니다. (헤더는 .tmpl에 포함)

```
lines = []
FOR i = 0 TO mergedStages.length - 1:
    ms = mergedStages[i]
    nextStage = (i < length - 1) ? mergedStages[i+1].Name : "완료"
    selfCheck = "{ms.Agent} 2회"
    crossCheck = ms.CrosscheckAgent ? "{ms.CrosscheckAgent} 1회" : "-"

    # 롤백 대상 표시
    IF ms.Name == ms.RollbackTo:
        rollbackDisplay = "{ms.Name} 재{ms.KoreanName}"
    ELSE IF ms.CrosscheckAgent == null:
        rollbackDisplay = "적절 단계로 롤백"
    ELSE:
        rbMeta = stagesJson[ms.RollbackTo]
        IF rbMeta:
            rollbackDisplay = "{ms.RollbackTo} 재{rbMeta.koreanName}"
        ELSE:
            rollbackDisplay = "{ms.RollbackTo}로 롤백"

    lines.push("| {ms.Gate} | {ms.Name} → {nextStage} | {selfCheck} | {crossCheck} | {rollbackDisplay} |")

GATE_OVERVIEW_TABLE = lines.join("\n")
```

**standard 프리셋 예시 출력:**
```
| Gate-1 | Plan → Code | analyst 2회 | architect 1회 | Plan 재계획 |
| Gate-2 | Code → Test | developer 2회 | tester 1회 | Plan 재계획 |
| Gate-3 | Test → Docs | tester 2회 | developer 1회 | Code 재코딩 |
| Gate-4 | Docs → Review | doc-manager 2회 | reviewer 1회 | Test 재테스트 |
| Gate-5 | Review → 완료 | reviewer 2회 | - | 적절 단계로 롤백 |
```

> **참고**: stages.json에서 Code의 rollbackTo는 "Design"이지만, standard 프리셋에는
> "Design" 단계가 없으므로 `Resolve-RollbackTarget` 알고리즘이 이전 단계("Plan")로 폴백합니다.
> full 프리셋에서는 "Design 재설계"로 정상 표시됩니다.

---

### 3-8. GATE_DETAILS

GATES.md용 게이트별 상세 통과 조건입니다.

```
lines = []
FOR i = 0 TO mergedStages.length - 1:
    ms = mergedStages[i]
    nextStage = (i < length - 1) ? mergedStages[i+1].Name : "완료"

    lines.push("**{ms.Gate} ({ms.Name} → {nextStage})**")

    FOR EACH check IN ms.GateChecks:
        # 중첩 변수 해결: {{LANGUAGE_SPECIFIC_GATE_CHECKS}} → validationItems 값
        resolvedCheck = check.replace("{{LANGUAGE_SPECIFIC_GATE_CHECKS}}", config.languageRules.validationItems)
        lines.push("- ✅ {resolvedCheck}")

    lines.push("- ✅ {ms.Agent} 1차 검증")
    lines.push("- ✅ {ms.Agent} 2차 검증")

    IF ms.CrosscheckAgent != null:
        lines.push("- ✅ {ms.CrosscheckAgent} 크로스체크")
    ELSE:
        lines.push("- ✅ coordinator 최종 검증")

    IF i < length - 1:
        lines.push("")  # 빈 줄 구분

GATE_DETAILS = lines.join("\n")
```

**standard 프리셋 예시 출력** (validationItems = "- [ ] 검증 항목 1\n- [ ] 검증 항목 2"):
```
**Gate-1 (Plan → Code)**
- ✅ 계획 명확성 검증
- ✅ 영향 파일 완전성 검증
- ✅ 위험 요소 식별 완료
- ✅ 사용자 승인 완료
- ✅ analyst 1차 검증
- ✅ analyst 2차 검증
- ✅ architect 크로스체크

**Gate-2 (Code → Test)**
- ✅ 빌드 성공 (Exit Code 0)
- ✅ 컴파일 에러 0개
- ✅ 컴파일 경고 < 5개 (심각 경고 0개)
- ✅ 참조 에러 0개
- ✅ 코드 스타일 준수
- ✅ 기술 규칙 준수 - [ ] 검증 항목 1
- [ ] 검증 항목 2
- ✅ developer 1차 검증
- ✅ developer 2차 검증
- ✅ tester 크로스체크

...이하 동일 패턴 반복
```

---

### 3-9. CROSS_STAGE_REVIEW_ROWS

AGENTS.md용 크로스체크 검증 테이블 행입니다. **마지막 스테이지(Review)는 제외**합니다.

```
lines = []
FOR i = 0 TO mergedStages.length - 2:  # 마지막 제외
    ms = mergedStages[i]
    nextMs = mergedStages[i + 1]
    checker = ms.CrosscheckAgent ?? "reviewer"

    lines.push("| {ms.Name} → {nextMs.Name} | {checker} | {ms.Gate} 크로스체크 검증 |")

CROSS_STAGE_REVIEW_ROWS = lines.join("\n")
```

**standard 프리셋 예시 출력:**
```
| Plan → Code | architect | Gate-1 크로스체크 검증 |
| Code → Test | tester | Gate-2 크로스체크 검증 |
| Test → Docs | developer | Gate-3 크로스체크 검증 |
| Docs → Review | reviewer | Gate-4 크로스체크 검증 |
```

---

### 3-10. WIP_FOLDER_TREE

AGENTS.md용 WIP 폴더 구조 트리입니다. **Review(coordinator) 스테이지는 제외**합니다.

```
nonReviewStages = mergedStages.filter(ms => ms.CrosscheckAgent != null)

lines = []
lines.push(".wips/")
lines.push("├── templates/           # 템플릿 파일 (읽기 전용)")

FOR i = 0 TO nonReviewStages.length - 1:
    ts = nonReviewStages[i]
    prefix = (i < length - 1) ? "│   ├──" : "│   └──"
    lines.push("{prefix} WIP-{ts.Name}-YYYYMMDD-NNN.md")

lines.push("└── active/              # 독립 WIP 작성 폴더 (쓰기 전용)")

FOR i = 0 TO nonReviewStages.length - 1:
    ts = nonReviewStages[i]
    prefix = (i < length - 1) ? "    ├──" : "    └──"
    lines.push("{prefix} {ts.Name}/")

WIP_FOLDER_TREE = lines.join("\n")
```

**standard 프리셋 예시 출력:**
```
.wips/
├── templates/           # 템플릿 파일 (읽기 전용)
│   ├── WIP-Plan-YYYYMMDD-NNN.md
│   ├── WIP-Code-YYYYMMDD-NNN.md
│   ├── WIP-Test-YYYYMMDD-NNN.md
│   └── WIP-Docs-YYYYMMDD-NNN.md
└── active/              # 독립 WIP 작성 폴더 (쓰기 전용)
    ├── Plan/
    ├── Code/
    ├── Test/
    └── Docs/
```

---

### 3-11. AGENT_STAGE_TABLE

AGENTS.md용 에이전트-스테이지 매핑 테이블 행입니다.

```
lines = []

# Review 제외 스테이지
FOR EACH ms IN nonReviewStages:
    lines.push("| **{ms.Agent}** | {ms.Name} | `WIP-{ms.Name}-YYYYMMDD-NNN.md` | `.wips/active/{ms.Name}/` | `.wips/templates/WIP-{ms.Name}-YYYYMMDD-NNN.md` | `.wips/active/{ms.Name}/WIP-{ms.Name}-YYYYMMDD-NNN.md` |")

# 마지막 스테이지(Review/coordinator) 별도 행
lastStage = mergedStages[last]
lines.push("| **{lastStage.Agent}** | {lastStage.Name} | (전체 관리) | (해당 없음) | - | - |")

AGENT_STAGE_TABLE = lines.join("\n")
```

**standard 프리셋 예시 출력:**
```
| **analyst** | Plan | `WIP-Plan-YYYYMMDD-NNN.md` | `.wips/active/Plan/` | `.wips/templates/WIP-Plan-YYYYMMDD-NNN.md` | `.wips/active/Plan/WIP-Plan-YYYYMMDD-NNN.md` |
| **developer** | Code | `WIP-Code-YYYYMMDD-NNN.md` | `.wips/active/Code/` | `.wips/templates/WIP-Code-YYYYMMDD-NNN.md` | `.wips/active/Code/WIP-Code-YYYYMMDD-NNN.md` |
| **tester** | Test | `WIP-Test-YYYYMMDD-NNN.md` | `.wips/active/Test/` | `.wips/templates/WIP-Test-YYYYMMDD-NNN.md` | `.wips/active/Test/WIP-Test-YYYYMMDD-NNN.md` |
| **doc-manager** | Docs | `WIP-Docs-YYYYMMDD-NNN.md` | `.wips/active/Docs/` | `.wips/templates/WIP-Docs-YYYYMMDD-NNN.md` | `.wips/active/Docs/WIP-Docs-YYYYMMDD-NNN.md` |
| **reviewer** | Review | (전체 관리) | (해당 없음) | - | - |
```

---

### 3-12. PIPELINE_WORKFLOW_AUTO

PIPELINE.md용 자동화 모드 워크플로우입니다.

```
lines = []
lines.push('사용자: "coordinator [기능명] 기능 추가"')
lines.push("  ↓")
lines.push("coordinator: 작업 시작 → WorkID 생성")

FOR i = 0 TO mergedStages.length - 1:
    ms = mergedStages[i]
    lines.push("  ↓")
    lines.push("{i+1}. {ms.Name}: {ms.Agent} ({ms.Summary})")

PIPELINE_WORKFLOW_AUTO = lines.join("\n")
```

**standard 프리셋 예시 출력:**
```
사용자: "coordinator [기능명] 기능 추가"
  ↓
coordinator: 작업 시작 → WorkID 생성
  ↓
1. Plan: analyst (기획서 분석, 유형 판단, 계획 수립)
  ↓
2. Code: developer (코드 구현, 빌드 확인)
  ↓
3. Test: tester (단위 테스트 자동 생성, 기능 테스트, 빌드 테스트)
  ↓
4. Docs: doc-manager (각 단계별 문서 업데이트, API 문서 생성)
  ↓
5. Review: reviewer (전체 결과물 종합 검토, 최종 승인)
```

---

### 3-13. COMMAND_COUNT

`.claude/commands/` 디렉토리의 `.md` 파일 수를 셉니다.

```
COMMAND_COUNT = count(.claude/commands/*.md)
```

현재 기본 값: **14**

### 3-14. CONVERGENCE_STAGES_TEXT

stages.json에서 `"convergence": true`인 스테이지를 현재 프리셋 기준으로 필터링하여 한글명을 연결합니다.

```
convergenceStages = mergedStages에서 stagesConfig[name].convergence == true인 것만 필터

IF convergenceStages가 비어있지 않으면:
    koreanNames = convergenceStages의 각 koreanName
    CONVERGENCE_STAGES_TEXT = koreanNames를 "/"로 연결 + " 단계"
    예: full → "계획/설계 단계", lite/standard → "계획 단계"
ELSE:
    CONVERGENCE_STAGES_TEXT = ""
```

### 3-15. CONVERGENCE_STAGES_LIST

수렴 검증 적용 단계의 상세 목록을 생성합니다.

```
IF convergenceStages가 비어있지 않으면:
    lines = []
    lines += '수렴 검증은 다음 단계에 적용됩니다 (stages.json의 `"convergence": true`):'
    FOR EACH cs IN convergenceStages:
        lines += "- **{cs.Name} ({cs.KoreanName})**: {cs.convergenceDescription}"
    lines += ""
    lines += "> 수렴 검증이 적용되지 않는 단계는 Gate 검증과 크로스체크로 품질을 보장합니다."
    CONVERGENCE_STAGES_LIST = lines를 줄바꿈으로 연결
ELSE:
    CONVERGENCE_STAGES_LIST = ""
```

> `convergenceDescription`은 stages.json에 정의된 필드입니다. 현재값:
> - Plan: "분석 결과와 작업 계획의 완전성·견고성 수렴"
> - Design: "아키텍처 설계의 기술적 완전성·견고성 수렴"

---

## 4. 검증 체크리스트

변수 치환 완료 후 다음을 확인하세요:

- [ ] 모든 `.tmpl` 파일에서 `.md`로 변환 완료
- [ ] 생성된 `.md` 파일에 `{{` 패턴이 남아있지 않음 (grep 검증)
- [ ] `PIPELINE_ARROW`의 스테이지 수가 프리셋과 일치
- [ ] `GATE_DETAILS`의 Gate 번호가 연속적 (Gate-1, Gate-2, ...)
- [ ] `WIP_FOLDER_TREE`에 Review 스테이지가 포함되지 않음
- [ ] `AGENT_STAGE_TABLE`의 에이전트명이 프리셋의 agents와 일치
- [ ] 별칭 변수(C 카테고리)가 원본과 동일한 값으로 치환됨
- [ ] 선택 필드(buildErrorChecklist 등)가 없으면 빈 문자열로 치환됨
- [ ] `reports/` 디렉토리와 `.gitkeep` 파일 생성됨
- [ ] `WORK_HISTORY.json` 초기 파일(`{"completed_works":[],"cancelled_works":[]}`) 생성됨
- [ ] `.wips/templates/` 하위 WIP 템플릿 파일들 생성됨
- [ ] `.wips/active/{Stage}/` 디렉토리 구조 생성됨

---

## 5. 프리셋별 차이 요약

| 항목 | lite | standard | full |
|------|------|----------|------|
| 단계 수 | 3 | 5 | 7 |
| 단계 목록 | Plan, Code, Review | Plan, Code, Test, Docs, Review | Plan, Design, Code, Test, Docs, QA, Review |
| WIP 템플릿 수 | 2 | 4 | 6 |
| Gate 수 | 3 | 5 | 7 |
| 크로스체크 행 수 | 2 | 4 | 6 |

> WIP 템플릿 수와 크로스체크 행 수 = 전체 단계 수 - 1 (Review 제외)
