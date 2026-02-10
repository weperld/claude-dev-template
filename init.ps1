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
Write-Host "`n[1/7] 설정 파일 읽기..." -ForegroundColor Cyan

$configFile = Join-Path $ScriptDir $ConfigPath
if (-not (Test-Path $configFile)) {
    Write-Host "  ERROR: $configFile 파일을 찾을 수 없습니다." -ForegroundColor Red
    exit 1
}

$config = Get-Content $configFile -Raw -Encoding UTF8 | ConvertFrom-Json
Write-Host "  프로젝트: $($config.project.name)" -ForegroundColor Green
Write-Host "  기술 스택: $($config.project.techStack)" -ForegroundColor Green

# ─────────────────────────────────────────────
# 2. 프리셋 로드
# ─────────────────────────────────────────────
Write-Host "`n[2/7] 파이프라인 프리셋 로드..." -ForegroundColor Cyan

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

# ─────────────────────────────────────────────
# 헬퍼: 변수 치환 함수
# ─────────────────────────────────────────────
function Replace-TemplateVars {
    param([string]$Content)

    # 프로젝트 정보
    $Content = $Content -replace '\{\{PROJECT_NAME\}\}', $config.project.name
    $Content = $Content -replace '\{\{PROJECT_DESCRIPTION\}\}', $config.project.description
    $Content = $Content -replace '\{\{TECH_STACK\}\}', $config.project.techStack
    $Content = $Content -replace '\{\{LIBRARIES\}\}', $config.project.libraries
    $Content = $Content -replace '\{\{BUILD_COMMAND\}\}', $config.project.buildCommand
    $Content = $Content -replace '\{\{TEST_COMMAND\}\}', $config.project.testCommand
    $Content = $Content -replace '\{\{RUN_COMMAND\}\}', $config.project.runCommand
    $Content = $Content -replace '\{\{PROJECT_FILE\}\}', $config.project.projectFile
    $Content = $Content -replace '\{\{PROJECT_STRUCTURE\}\}', $config.project.projectStructure
    $Content = $Content -replace '\{\{NAMING_CONVENTIONS\}\}', $config.project.namingConventions
    $Content = $Content -replace '\{\{FEATURE_CATEGORIES\}\}', $config.project.featureCategories
    $Content = $Content -replace '\{\{OUTPUT_FORMATS\}\}', $config.project.outputFormats
    $Content = $Content -replace '\{\{CLI_OPTIONS\}\}', $config.project.cliOptions
    $Content = $Content -replace '\{\{DOMAIN_RULES\}\}', $config.project.domainRules
    $Content = $Content -replace '\{\{COMMAND_COUNT\}\}', "14"

    # 언어별 규칙
    $Content = $Content -replace '\{\{TYPE_SAFETY_RULES\}\}', $config.languageRules.typeSafety
    $Content = $Content -replace '\{\{TYPE_SAFETY_ANTIPATTERNS\}\}', $config.languageRules.antiPatterns
    $Content = $Content -replace '\{\{ARCHITECT_LANG_RULES\}\}', $config.languageRules.architectRules
    $Content = $Content -replace '\{\{DEVELOPER_LANG_RULES\}\}', $config.languageRules.developerRules
    $Content = $Content -replace '\{\{VALIDATION_ITEMS\}\}', $config.languageRules.validationItems
    $Content = $Content -replace '\{\{DESIGN_REVIEW_ITEMS\}\}', $config.languageRules.designReviewItems
    $Content = $Content -replace '\{\{LANG_RULES\}\}', $config.languageRules.validationItems

    # Gate 관련
    $Content = $Content -replace '\{\{LANGUAGE_SPECIFIC_GATE_CHECKS\}\}', $config.languageRules.validationItems
    $Content = $Content -replace '\{\{PROJECT_FILE_STRUCTURE\}\}', $config.project.projectStructure
    $Content = $Content -replace '\{\{PROJECT_EXAMPLES\}\}', $config.project.projectStructure

    # 절대 규칙 요약
    $hardBlocksSummary = "- **타입 안전성**: $($config.languageRules.typeSafety)`n- **빈 catch 블록 금지**: catch(e) {} 사용 금지`n- **추측 금지**: 모호한 요청은 반드시 사용자에게 확인"
    $Content = $Content -replace '\{\{ABSOLUTE_RULES_SUMMARY\}\}', $hardBlocksSummary
    $Content = $Content -replace '\{\{HARD_BLOCKS_SUMMARY\}\}', $hardBlocksSummary

    # 코드 패턴 (빈 값이면 기본값)
    if ($config.languageRules.PSObject.Properties['codePatterns']) {
        $Content = $Content -replace '\{\{CODE_PATTERNS\}\}', $config.languageRules.codePatterns
    } else {
        $Content = $Content -replace '\{\{CODE_PATTERNS\}\}', ""
    }

    return $Content
}

