# project-template 초기화 스크립트
# 사용법: .\init.ps1 [-ConfigPath "template-config.json"]

param(
    [string]$ConfigPath = "template-config.json"
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# ─────────────────────────────────────────────
# 1. 설정 파일 읽기
# ─────────────────────────────────────────────
Write-Host "`n[1/8] 설정 파일 읽기..." -ForegroundColor Cyan

$configFile = Join-Path $ScriptDir $ConfigPath
if (-not (Test-Path $configFile)) {
    Write-Host "  ERROR: $configFile 파일을 찾을 수 없습니다." -ForegroundColor Red
    exit 1
}

$config = Get-Content $configFile -Raw -Encoding UTF8 | ConvertFrom-Json

# 필수 필드 검증
$requiredFields = @(
    @("project.name", "프로젝트 이름"),
    @("project.description", "프로젝트 설명"),
    @("project.techStack", "기술 스택"),
    @("project.libraries", "라이브러리 목록"),
    @("project.buildCommand", "빌드 명령어"),
    @("project.testCommand", "테스트 명령어"),
    @("project.runCommand", "실행 명령어"),
    @("project.projectFile", "프로젝트 파일명"),
    @("project.projectStructure", "프로젝트 구조"),
    @("project.namingConventions", "명명 규칙"),
    @("project.featureCategories", "기능 카테고리"),
    @("project.outputFormats", "출력 포맷"),
    @("project.cliOptions", "CLI 옵션"),
    @("project.domainRules", "도메인 규칙"),
    @("pipeline.preset", "파이프라인 프리셋 (lite/standard/full)"),
    @("languageRules.typeSafety", "타입 안전성 규칙"),
    @("languageRules.antiPatterns", "안티패턴"),
    @("languageRules.architectRules", "아키텍트 언어 규칙"),
    @("languageRules.developerRules", "개발자 언어 규칙"),
    @("languageRules.validationItems", "검증 체크리스트"),
    @("languageRules.designReviewItems", "설계 리뷰 항목")
)

$missingFields = @()
foreach ($field in $requiredFields) {
    $path = $field[0]
    $parts = $path -split '\.'
    $value = $config
    foreach ($part in $parts) {
        $value = $value.$part
    }
    if ([string]::IsNullOrWhiteSpace($value)) {
        $missingFields += "  - $path ($($field[1]))"
    }
}

if ($missingFields.Count -gt 0) {
    Write-Host "  ERROR: 다음 필수 필드가 비어있거나 누락되었습니다:" -ForegroundColor Red
    foreach ($msg in $missingFields) {
        Write-Host $msg -ForegroundColor Red
    }
    Write-Host "`n  template-config.example.json을 참고하여 필드를 채워주세요." -ForegroundColor Yellow
    exit 1
}

Write-Host "  프로젝트: $($config.project.name)" -ForegroundColor Green
Write-Host "  기술 스택: $($config.project.techStack)" -ForegroundColor Green

# 커스텀 명령어 수 동적 계산
$commandFiles = Get-ChildItem -Path (Join-Path $ScriptDir ".claude\commands") -Filter "*.md" -File
$tmplCommandFiles = Get-ChildItem -Path (Join-Path $ScriptDir ".claude\commands") -Filter "*.md.tmpl" -File
$commandCount = $commandFiles.Count + $tmplCommandFiles.Count
Write-Host "  커스텀 명령어: ${commandCount}개" -ForegroundColor Green

# ─────────────────────────────────────────────
# 2. 프리셋 및 스테이지 설정 로드
# ─────────────────────────────────────────────
Write-Host "`n[2/8] 파이프라인 프리셋 로드..." -ForegroundColor Cyan

$presetName = $config.pipeline.preset
$presetFile = Join-Path $ScriptDir "presets\$presetName.json"
if (-not (Test-Path $presetFile)) {
    Write-Host "  ERROR: 프리셋 '$presetName' 을 찾을 수 없습니다. (lite/standard/full)" -ForegroundColor Red
    exit 1
}

$preset = Get-Content $presetFile -Raw -Encoding UTF8 | ConvertFrom-Json
$stages = $preset.stages
Write-Host "  프리셋: $($preset.name) ($($stages.Count)단계)" -ForegroundColor Green
Write-Host "  단계: $($stages -join ' -> ')" -ForegroundColor Green

# 스테이지 메타데이터 로드 (stages.json - 단계별 상세 설정의 단일 소스)
$stagesConfig = Get-Content (Join-Path $ScriptDir ".wips\stages.json") -Raw -Encoding UTF8 | ConvertFrom-Json
Write-Host "  스테이지 메타데이터 로드 완료" -ForegroundColor Green

# ─────────────────────────────────────────────
# 헬퍼: 롤백 대상 해결 함수
# ─────────────────────────────────────────────
# stages.json의 rollbackTo가 현재 프리셋에 없는 스테이지를 가리킬 경우
# 가장 가까운 이전 스테이지로 대체합니다.
function Resolve-RollbackTarget {
    param(
        [AllowNull()][string]$Target,
        [string[]]$AvailableStages,
        [int]$CurrentIndex
    )

    if ([string]::IsNullOrEmpty($Target)) {
        return $AvailableStages[$CurrentIndex]
    }

    if ($AvailableStages -contains $Target) {
        return $Target
    }

    for ($i = $CurrentIndex - 1; $i -ge 0; $i--) {
        return $AvailableStages[$i]
    }
    return $AvailableStages[0]
}

# ─────────────────────────────────────────────
# 헬퍼: 변수 치환 함수
# ─────────────────────────────────────────────
function Replace-TemplateVars {
    param([string]$Content)

    # ── 동적 파이프라인 변수 (프리셋 기반, 먼저 치환) ──
    # 동적 변수 내부에 {{LANGUAGE_SPECIFIC_GATE_CHECKS}} 등이 포함될 수 있으므로
    # 동적 변수를 먼저 삽입한 후, 아래의 언어별 규칙 치환에서 나머지를 처리합니다.
    $Content = $Content.Replace('{{PIPELINE_ARROW}}', $dynamicVars.PipelineArrow)
    $Content = $Content.Replace('{{GATED_PIPELINE_ARROW}}', $dynamicVars.GatedPipelineArrow)
    $Content = $Content.Replace('{{STAGE_COUNT}}', $dynamicVars.StageCount)
    $Content = $Content.Replace('{{PIPELINE_STAGES_LIST}}', $dynamicVars.PipelineStagesList)
    $Content = $Content.Replace('{{WIP_COMPLETED_STEPS}}', $dynamicVars.WipCompletedSteps)
    $Content = $Content.Replace('{{WIP_VALIDATION_GATES}}', $dynamicVars.WipValidationGates)
    $Content = $Content.Replace('{{GATE_OVERVIEW_TABLE}}', $dynamicVars.GateOverviewTable)
    $Content = $Content.Replace('{{GATE_DETAILS}}', $dynamicVars.GateDetails)
    $Content = $Content.Replace('{{CROSS_STAGE_REVIEW_ROWS}}', $dynamicVars.CrossStageReviewRows)
    $Content = $Content.Replace('{{WIP_FOLDER_TREE}}', $dynamicVars.WipFolderTree)
    $Content = $Content.Replace('{{AGENT_STAGE_TABLE}}', $dynamicVars.AgentStageTable)
    $Content = $Content.Replace('{{PIPELINE_WORKFLOW_AUTO}}', $dynamicVars.PipelineWorkflowAuto)
    $Content = $Content.Replace('{{CONVERGENCE_STAGES_TEXT}}', $dynamicVars.ConvergenceStagesText)
    $Content = $Content.Replace('{{CONVERGENCE_STAGES_LIST}}', $dynamicVars.ConvergenceStagesList)

    # 프로젝트 정보 (.Replace() 사용: config 값의 $ 문자가 정규식 역참조로 해석되는 것을 방지)
    $Content = $Content.Replace('{{PROJECT_NAME}}', $config.project.name)
    $Content = $Content.Replace('{{PROJECT_DESCRIPTION}}', $config.project.description)
    $Content = $Content.Replace('{{TECH_STACK}}', $config.project.techStack)
    $Content = $Content.Replace('{{LIBRARIES}}', $config.project.libraries)
    $Content = $Content.Replace('{{BUILD_COMMAND}}', $config.project.buildCommand)
    $Content = $Content.Replace('{{TEST_COMMAND}}', $config.project.testCommand)
    $Content = $Content.Replace('{{RUN_COMMAND}}', $config.project.runCommand)
    $Content = $Content.Replace('{{PROJECT_FILE}}', $config.project.projectFile)
    $Content = $Content.Replace('{{PROJECT_STRUCTURE}}', $config.project.projectStructure)
    $Content = $Content.Replace('{{NAMING_CONVENTIONS}}', $config.project.namingConventions)
    $Content = $Content.Replace('{{FEATURE_CATEGORIES}}', $config.project.featureCategories)
    $Content = $Content.Replace('{{OUTPUT_FORMATS}}', $config.project.outputFormats)
    $Content = $Content.Replace('{{CLI_OPTIONS}}', $config.project.cliOptions)
    $Content = $Content.Replace('{{DOMAIN_RULES}}', $config.project.domainRules)
    $Content = $Content.Replace('{{COMMAND_COUNT}}', "$commandCount")

    # 언어별 규칙
    $Content = $Content.Replace('{{TYPE_SAFETY_RULES}}', $config.languageRules.typeSafety)
    $Content = $Content.Replace('{{TYPE_SAFETY_ANTIPATTERNS}}', $config.languageRules.antiPatterns)
    $Content = $Content.Replace('{{ARCHITECT_LANG_RULES}}', $config.languageRules.architectRules)
    $Content = $Content.Replace('{{DEVELOPER_LANG_RULES}}', $config.languageRules.developerRules)
    $Content = $Content.Replace('{{DESIGN_REVIEW_ITEMS}}', $config.languageRules.designReviewItems)

    # 아래 3개 변수는 모두 동일한 값(languageRules.validationItems)을 참조하는 별칭입니다:
    #   - VALIDATION_ITEMS: AGENTS.md.tmpl에서 Self-Validation Checklist 용도
    #   - LANG_RULES: META-TEMPLATE.md에서 WIP 절대 규칙 체크 용도 (stages.json 경유)
    #   - LANGUAGE_SPECIFIC_GATE_CHECKS: GATES.md.tmpl에서 Gate 통과 조건 용도
    $Content = $Content.Replace('{{VALIDATION_ITEMS}}', $config.languageRules.validationItems)
    $Content = $Content.Replace('{{LANG_RULES}}', $config.languageRules.validationItems)
    $Content = $Content.Replace('{{LANGUAGE_SPECIFIC_GATE_CHECKS}}', $config.languageRules.validationItems)
    $Content = $Content.Replace('{{PROJECT_FILE_STRUCTURE}}', $config.project.projectStructure)
    $Content = $Content.Replace('{{PROJECT_EXAMPLES}}', $config.project.projectStructure)

    # 절대 규칙 요약
    $hardBlocksSummary = "- **타입 안전성**: $($config.languageRules.typeSafety)`n- **빈 catch 블록 금지**: catch(e) {} 사용 금지`n- **추측 금지**: 모호한 요청은 반드시 사용자에게 확인"
    $Content = $Content.Replace('{{ABSOLUTE_RULES_SUMMARY}}', $hardBlocksSummary)
    $Content = $Content.Replace('{{HARD_BLOCKS_SUMMARY}}', $hardBlocksSummary)

    # 에러 체크리스트 및 기술 원칙 (빈 값이면 기본값)
    if ($config.languageRules.PSObject.Properties['buildErrorChecklist']) {
        $Content = $Content.Replace('{{BUILD_ERROR_CHECKLIST}}', $config.languageRules.buildErrorChecklist)
    } else {
        $Content = $Content.Replace('{{BUILD_ERROR_CHECKLIST}}', "")
    }
    if ($config.languageRules.PSObject.Properties['runtimeErrorChecklist']) {
        $Content = $Content.Replace('{{RUNTIME_ERROR_CHECKLIST}}', $config.languageRules.runtimeErrorChecklist)
    } else {
        $Content = $Content.Replace('{{RUNTIME_ERROR_CHECKLIST}}', "")
    }
    if ($config.languageRules.PSObject.Properties['technicalPrinciples']) {
        $Content = $Content.Replace('{{TECHNICAL_PRINCIPLES}}', $config.languageRules.technicalPrinciples)
    } else {
        $Content = $Content.Replace('{{TECHNICAL_PRINCIPLES}}', "")
    }

    # 코드 패턴 (빈 값이면 기본값)
    if ($config.languageRules.PSObject.Properties['codePatterns']) {
        $Content = $Content.Replace('{{CODE_PATTERNS}}', $config.languageRules.codePatterns)
    } else {
        $Content = $Content.Replace('{{CODE_PATTERNS}}', "")
    }

    return $Content
}

# ─────────────────────────────────────────────
# 3. 동적 파이프라인 컨텐츠 생성
# ─────────────────────────────────────────────
Write-Host "`n[3/8] 동적 파이프라인 컨텐츠 생성..." -ForegroundColor Cyan

$dynamicVars = @{}

# ── 프리셋 + stages.json 병합 데이터 생성 ──
# 프리셋의 agents 데이터(agent, crosscheckAgent, gate 번호)가 우선이며,
# stages.json의 메타데이터(summary, koreanName, gateChecks, rollbackTo, steps, results)를 보완합니다.
$mergedStages = @()
for ($i = 0; $i -lt $stages.Count; $i++) {
    $stageName = $stages[$i]
    $presetAgent = $preset.agents.$stageName
    $stageMetadata = $stagesConfig.$stageName

    if ($null -eq $stageMetadata) {
        Write-Host "  WARN: stages.json에 '$stageName' 설정이 없습니다. 건너뜁니다." -ForegroundColor Yellow
        continue
    }

    $gateName = "Gate-$($i + 1)"
    $resolvedRollback = Resolve-RollbackTarget `
        -Target $stageMetadata.rollbackTo `
        -AvailableStages $stages `
        -CurrentIndex $i

    $mergedStages += @{
        Name           = $stageName
        Index          = $i
        Agent          = if ($presetAgent) { $presetAgent.agent } else { $stageMetadata.agent }
        CrosscheckAgent = if ($presetAgent) { $presetAgent.crosscheckAgent } else { $stageMetadata.crosscheckAgent }
        Gate           = $gateName
        Summary        = $stageMetadata.summary
        KoreanName     = $stageMetadata.koreanName
        GateChecks     = $stageMetadata.gateChecks
        RollbackTo     = $resolvedRollback
    }
}

# ── PIPELINE_ARROW: "Plan → Design → Code" ──
$dynamicVars.PipelineArrow = $stages -join " → "

# ── GATED_PIPELINE_ARROW: "Plan → [Gate-1] → Design → [Gate-2] → ... → 완료" ──
$gatedParts = @()
for ($i = 0; $i -lt $mergedStages.Count; $i++) {
    $ms = $mergedStages[$i]
    $gatedParts += $ms.Name
    $gatedParts += "[$($ms.Gate)]"
}
$gatedParts += "완료"
$dynamicVars.GatedPipelineArrow = $gatedParts -join " → "

# ── STAGE_COUNT ──
$dynamicVars.StageCount = "$($stages.Count)"

# ── PIPELINE_STAGES_LIST: 번호가 매겨진 단계 목록 ──
$stageListLines = @()
for ($i = 0; $i -lt $mergedStages.Count; $i++) {
    $ms = $mergedStages[$i]
    $stageListLines += "$($i + 1). $($ms.Name) ($($ms.KoreanName)): $($ms.Summary)"
}
$dynamicVars.PipelineStagesList = $stageListLines -join "`n"

# ── WIP_COMPLETED_STEPS: WORK_IN_PROGRESS.md용 체크리스트 ──
$wipStepLines = @()
for ($i = 0; $i -lt $mergedStages.Count; $i++) {
    $ms = $mergedStages[$i]
    $wipStepLines += "- [ ] $($i + 1). $($ms.Name) ($($ms.KoreanName)): $($ms.Summary)"
}
$dynamicVars.WipCompletedSteps = $wipStepLines -join "`n"

# ── WIP_VALIDATION_GATES: WORK_IN_PROGRESS.md용 Gate 검증 섹션 ──
$wipGateLines = @()
for ($i = 0; $i -lt $mergedStages.Count; $i++) {
    $ms = $mergedStages[$i]
    $nextStage = if ($i -lt $mergedStages.Count - 1) { $mergedStages[$i + 1].Name } else { "완료" }

    $wipGateLines += "- [ ] **$($ms.Gate)**: $($ms.Name) → $nextStage"
    $wipGateLines += "  - [ ] 1차 자체 검증 ($($ms.Agent))"
    $wipGateLines += "  - [ ] 2차 자체 검증 ($($ms.Agent))"
    if ($ms.CrosscheckAgent) {
        $wipGateLines += "  - [ ] 크로스체크 ($($ms.CrosscheckAgent))"
    } else {
        $wipGateLines += "  - [ ] 사용자 승인"
    }
    $wipGateLines += "  - 상태: 대기 중"
    if ($i -lt $mergedStages.Count - 1) { $wipGateLines += "" }
}
$dynamicVars.WipValidationGates = $wipGateLines -join "`n"

# ── GATE_OVERVIEW_TABLE: GATES.md.tmpl용 게이트 개요 테이블 행 ──
$gateTableLines = @()
for ($i = 0; $i -lt $mergedStages.Count; $i++) {
    $ms = $mergedStages[$i]
    $nextStage = if ($i -lt $mergedStages.Count - 1) { $mergedStages[$i + 1].Name } else { "완료" }
    $selfCheck = "$($ms.Agent) 2회"
    $crossCheck = if ($ms.CrosscheckAgent) { "$($ms.CrosscheckAgent) 1회" } else { "-" }

    # 롤백 대상 표시
    if ($ms.Name -eq $ms.RollbackTo) {
        $rollbackDisplay = "$($ms.Name) 재$($ms.KoreanName)"
    } elseif ($null -eq $ms.CrosscheckAgent) {
        $rollbackDisplay = "적절 단계로 롤백"
    } else {
        $rbMeta = $stagesConfig.($ms.RollbackTo)
        if ($rbMeta) {
            $rollbackDisplay = "$($ms.RollbackTo) 재$($rbMeta.koreanName)"
        } else {
            $rollbackDisplay = "$($ms.RollbackTo)로 롤백"
        }
    }

    $gateTableLines += "| $($ms.Gate) | $($ms.Name) → $nextStage | $selfCheck | $crossCheck | $rollbackDisplay |"
}
$dynamicVars.GateOverviewTable = $gateTableLines -join "`n"

# ── GATE_DETAILS: GATES.md.tmpl용 게이트별 상세 통과 조건 ──
$gateDetailLines = @()
for ($i = 0; $i -lt $mergedStages.Count; $i++) {
    $ms = $mergedStages[$i]
    $nextStage = if ($i -lt $mergedStages.Count - 1) { $mergedStages[$i + 1].Name } else { "완료" }

    $gateDetailLines += "**$($ms.Gate) ($($ms.Name) → $nextStage)**"
    foreach ($check in $ms.GateChecks) {
        # gateChecks 내부의 템플릿 변수를 미리 해결
        $resolvedCheck = $check.Replace('{{LANGUAGE_SPECIFIC_GATE_CHECKS}}', $config.languageRules.validationItems)
        $gateDetailLines += "- ✅ $resolvedCheck"
    }
    $gateDetailLines += "- ✅ $($ms.Agent) 1차 검증"
    $gateDetailLines += "- ✅ $($ms.Agent) 2차 검증"
    if ($ms.CrosscheckAgent) {
        $gateDetailLines += "- ✅ $($ms.CrosscheckAgent) 크로스체크"
    } else {
        $gateDetailLines += "- ✅ coordinator 최종 검증"
    }
    if ($i -lt $mergedStages.Count - 1) { $gateDetailLines += "" }
}
$dynamicVars.GateDetails = $gateDetailLines -join "`n"

# ── CROSS_STAGE_REVIEW_ROWS: AGENTS.md.tmpl용 크로스체크 검증 테이블 행 ──
$reviewRowLines = @()
for ($i = 0; $i -lt $mergedStages.Count - 1; $i++) {
    $ms = $mergedStages[$i]
    $nextMs = $mergedStages[$i + 1]
    $checker = if ($ms.CrosscheckAgent) { $ms.CrosscheckAgent } else { "reviewer" }
    $reviewRowLines += "| $($ms.Name) → $($nextMs.Name) | $checker | $($ms.Gate) 크로스체크 검증 |"
}
$dynamicVars.CrossStageReviewRows = $reviewRowLines -join "`n"

# ── WIP_FOLDER_TREE: AGENTS.md.tmpl용 폴더 구조 트리 ──
# Review(coordinator)는 전체 관리 역할이므로 독립 WIP 템플릿 불필요
$nonReviewStages = @($mergedStages | Where-Object { $_.CrosscheckAgent -ne $null })
$wipTreeLines = @()
$wipTreeLines += ".wips/"
$wipTreeLines += "├── templates/           # 템플릿 파일 (읽기 전용)"
for ($i = 0; $i -lt $nonReviewStages.Count; $i++) {
    $ts = $nonReviewStages[$i]
    $prefix = if ($i -lt $nonReviewStages.Count - 1) { "│   ├──" } else { "│   └──" }
    $wipTreeLines += "$prefix WIP-$($ts.Name)-YYYYMMDD-NNN.md"
}
$wipTreeLines += "└── active/              # 독립 WIP 작성 폴더 (쓰기 전용)"
for ($i = 0; $i -lt $nonReviewStages.Count; $i++) {
    $ts = $nonReviewStages[$i]
    $prefix = if ($i -lt $nonReviewStages.Count - 1) { "    ├──" } else { "    └──" }
    $wipTreeLines += "$prefix $($ts.Name)/"
}
$dynamicVars.WipFolderTree = $wipTreeLines -join "`n"

# ── AGENT_STAGE_TABLE: AGENTS.md.tmpl용 에이전트별 매핑 테이블 행 ──
$agentTableLines = @()
foreach ($ms in $nonReviewStages) {
    $agentTableLines += "| **$($ms.Agent)** | $($ms.Name) | ``WIP-$($ms.Name)-YYYYMMDD-NNN.md`` | ``.wips/active/$($ms.Name)/`` | ``.wips/templates/WIP-$($ms.Name)-YYYYMMDD-NNN.md`` | ``.wips/active/$($ms.Name)/WIP-$($ms.Name)-YYYYMMDD-NNN.md`` |"
}
# coordinator (최종 스테이지) 별도 행
$lastStage = $mergedStages[$mergedStages.Count - 1]
$agentTableLines += "| **$($lastStage.Agent)** | $($lastStage.Name) | (전체 관리) | (해당 없음) | - | - |"
$dynamicVars.AgentStageTable = $agentTableLines -join "`n"

# ── PIPELINE_WORKFLOW_AUTO: PIPELINE.md.tmpl용 자동화 모드 워크플로우 ──
$wfAutoLines = @()
$wfAutoLines += "사용자: `"coordinator [기능명] 기능 추가`""
$wfAutoLines += '  ↓'
$wfAutoLines += 'coordinator: 작업 시작 → WorkID 생성'
for ($i = 0; $i -lt $mergedStages.Count; $i++) {
    $ms = $mergedStages[$i]
    $wfAutoLines += '  ↓'
    $wfAutoLines += "$($i + 1). $($ms.Name): $($ms.Agent) ($($ms.Summary))"
}
$dynamicVars.PipelineWorkflowAuto = $wfAutoLines -join "`n"

# ── CONVERGENCE_STAGES_TEXT / CONVERGENCE_STAGES_LIST: 수렴 검증 적용 단계 ──
$convergenceStages = @()
foreach ($ms in $mergedStages) {
    $stageMetadata = $stagesConfig.($ms.Name)
    if ($stageMetadata.convergence -eq $true) {
        $convergenceStages += @{
            Name = $ms.Name
            KoreanName = $ms.KoreanName
            Description = $stageMetadata.convergenceDescription
        }
    }
}

if ($convergenceStages.Count -gt 0) {
    $convergenceKoreanNames = $convergenceStages | ForEach-Object { $_.KoreanName }
    $dynamicVars.ConvergenceStagesText = ($convergenceKoreanNames -join "/") + " 단계"

    $convListLines = @()
    $convListLines += '수렴 검증은 다음 단계에 적용됩니다 (stages.json의 `"convergence": true`):'
    foreach ($cs in $convergenceStages) {
        $convListLines += "- **$($cs.Name) ($($cs.KoreanName))**: $($cs.Description)"
    }
    $convListLines += ""
    $convListLines += "> 수렴 검증이 적용되지 않는 단계는 Gate 검증과 크로스체크로 품질을 보장합니다."
    $dynamicVars.ConvergenceStagesList = $convListLines -join "`n"
} else {
    $dynamicVars.ConvergenceStagesText = ""
    $dynamicVars.ConvergenceStagesList = ""
}

Write-Host "  $($mergedStages.Count)개 스테이지 동적 컨텐츠 생성 완료" -ForegroundColor Green

# ─────────────────────────────────────────────
# 4. .tmpl 파일 처리
# ─────────────────────────────────────────────
Write-Host "`n[4/8] 템플릿 파일 처리..." -ForegroundColor Cyan

$tmplFiles = Get-ChildItem -Path $ScriptDir -Filter "*.tmpl" -Recurse
$processedCount = 0

foreach ($tmpl in $tmplFiles) {
    $outputPath = $tmpl.FullName -replace '\.tmpl$', ''
    $content = Get-Content $tmpl.FullName -Raw -Encoding UTF8
    $content = Replace-TemplateVars $content
    Set-Content -Path $outputPath -Value $content -Encoding UTF8 -NoNewline
    $processedCount++

    $relativePath = $outputPath.Replace($ScriptDir, ".").Replace("\", "/")
    Write-Host "  생성: $relativePath" -ForegroundColor Gray
}

Write-Host "  $processedCount 개 템플릿 처리 완료" -ForegroundColor Green

# ─────────────────────────────────────────────
# 5. WIP 템플릿 생성 (메타 템플릿 + 병합 데이터)
# ─────────────────────────────────────────────
Write-Host "`n[5/8] WIP 템플릿 생성..." -ForegroundColor Cyan

$metaTemplate = Get-Content (Join-Path $ScriptDir ".wips\META-TEMPLATE.md") -Raw -Encoding UTF8

$wipsTemplateDir = Join-Path $ScriptDir ".wips\templates"
if (-not (Test-Path $wipsTemplateDir)) {
    New-Item -ItemType Directory -Path $wipsTemplateDir -Force | Out-Null
}

$wipCount = 0
foreach ($stage in $stages) {
    $stageConfig = $stagesConfig.$stage
    if ($null -eq $stageConfig) {
        Write-Host "  WARN: stages.json에 '$stage' 설정이 없습니다. 건너뜁니다." -ForegroundColor Yellow
        continue
    }

    # 병합 데이터에서 해당 스테이지 찾기 (프리셋 기반 gate 번호 사용)
    $merged = $mergedStages | Where-Object { $_.Name -eq $stage }

    # Review(crosscheckAgent=null) 스테이지는 독립 WIP 불필요 (WIP_FOLDER_TREE와 일관성 유지)
    if ([string]::IsNullOrEmpty($merged.CrosscheckAgent)) {
        continue
    }

    $wipContent = $metaTemplate

    # 스테이지별 변수 치환 (프리셋 데이터 우선)
    $wipContent = $wipContent.Replace('{{STAGE}}', $stage)
    $wipContent = $wipContent.Replace('{{AGENT}}', $merged.Agent)
    $wipContent = $wipContent.Replace('{{CROSSCHECK_AGENT}}', $merged.CrosscheckAgent)
    $wipContent = $wipContent.Replace('{{GATE}}', $merged.Gate)

    # 스테이지별 단계 내용
    $langRules = $stageConfig.langRules
    $langRules = Replace-TemplateVars $langRules
    $wipContent = $wipContent.Replace('{{LANG_RULES}}', $langRules)
    $wipContent = $wipContent.Replace('{{STAGE_STEP1}}', $stageConfig.step1)
    $wipContent = $wipContent.Replace('{{STAGE_STEP2}}', $stageConfig.step2)
    $wipContent = $wipContent.Replace('{{STAGE_STEP3}}', $stageConfig.step3)
    $wipContent = $wipContent.Replace('{{STAGE_RESULTS}}', $stageConfig.results)

    $outputFile = Join-Path $wipsTemplateDir "WIP-$stage-YYYYMMDD-NNN.md"
    Set-Content -Path $outputFile -Value $wipContent -Encoding UTF8 -NoNewline
    $wipCount++

    Write-Host "  생성: .wips/templates/WIP-$stage-YYYYMMDD-NNN.md" -ForegroundColor Gray
}

Write-Host "  $wipCount 개 WIP 템플릿 생성 완료" -ForegroundColor Green

# ─────────────────────────────────────────────
# 6. .wips/active/ 디렉토리 생성
# ─────────────────────────────────────────────
Write-Host "`n[6/8] WIP 디렉토리 구조 생성..." -ForegroundColor Cyan

foreach ($ms in $mergedStages) {
    if ([string]::IsNullOrEmpty($ms.CrosscheckAgent)) {
        continue
    }
    $activeDir = Join-Path $ScriptDir ".wips\active\$($ms.Name)"
    if (-not (Test-Path $activeDir)) {
        New-Item -ItemType Directory -Path $activeDir -Force | Out-Null
        # .gitkeep 생성
        New-Item -ItemType File -Path (Join-Path $activeDir ".gitkeep") -Force | Out-Null
    }
    Write-Host "  생성: .wips/active/$($ms.Name)/" -ForegroundColor Gray
}

# archive 디렉토리도 생성
$archiveDir = Join-Path $ScriptDir ".wips\archive"
if (-not (Test-Path $archiveDir)) {
    New-Item -ItemType Directory -Path $archiveDir -Force | Out-Null
    New-Item -ItemType File -Path (Join-Path $archiveDir ".gitkeep") -Force | Out-Null
}

# reports 디렉토리 생성
$reportsDir = Join-Path $ScriptDir "reports"
if (-not (Test-Path $reportsDir)) {
    New-Item -ItemType Directory -Path $reportsDir -Force | Out-Null
    New-Item -ItemType File -Path (Join-Path $reportsDir ".gitkeep") -Force | Out-Null
    Write-Host "  생성: reports/" -ForegroundColor Gray
}

# WORK_HISTORY.json 초기 파일 생성
$historyFile = Join-Path $ScriptDir "WORK_HISTORY.json"
if (-not (Test-Path $historyFile)) {
    $initialHistory = @'
{
  "completed_works": [],
  "cancelled_works": []
}
'@
    Set-Content -Path $historyFile -Value $initialHistory -Encoding UTF8 -NoNewline
    Write-Host "  생성: WORK_HISTORY.json" -ForegroundColor Gray
}

Write-Host "  디렉토리 구조 생성 완료" -ForegroundColor Green

# ─────────────────────────────────────────────
# 7. .example.md → .md 복사
# ─────────────────────────────────────────────
Write-Host "`n[7/8] 가이드 스켈레톤 복사..." -ForegroundColor Cyan

$exampleFiles = Get-ChildItem -Path (Join-Path $ScriptDir ".guides") -Filter "*.example.md"
foreach ($example in $exampleFiles) {
    $outputName = $example.Name -replace '\.example\.md$', '.md'
    $outputPath = Join-Path $example.DirectoryName $outputName

    if (-not (Test-Path $outputPath)) {
        Copy-Item $example.FullName $outputPath
        Write-Host "  복사: .guides/$outputName (편집 필요)" -ForegroundColor Yellow
    } else {
        Write-Host "  건너뜀: .guides/$outputName (이미 존재)" -ForegroundColor Gray
    }
}

Write-Host "  가이드 스켈레톤 복사 완료" -ForegroundColor Green

# ─────────────────────────────────────────────
# 8. 완료 요약
# ─────────────────────────────────────────────
Write-Host "`n[8/8] 초기화 완료!" -ForegroundColor Cyan
Write-Host ""
Write-Host "  ============================================" -ForegroundColor White
Write-Host "  프로젝트: $($config.project.name)" -ForegroundColor White
Write-Host "  파이프라인: $($preset.name) ($($stages.Count)단계)" -ForegroundColor White
Write-Host "  파이프라인: $($dynamicVars.PipelineArrow)" -ForegroundColor White
Write-Host "  ============================================" -ForegroundColor White
Write-Host ""

# 생성된 파일 카운트
$allFiles = Get-ChildItem -Path $ScriptDir -Recurse -File | Where-Object {
    $_.Name -notmatch '\.tmpl$' -and
    $_.Name -ne 'init.ps1' -and
    $_.Name -ne 'init.sh' -and
    $_.Name -ne 'template-config.json' -and
    $_.Name -ne 'META-TEMPLATE.md' -and
    $_.Name -ne 'stages.json' -and
    $_.DirectoryName -notmatch 'presets' -and
    $_.DirectoryName -notmatch '[\\/]\.git([\\/]|$)'
}

Write-Host "  생성된 파일: $($allFiles.Count)개" -ForegroundColor Green
Write-Host ""
Write-Host "  다음 단계:" -ForegroundColor Yellow
Write-Host '    1. .guides/BUILD_GUIDE.md 작성 (프로젝트 빌드 방법)' -ForegroundColor Yellow
Write-Host '    2. .guides/CODE_STYLE.md 작성 (코드 스타일 규칙)' -ForegroundColor Yellow
Write-Host '    3. .guides/TECHNICAL_RULES.md 작성 (기술 규칙)' -ForegroundColor Yellow
Write-Host '    4. .guides/TEST_GUIDE.md 작성 (테스트 가이드)' -ForegroundColor Yellow
Write-Host '    5. PROJECT_SUMMARY.md 내용 채우기' -ForegroundColor Yellow
Write-Host ""
Write-Host "  사용 시작: Claude Code에서 /project:명령어 로 확인" -ForegroundColor Green
Write-Host ""