# ─────────────────────────────────────────────
# 3. .tmpl 파일 처리
# ─────────────────────────────────────────────
Write-Host "`n[3/7] 템플릿 파일 처리..." -ForegroundColor Cyan

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
# 4. WIP 템플릿 생성 (메타 템플릿 + stages.json)
# ─────────────────────────────────────────────
Write-Host "`n[4/7] WIP 템플릿 생성..." -ForegroundColor Cyan

$metaTemplate = Get-Content (Join-Path $ScriptDir ".wips\META-TEMPLATE.md") -Raw -Encoding UTF8
$stagesConfig = Get-Content (Join-Path $ScriptDir ".wips\stages.json") -Raw -Encoding UTF8 | ConvertFrom-Json

$wipsTemplateDir = Join-Path $ScriptDir ".wips\templates"
if (-not (Test-Path $wipsTemplateDir)) {
    New-Item -ItemType Directory -Path $wipsTemplateDir -Force | Out-Null
}

$wipCount = 0
foreach ($stage in $stages) {
    if (-not $stagesConfig.PSObject.Properties[$stage]) {
        Write-Host "  WARN: stages.json에 '$stage' 설정이 없습니다. 건너뜁니다." -ForegroundColor Yellow
        continue
    }

    $stageConfig = $stagesConfig.$stage
    $wipContent = $metaTemplate

    # 스테이지별 변수 치환
    $wipContent = $wipContent -replace '\{\{STAGE\}\}', $stage
    $wipContent = $wipContent -replace '\{\{AGENT\}\}', $stageConfig.agent
    $wipContent = $wipContent -replace '\{\{CROSSCHECK_AGENT\}\}', $stageConfig.crosscheckAgent
    $wipContent = $wipContent -replace '\{\{GATE\}\}', $stageConfig.gate

    # 스테이지별 단계 내용
    $langRules = $stageConfig.langRules
    $langRules = Replace-TemplateVars $langRules
    $wipContent = $wipContent -replace '\{\{LANG_RULES\}\}', $langRules
    $wipContent = $wipContent -replace '\{\{STAGE_STEP1\}\}', $stageConfig.step1
    $wipContent = $wipContent -replace '\{\{STAGE_STEP2\}\}', $stageConfig.step2
    $wipContent = $wipContent -replace '\{\{STAGE_STEP3\}\}', $stageConfig.step3
    $wipContent = $wipContent -replace '\{\{STAGE_RESULTS\}\}', $stageConfig.results

    $outputFile = Join-Path $wipsTemplateDir "WIP-$stage-YYYYMMDD-NN.md"
    Set-Content -Path $outputFile -Value $wipContent -Encoding UTF8 -NoNewline
    $wipCount++

    Write-Host "  생성: .wips/templates/WIP-$stage-YYYYMMDD-NN.md" -ForegroundColor Gray
}

Write-Host "  $wipCount 개 WIP 템플릿 생성 완료" -ForegroundColor Green

# ─────────────────────────────────────────────
# 5. .wips/active/ 디렉토리 생성
# ─────────────────────────────────────────────
Write-Host "`n[5/7] WIP 디렉토리 구조 생성..." -ForegroundColor Cyan

foreach ($stage in $stages) {
    $activeDir = Join-Path $ScriptDir ".wips\active\$stage"
    if (-not (Test-Path $activeDir)) {
        New-Item -ItemType Directory -Path $activeDir -Force | Out-Null
        # .gitkeep 생성
        New-Item -ItemType File -Path (Join-Path $activeDir ".gitkeep") -Force | Out-Null
    }
    Write-Host "  생성: .wips/active/$stage/" -ForegroundColor Gray
}

# archive 디렉토리도 생성
$archiveDir = Join-Path $ScriptDir ".wips\archive"
if (-not (Test-Path $archiveDir)) {
    New-Item -ItemType Directory -Path $archiveDir -Force | Out-Null
    New-Item -ItemType File -Path (Join-Path $archiveDir ".gitkeep") -Force | Out-Null
}

Write-Host "  디렉토리 구조 생성 완료" -ForegroundColor Green

# ─────────────────────────────────────────────
# 6. .example.md → .md 복사
# ─────────────────────────────────────────────
Write-Host "`n[6/7] 가이드 스켈레톤 복사..." -ForegroundColor Cyan

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
# 7. 완료 요약
# ─────────────────────────────────────────────
Write-Host "`n[7/7] 초기화 완료!" -ForegroundColor Cyan
Write-Host ""
Write-Host "  ============================================" -ForegroundColor White
Write-Host "  프로젝트: $($config.project.name)" -ForegroundColor White
Write-Host "  파이프라인: $($preset.name) ($($stages.Count)단계)" -ForegroundColor White
Write-Host "  ============================================" -ForegroundColor White
Write-Host ""

# 생성된 파일 카운트
$allFiles = Get-ChildItem -Path $ScriptDir -Recurse -File | Where-Object {
    $_.Name -notmatch '\.tmpl$' -and
    $_.Name -ne 'init.ps1' -and
    $_.Name -ne 'template-config.json' -and
    $_.Name -ne 'META-TEMPLATE.md' -and
    $_.Name -ne 'stages.json' -and
    $_.DirectoryName -notmatch 'presets'
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
