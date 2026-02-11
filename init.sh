#!/usr/bin/env bash
# project-template 초기화 스크립트 (Linux/macOS)
# 사용법: ./init.sh [config-path]
# 의존성: jq (JSON 파서)

set -euo pipefail

CONFIG_PATH="${1:-template-config.json}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 색상 정의
CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
WHITE='\033[1;37m'
GRAY='\033[0;37m'
NC='\033[0m'

# jq 설치 확인
if ! command -v jq &>/dev/null; then
    echo -e "${RED}  ERROR: jq가 설치되어 있지 않습니다.${NC}"
    echo "  설치 방법:"
    echo "    macOS: brew install jq"
    echo "    Ubuntu/Debian: sudo apt-get install jq"
    echo "    CentOS/RHEL: sudo yum install jq"
    exit 1
fi

# ─────────────────────────────────────────────
# 1. 설정 파일 읽기
# ─────────────────────────────────────────────
echo -e "\n${CYAN}[1/8] 설정 파일 읽기...${NC}"

CONFIG_FILE="$SCRIPT_DIR/$CONFIG_PATH"
if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "  ${RED}ERROR: $CONFIG_FILE 파일을 찾을 수 없습니다.${NC}"
    exit 1
fi

CONFIG=$(cat "$CONFIG_FILE")

# 필수 필드 검증
REQUIRED_FIELDS=(
    "project.name:프로젝트 이름"
    "project.description:프로젝트 설명"
    "project.techStack:기술 스택"
    "project.libraries:라이브러리 목록"
    "project.buildCommand:빌드 명령어"
    "project.testCommand:테스트 명령어"
    "project.runCommand:실행 명령어"
    "project.projectFile:프로젝트 파일명"
    "project.projectStructure:프로젝트 구조"
    "project.namingConventions:명명 규칙"
    "project.featureCategories:기능 카테고리"
    "project.outputFormats:출력 포맷"
    "project.cliOptions:CLI 옵션"
    "project.domainRules:도메인 규칙"
    "pipeline.preset:파이프라인 프리셋 (lite/standard/full)"
    "languageRules.typeSafety:타입 안전성 규칙"
    "languageRules.antiPatterns:안티패턴"
    "languageRules.architectRules:아키텍트 언어 규칙"
    "languageRules.developerRules:개발자 언어 규칙"
    "languageRules.validationItems:검증 체크리스트"
    "languageRules.designReviewItems:설계 리뷰 항목"
)

MISSING_FIELDS=()
for entry in "${REQUIRED_FIELDS[@]}"; do
    FIELD_PATH="${entry%%:*}"
    FIELD_DESC="${entry##*:}"
    JQ_PATH=".$(echo "$FIELD_PATH" | sed 's/\././g')"
    VALUE=$(echo "$CONFIG" | jq -r "$JQ_PATH // empty")
    if [ -z "$VALUE" ]; then
        MISSING_FIELDS+=("  - $FIELD_PATH ($FIELD_DESC)")
    fi
done

if [ ${#MISSING_FIELDS[@]} -gt 0 ]; then
    echo -e "  ${RED}ERROR: 다음 필수 필드가 비어있거나 누락되었습니다:${NC}"
    for msg in "${MISSING_FIELDS[@]}"; do
        echo -e "  ${RED}$msg${NC}"
    done
    echo -e "\n  ${YELLOW}template-config.example.json을 참고하여 필드를 채워주세요.${NC}"
    exit 1
fi

PROJECT_NAME=$(echo "$CONFIG" | jq -r '.project.name')
TECH_STACK=$(echo "$CONFIG" | jq -r '.project.techStack')

echo -e "  ${GREEN}프로젝트: $PROJECT_NAME${NC}"
echo -e "  ${GREEN}기술 스택: $TECH_STACK${NC}"

# ─────────────────────────────────────────────
# 2. 프리셋 및 스테이지 설정 로드
# ─────────────────────────────────────────────
echo -e "\n${CYAN}[2/8] 파이프라인 프리셋 로드...${NC}"

PRESET_NAME=$(echo "$CONFIG" | jq -r '.pipeline.preset')
PRESET_FILE="$SCRIPT_DIR/presets/$PRESET_NAME.json"

if [ ! -f "$PRESET_FILE" ]; then
    echo -e "  ${RED}ERROR: 프리셋 '$PRESET_NAME' 을 찾을 수 없습니다. (lite/standard/full)${NC}"
    exit 1
fi

PRESET=$(cat "$PRESET_FILE")
PRESET_DISPLAY_NAME=$(echo "$PRESET" | jq -r '.name')

# 스테이지 배열 읽기
mapfile -t STAGES < <(echo "$PRESET" | jq -r '.stages[]')
STAGE_COUNT=${#STAGES[@]}

echo -e "  ${GREEN}프리셋: $PRESET_DISPLAY_NAME (${STAGE_COUNT}단계)${NC}"
echo -e "  ${GREEN}단계: $(IFS=' -> '; echo "${STAGES[*]}")${NC}"

# 스테이지 메타데이터 로드
STAGES_CONFIG=$(cat "$SCRIPT_DIR/.wips/stages.json")
echo -e "  ${GREEN}스테이지 메타데이터 로드 완료${NC}"

# ─────────────────────────────────────────────
# 헬퍼: 롤백 대상 해결 함수
# ─────────────────────────────────────────────
resolve_rollback_target() {
    local target="$1"
    local current_index="$2"

    # rollbackTo가 비어있으면 자기 자신
    if [ -z "$target" ] || [ "$target" = "null" ]; then
        echo "${STAGES[$current_index]}"
        return
    fi

    # 현재 프리셋에 존재하면 그대로
    for s in "${STAGES[@]}"; do
        if [ "$s" = "$target" ]; then
            echo "$target"
            return
        fi
    done

    # 없으면 가장 가까운 이전 스테이지
    for ((i = current_index - 1; i >= 0; i--)); do
        echo "${STAGES[$i]}"
        return
    done

    echo "${STAGES[0]}"
}

# ─────────────────────────────────────────────
# 헬퍼: 템플릿 변수 치환 함수
# ─────────────────────────────────────────────
replace_template_vars() {
    local content="$1"

    # 동적 파이프라인 변수 (먼저 치환)
    content="${content//\{\{PIPELINE_ARROW\}\}/$DYN_PIPELINE_ARROW}"
    content="${content//\{\{GATED_PIPELINE_ARROW\}\}/$DYN_GATED_PIPELINE_ARROW}"
    content="${content//\{\{STAGE_COUNT\}\}/$STAGE_COUNT}"
    content="${content//\{\{PIPELINE_STAGES_LIST\}\}/$DYN_PIPELINE_STAGES_LIST}"
    content="${content//\{\{WIP_COMPLETED_STEPS\}\}/$DYN_WIP_COMPLETED_STEPS}"
    content="${content//\{\{WIP_VALIDATION_GATES\}\}/$DYN_WIP_VALIDATION_GATES}"
    content="${content//\{\{GATE_OVERVIEW_TABLE\}\}/$DYN_GATE_OVERVIEW_TABLE}"
    content="${content//\{\{GATE_DETAILS\}\}/$DYN_GATE_DETAILS}"
    content="${content//\{\{CROSS_STAGE_REVIEW_ROWS\}\}/$DYN_CROSS_STAGE_REVIEW_ROWS}"
    content="${content//\{\{WIP_FOLDER_TREE\}\}/$DYN_WIP_FOLDER_TREE}"
    content="${content//\{\{AGENT_STAGE_TABLE\}\}/$DYN_AGENT_STAGE_TABLE}"
    content="${content//\{\{PIPELINE_WORKFLOW_AUTO\}\}/$DYN_PIPELINE_WORKFLOW_AUTO}"

    # 프로젝트 정보
    content="${content//\{\{PROJECT_NAME\}\}/$(echo "$CONFIG" | jq -r '.project.name')}"
    content="${content//\{\{PROJECT_DESCRIPTION\}\}/$(echo "$CONFIG" | jq -r '.project.description')}"
    content="${content//\{\{TECH_STACK\}\}/$(echo "$CONFIG" | jq -r '.project.techStack')}"
    content="${content//\{\{LIBRARIES\}\}/$(echo "$CONFIG" | jq -r '.project.libraries')}"
    content="${content//\{\{BUILD_COMMAND\}\}/$(echo "$CONFIG" | jq -r '.project.buildCommand')}"
    content="${content//\{\{TEST_COMMAND\}\}/$(echo "$CONFIG" | jq -r '.project.testCommand')}"
    content="${content//\{\{RUN_COMMAND\}\}/$(echo "$CONFIG" | jq -r '.project.runCommand')}"
    content="${content//\{\{PROJECT_FILE\}\}/$(echo "$CONFIG" | jq -r '.project.projectFile')}"
    content="${content//\{\{PROJECT_STRUCTURE\}\}/$(echo "$CONFIG" | jq -r '.project.projectStructure')}"
    content="${content//\{\{NAMING_CONVENTIONS\}\}/$(echo "$CONFIG" | jq -r '.project.namingConventions')}"
    content="${content//\{\{FEATURE_CATEGORIES\}\}/$(echo "$CONFIG" | jq -r '.project.featureCategories')}"
    content="${content//\{\{OUTPUT_FORMATS\}\}/$(echo "$CONFIG" | jq -r '.project.outputFormats')}"
    content="${content//\{\{CLI_OPTIONS\}\}/$(echo "$CONFIG" | jq -r '.project.cliOptions')}"
    content="${content//\{\{DOMAIN_RULES\}\}/$(echo "$CONFIG" | jq -r '.project.domainRules')}"
    content="${content//\{\{COMMAND_COUNT\}\}/14}"

    # 언어별 규칙
    local VALIDATION_ITEMS
    VALIDATION_ITEMS=$(echo "$CONFIG" | jq -r '.languageRules.validationItems')
    content="${content//\{\{TYPE_SAFETY_RULES\}\}/$(echo "$CONFIG" | jq -r '.languageRules.typeSafety')}"
    content="${content//\{\{TYPE_SAFETY_ANTIPATTERNS\}\}/$(echo "$CONFIG" | jq -r '.languageRules.antiPatterns')}"
    content="${content//\{\{ARCHITECT_LANG_RULES\}\}/$(echo "$CONFIG" | jq -r '.languageRules.architectRules')}"
    content="${content//\{\{DEVELOPER_LANG_RULES\}\}/$(echo "$CONFIG" | jq -r '.languageRules.developerRules')}"
    content="${content//\{\{DESIGN_REVIEW_ITEMS\}\}/$(echo "$CONFIG" | jq -r '.languageRules.designReviewItems')}"
    content="${content//\{\{VALIDATION_ITEMS\}\}/$VALIDATION_ITEMS}"
    content="${content//\{\{LANG_RULES\}\}/$VALIDATION_ITEMS}"
    content="${content//\{\{LANGUAGE_SPECIFIC_GATE_CHECKS\}\}/$VALIDATION_ITEMS}"
    content="${content//\{\{PROJECT_FILE_STRUCTURE\}\}/$(echo "$CONFIG" | jq -r '.project.projectStructure')}"
    content="${content//\{\{PROJECT_EXAMPLES\}\}/$(echo "$CONFIG" | jq -r '.project.projectStructure')}"

    # 절대 규칙 요약
    local TYPE_SAFETY
    TYPE_SAFETY=$(echo "$CONFIG" | jq -r '.languageRules.typeSafety')
    local HARD_BLOCKS="- **타입 안전성**: ${TYPE_SAFETY}
- **빈 catch 블록 금지**: catch(e) {} 사용 금지
- **추측 금지**: 모호한 요청은 반드시 사용자에게 확인"
    content="${content//\{\{ABSOLUTE_RULES_SUMMARY\}\}/$HARD_BLOCKS}"
    content="${content//\{\{HARD_BLOCKS_SUMMARY\}\}/$HARD_BLOCKS}"

    # 에러 체크리스트 및 기술 원칙
    local BUILD_ERROR_CHECKLIST
    BUILD_ERROR_CHECKLIST=$(echo "$CONFIG" | jq -r '.languageRules.buildErrorChecklist // ""')
    content="${content//\{\{BUILD_ERROR_CHECKLIST\}\}/$BUILD_ERROR_CHECKLIST}"
    local RUNTIME_ERROR_CHECKLIST
    RUNTIME_ERROR_CHECKLIST=$(echo "$CONFIG" | jq -r '.languageRules.runtimeErrorChecklist // ""')
    content="${content//\{\{RUNTIME_ERROR_CHECKLIST\}\}/$RUNTIME_ERROR_CHECKLIST}"
    local TECHNICAL_PRINCIPLES
    TECHNICAL_PRINCIPLES=$(echo "$CONFIG" | jq -r '.languageRules.technicalPrinciples // ""')
    content="${content//\{\{TECHNICAL_PRINCIPLES\}\}/$TECHNICAL_PRINCIPLES}"

    # 코드 패턴
    local CODE_PATTERNS
    CODE_PATTERNS=$(echo "$CONFIG" | jq -r '.languageRules.codePatterns // ""')
    content="${content//\{\{CODE_PATTERNS\}\}/$CODE_PATTERNS}"

    echo "$content"
}

# ─────────────────────────────────────────────
# 3. 동적 파이프라인 컨텐츠 생성
# ─────────────────────────────────────────────
echo -e "\n${CYAN}[3/8] 동적 파이프라인 컨텐츠 생성...${NC}"

# 병합 데이터 배열 (각 스테이지별)
declare -a MERGED_NAME MERGED_AGENT MERGED_CROSSCHECK MERGED_GATE
declare -a MERGED_SUMMARY MERGED_KOREAN MERGED_ROLLBACK

for ((i = 0; i < STAGE_COUNT; i++)); do
    STAGE_NAME="${STAGES[$i]}"

    # 프리셋 에이전트 데이터 (우선)
    PRESET_AGENT=$(echo "$PRESET" | jq -r ".agents.\"$STAGE_NAME\".agent // empty")
    PRESET_CROSSCHECK=$(echo "$PRESET" | jq -r ".agents.\"$STAGE_NAME\".crosscheckAgent // empty")

    # stages.json 메타데이터
    META_AGENT=$(echo "$STAGES_CONFIG" | jq -r ".\"$STAGE_NAME\".agent // empty")
    META_CROSSCHECK=$(echo "$STAGES_CONFIG" | jq -r ".\"$STAGE_NAME\".crosscheckAgent // empty")
    META_SUMMARY=$(echo "$STAGES_CONFIG" | jq -r ".\"$STAGE_NAME\".summary // empty")
    META_KOREAN=$(echo "$STAGES_CONFIG" | jq -r ".\"$STAGE_NAME\".koreanName // empty")
    META_ROLLBACK=$(echo "$STAGES_CONFIG" | jq -r ".\"$STAGE_NAME\".rollbackTo // empty")

    if [ -z "$META_SUMMARY" ]; then
        echo -e "  ${YELLOW}WARN: stages.json에 '$STAGE_NAME' 설정이 없습니다. 건너뜁니다.${NC}"
        continue
    fi

    MERGED_NAME[$i]="$STAGE_NAME"
    MERGED_AGENT[$i]="${PRESET_AGENT:-$META_AGENT}"
    MERGED_CROSSCHECK[$i]="${PRESET_CROSSCHECK:-$META_CROSSCHECK}"
    MERGED_GATE[$i]="Gate-$((i + 1))"
    MERGED_SUMMARY[$i]="$META_SUMMARY"
    MERGED_KOREAN[$i]="$META_KOREAN"
    MERGED_ROLLBACK[$i]=$(resolve_rollback_target "$META_ROLLBACK" "$i")
done

MERGED_COUNT=${#MERGED_NAME[@]}

# PIPELINE_ARROW
DYN_PIPELINE_ARROW=$(IFS=' → '; echo "${STAGES[*]}")

# GATED_PIPELINE_ARROW
GATED_PARTS=""
for ((i = 0; i < MERGED_COUNT; i++)); do
    if [ $i -gt 0 ]; then GATED_PARTS="$GATED_PARTS → "; fi
    GATED_PARTS="$GATED_PARTS${MERGED_NAME[$i]} → [${MERGED_GATE[$i]}]"
done
DYN_GATED_PIPELINE_ARROW="$GATED_PARTS → 완료"

# PIPELINE_STAGES_LIST
DYN_PIPELINE_STAGES_LIST=""
for ((i = 0; i < MERGED_COUNT; i++)); do
    if [ $i -gt 0 ]; then DYN_PIPELINE_STAGES_LIST="$DYN_PIPELINE_STAGES_LIST
"; fi
    DYN_PIPELINE_STAGES_LIST="$DYN_PIPELINE_STAGES_LIST$((i + 1)). ${MERGED_NAME[$i]} (${MERGED_KOREAN[$i]}): ${MERGED_SUMMARY[$i]}"
done

# WIP_COMPLETED_STEPS
DYN_WIP_COMPLETED_STEPS=""
for ((i = 0; i < MERGED_COUNT; i++)); do
    if [ $i -gt 0 ]; then DYN_WIP_COMPLETED_STEPS="$DYN_WIP_COMPLETED_STEPS
"; fi
    DYN_WIP_COMPLETED_STEPS="$DYN_WIP_COMPLETED_STEPS- [ ] $((i + 1)). ${MERGED_NAME[$i]} (${MERGED_KOREAN[$i]}): ${MERGED_SUMMARY[$i]}"
done

# WIP_VALIDATION_GATES
DYN_WIP_VALIDATION_GATES=""
for ((i = 0; i < MERGED_COUNT; i++)); do
    NEXT_STAGE="완료"
    if [ $((i + 1)) -lt $MERGED_COUNT ]; then
        NEXT_STAGE="${MERGED_NAME[$((i + 1))]}"
    fi

    if [ $i -gt 0 ]; then DYN_WIP_VALIDATION_GATES="$DYN_WIP_VALIDATION_GATES

"; fi
    DYN_WIP_VALIDATION_GATES="$DYN_WIP_VALIDATION_GATES- [ ] **${MERGED_GATE[$i]}**: ${MERGED_NAME[$i]} → $NEXT_STAGE
  - [ ] 1차 자체 검증 (${MERGED_AGENT[$i]})
  - [ ] 2차 자체 검증 (${MERGED_AGENT[$i]})"
    if [ -n "${MERGED_CROSSCHECK[$i]}" ] && [ "${MERGED_CROSSCHECK[$i]}" != "null" ]; then
        DYN_WIP_VALIDATION_GATES="$DYN_WIP_VALIDATION_GATES
  - [ ] 크로스체크 (${MERGED_CROSSCHECK[$i]})"
    else
        DYN_WIP_VALIDATION_GATES="$DYN_WIP_VALIDATION_GATES
  - [ ] 사용자 승인"
    fi
    DYN_WIP_VALIDATION_GATES="$DYN_WIP_VALIDATION_GATES
  - 상태: 대기 중"
done

# GATE_OVERVIEW_TABLE
DYN_GATE_OVERVIEW_TABLE=""
for ((i = 0; i < MERGED_COUNT; i++)); do
    NEXT_STAGE="완료"
    if [ $((i + 1)) -lt $MERGED_COUNT ]; then
        NEXT_STAGE="${MERGED_NAME[$((i + 1))]}"
    fi
    SELF_CHECK="${MERGED_AGENT[$i]} 2회"
    if [ -n "${MERGED_CROSSCHECK[$i]}" ] && [ "${MERGED_CROSSCHECK[$i]}" != "null" ]; then
        CROSS_CHECK="${MERGED_CROSSCHECK[$i]} 1회"
    else
        CROSS_CHECK="-"
    fi

    # 롤백 표시
    if [ "${MERGED_NAME[$i]}" = "${MERGED_ROLLBACK[$i]}" ]; then
        ROLLBACK_DISPLAY="${MERGED_NAME[$i]} 재${MERGED_KOREAN[$i]}"
    elif [ -z "${MERGED_CROSSCHECK[$i]}" ] || [ "${MERGED_CROSSCHECK[$i]}" = "null" ]; then
        ROLLBACK_DISPLAY="적절 단계로 롤백"
    else
        RB_KOREAN=$(echo "$STAGES_CONFIG" | jq -r ".\"${MERGED_ROLLBACK[$i]}\".koreanName // empty")
        if [ -n "$RB_KOREAN" ]; then
            ROLLBACK_DISPLAY="${MERGED_ROLLBACK[$i]} 재${RB_KOREAN}"
        else
            ROLLBACK_DISPLAY="${MERGED_ROLLBACK[$i]}로 롤백"
        fi
    fi

    if [ $i -gt 0 ]; then DYN_GATE_OVERVIEW_TABLE="$DYN_GATE_OVERVIEW_TABLE
"; fi
    DYN_GATE_OVERVIEW_TABLE="$DYN_GATE_OVERVIEW_TABLE| ${MERGED_GATE[$i]} | ${MERGED_NAME[$i]} → $NEXT_STAGE | $SELF_CHECK | $CROSS_CHECK | $ROLLBACK_DISPLAY |"
done

# GATE_DETAILS
VALIDATION_ITEMS=$(echo "$CONFIG" | jq -r '.languageRules.validationItems')
DYN_GATE_DETAILS=""
for ((i = 0; i < MERGED_COUNT; i++)); do
    NEXT_STAGE="완료"
    if [ $((i + 1)) -lt $MERGED_COUNT ]; then
        NEXT_STAGE="${MERGED_NAME[$((i + 1))]}"
    fi

    if [ $i -gt 0 ]; then DYN_GATE_DETAILS="$DYN_GATE_DETAILS

"; fi
    DYN_GATE_DETAILS="$DYN_GATE_DETAILS**${MERGED_GATE[$i]} (${MERGED_NAME[$i]} → $NEXT_STAGE)**"

    # gateChecks 배열 순회
    GATE_CHECKS_COUNT=$(echo "$STAGES_CONFIG" | jq -r ".\"${MERGED_NAME[$i]}\".gateChecks | length")
    for ((j = 0; j < GATE_CHECKS_COUNT; j++)); do
        CHECK=$(echo "$STAGES_CONFIG" | jq -r ".\"${MERGED_NAME[$i]}\".gateChecks[$j]")
        CHECK="${CHECK//\{\{LANGUAGE_SPECIFIC_GATE_CHECKS\}\}/$VALIDATION_ITEMS}"
        DYN_GATE_DETAILS="$DYN_GATE_DETAILS
- ✅ $CHECK"
    done

    DYN_GATE_DETAILS="$DYN_GATE_DETAILS
- ✅ ${MERGED_AGENT[$i]} 1차 검증
- ✅ ${MERGED_AGENT[$i]} 2차 검증"
    if [ -n "${MERGED_CROSSCHECK[$i]}" ] && [ "${MERGED_CROSSCHECK[$i]}" != "null" ]; then
        DYN_GATE_DETAILS="$DYN_GATE_DETAILS
- ✅ ${MERGED_CROSSCHECK[$i]} 크로스체크"
    else
        DYN_GATE_DETAILS="$DYN_GATE_DETAILS
- ✅ coordinator 최종 검증"
    fi
done

# CROSS_STAGE_REVIEW_ROWS
DYN_CROSS_STAGE_REVIEW_ROWS=""
for ((i = 0; i < MERGED_COUNT - 1; i++)); do
    CHECKER="${MERGED_CROSSCHECK[$i]:-reviewer}"
    if [ "$CHECKER" = "null" ]; then CHECKER="reviewer"; fi
    if [ $i -gt 0 ]; then DYN_CROSS_STAGE_REVIEW_ROWS="$DYN_CROSS_STAGE_REVIEW_ROWS
"; fi
    DYN_CROSS_STAGE_REVIEW_ROWS="$DYN_CROSS_STAGE_REVIEW_ROWS| ${MERGED_NAME[$i]} → ${MERGED_NAME[$((i + 1))]} | $CHECKER | ${MERGED_GATE[$i]} 크로스체크 검증 |"
done

# WIP_FOLDER_TREE (Review/coordinator 제외)
DYN_WIP_FOLDER_TREE=".wips/
├── templates/           # 템플릿 파일 (읽기 전용)"
NON_REVIEW_COUNT=0
declare -a NON_REVIEW_STAGES
for ((i = 0; i < MERGED_COUNT; i++)); do
    if [ -n "${MERGED_CROSSCHECK[$i]}" ] && [ "${MERGED_CROSSCHECK[$i]}" != "null" ]; then
        NON_REVIEW_STAGES[$NON_REVIEW_COUNT]="${MERGED_NAME[$i]}"
        ((NON_REVIEW_COUNT++))
    fi
done
for ((i = 0; i < NON_REVIEW_COUNT; i++)); do
    PREFIX="│   ├──"
    if [ $((i + 1)) -eq $NON_REVIEW_COUNT ]; then PREFIX="│   └──"; fi
    DYN_WIP_FOLDER_TREE="$DYN_WIP_FOLDER_TREE
$PREFIX WIP-${NON_REVIEW_STAGES[$i]}-YYYYMMDD-NNN.md"
done
DYN_WIP_FOLDER_TREE="$DYN_WIP_FOLDER_TREE
└── active/              # 독립 WIP 작성 폴더 (쓰기 전용)"
for ((i = 0; i < NON_REVIEW_COUNT; i++)); do
    PREFIX="    ├──"
    if [ $((i + 1)) -eq $NON_REVIEW_COUNT ]; then PREFIX="    └──"; fi
    DYN_WIP_FOLDER_TREE="$DYN_WIP_FOLDER_TREE
$PREFIX ${NON_REVIEW_STAGES[$i]}/"
done

# AGENT_STAGE_TABLE
DYN_AGENT_STAGE_TABLE=""
for ((i = 0; i < NON_REVIEW_COUNT; i++)); do
    S="${NON_REVIEW_STAGES[$i]}"
    A=""
    for ((j = 0; j < MERGED_COUNT; j++)); do
        if [ "${MERGED_NAME[$j]}" = "$S" ]; then A="${MERGED_AGENT[$j]}"; break; fi
    done
    if [ $i -gt 0 ]; then DYN_AGENT_STAGE_TABLE="$DYN_AGENT_STAGE_TABLE
"; fi
    DYN_AGENT_STAGE_TABLE="$DYN_AGENT_STAGE_TABLE| **$A** | $S | \`WIP-$S-YYYYMMDD-NNN.md\` | \`.wips/active/$S/\` | \`.wips/templates/WIP-$S-YYYYMMDD-NNN.md\` | \`.wips/active/$S/WIP-$S-YYYYMMDD-NNN.md\` |"
done
# coordinator (최종 스테이지) 별도 행
LAST_AGENT="${MERGED_AGENT[$((MERGED_COUNT - 1))]}"
LAST_NAME="${MERGED_NAME[$((MERGED_COUNT - 1))]}"
DYN_AGENT_STAGE_TABLE="$DYN_AGENT_STAGE_TABLE
| **$LAST_AGENT** | $LAST_NAME | (전체 관리) | (해당 없음) | - | - |"

# PIPELINE_WORKFLOW_AUTO
DYN_PIPELINE_WORKFLOW_AUTO="사용자: \"coordinator [기능명] 기능 추가\"
  ↓
coordinator: 작업 시작 → WorkID 생성"
for ((i = 0; i < MERGED_COUNT; i++)); do
    DYN_PIPELINE_WORKFLOW_AUTO="$DYN_PIPELINE_WORKFLOW_AUTO
  ↓
$((i + 1)). ${MERGED_NAME[$i]}: ${MERGED_AGENT[$i]} (${MERGED_SUMMARY[$i]})"
done

echo -e "  ${GREEN}${MERGED_COUNT}개 스테이지 동적 컨텐츠 생성 완료${NC}"

# ─────────────────────────────────────────────
# 4. .tmpl 파일 처리
# ─────────────────────────────────────────────
echo -e "\n${CYAN}[4/8] 템플릿 파일 처리...${NC}"

PROCESSED_COUNT=0
while IFS= read -r -d '' TMPL_FILE; do
    OUTPUT_PATH="${TMPL_FILE%.tmpl}"
    CONTENT=$(cat "$TMPL_FILE")
    CONTENT=$(replace_template_vars "$CONTENT")
    printf '%s' "$CONTENT" > "$OUTPUT_PATH"
    ((PROCESSED_COUNT++))

    RELATIVE_PATH="${OUTPUT_PATH#"$SCRIPT_DIR/"}"
    echo -e "  ${GRAY}생성: ./$RELATIVE_PATH${NC}"
done < <(find "$SCRIPT_DIR" -name "*.tmpl" -print0)

echo -e "  ${GREEN}$PROCESSED_COUNT 개 템플릿 처리 완료${NC}"

# ─────────────────────────────────────────────
# 5. WIP 템플릿 생성 (메타 템플릿 + 병합 데이터)
# ─────────────────────────────────────────────
echo -e "\n${CYAN}[5/8] WIP 템플릿 생성...${NC}"

META_TEMPLATE=$(cat "$SCRIPT_DIR/.wips/META-TEMPLATE.md")

WIPS_TEMPLATE_DIR="$SCRIPT_DIR/.wips/templates"
mkdir -p "$WIPS_TEMPLATE_DIR"

WIP_COUNT=0
for ((i = 0; i < MERGED_COUNT; i++)); do
    STAGE="${MERGED_NAME[$i]}"

    WIP_CONTENT="$META_TEMPLATE"
    WIP_CONTENT="${WIP_CONTENT//\{\{STAGE\}\}/$STAGE}"
    WIP_CONTENT="${WIP_CONTENT//\{\{AGENT\}\}/${MERGED_AGENT[$i]}}"
    WIP_CONTENT="${WIP_CONTENT//\{\{CROSSCHECK_AGENT\}\}/${MERGED_CROSSCHECK[$i]}}"
    WIP_CONTENT="${WIP_CONTENT//\{\{GATE\}\}/${MERGED_GATE[$i]}}"

    # langRules 치환
    LANG_RULES=$(echo "$STAGES_CONFIG" | jq -r ".\"$STAGE\".langRules")
    LANG_RULES=$(replace_template_vars "$LANG_RULES")
    WIP_CONTENT="${WIP_CONTENT//\{\{LANG_RULES\}\}/$LANG_RULES}"

    STEP1=$(echo "$STAGES_CONFIG" | jq -r ".\"$STAGE\".step1")
    STEP2=$(echo "$STAGES_CONFIG" | jq -r ".\"$STAGE\".step2")
    STEP3=$(echo "$STAGES_CONFIG" | jq -r ".\"$STAGE\".step3")
    RESULTS=$(echo "$STAGES_CONFIG" | jq -r ".\"$STAGE\".results")

    WIP_CONTENT="${WIP_CONTENT//\{\{STAGE_STEP1\}\}/$STEP1}"
    WIP_CONTENT="${WIP_CONTENT//\{\{STAGE_STEP2\}\}/$STEP2}"
    WIP_CONTENT="${WIP_CONTENT//\{\{STAGE_STEP3\}\}/$STEP3}"
    WIP_CONTENT="${WIP_CONTENT//\{\{STAGE_RESULTS\}\}/$RESULTS}"

    OUTPUT_FILE="$WIPS_TEMPLATE_DIR/WIP-$STAGE-YYYYMMDD-NNN.md"
    printf '%s' "$WIP_CONTENT" > "$OUTPUT_FILE"
    ((WIP_COUNT++))

    echo -e "  ${GRAY}생성: .wips/templates/WIP-$STAGE-YYYYMMDD-NNN.md${NC}"
done

echo -e "  ${GREEN}$WIP_COUNT 개 WIP 템플릿 생성 완료${NC}"

# ─────────────────────────────────────────────
# 6. .wips/active/ 디렉토리 생성
# ─────────────────────────────────────────────
echo -e "\n${CYAN}[6/8] WIP 디렉토리 구조 생성...${NC}"

for STAGE in "${STAGES[@]}"; do
    ACTIVE_DIR="$SCRIPT_DIR/.wips/active/$STAGE"
    if [ ! -d "$ACTIVE_DIR" ]; then
        mkdir -p "$ACTIVE_DIR"
        touch "$ACTIVE_DIR/.gitkeep"
    fi
    echo -e "  ${GRAY}생성: .wips/active/$STAGE/${NC}"
done

# archive 디렉토리
ARCHIVE_DIR="$SCRIPT_DIR/.wips/archive"
if [ ! -d "$ARCHIVE_DIR" ]; then
    mkdir -p "$ARCHIVE_DIR"
    touch "$ARCHIVE_DIR/.gitkeep"
fi

# reports 디렉토리
REPORTS_DIR="$SCRIPT_DIR/reports"
if [ ! -d "$REPORTS_DIR" ]; then
    mkdir -p "$REPORTS_DIR"
    touch "$REPORTS_DIR/.gitkeep"
    echo -e "  ${GRAY}생성: reports/${NC}"
fi

# WORK_HISTORY.json 초기 파일
HISTORY_FILE="$SCRIPT_DIR/WORK_HISTORY.json"
if [ ! -f "$HISTORY_FILE" ]; then
    printf '%s' '{
  "completed_works": [],
  "cancelled_works": []
}' > "$HISTORY_FILE"
    echo -e "  ${GRAY}생성: WORK_HISTORY.json${NC}"
fi

echo -e "  ${GREEN}디렉토리 구조 생성 완료${NC}"

# ─────────────────────────────────────────────
# 7. .example.md → .md 복사
# ─────────────────────────────────────────────
echo -e "\n${CYAN}[7/8] 가이드 스켈레톤 복사...${NC}"

GUIDES_DIR="$SCRIPT_DIR/.guides"
if [ -d "$GUIDES_DIR" ]; then
    for EXAMPLE_FILE in "$GUIDES_DIR"/*.example.md; do
        [ -f "$EXAMPLE_FILE" ] || continue
        OUTPUT_NAME=$(basename "$EXAMPLE_FILE" .example.md).md
        OUTPUT_PATH="$GUIDES_DIR/$OUTPUT_NAME"

        if [ ! -f "$OUTPUT_PATH" ]; then
            cp "$EXAMPLE_FILE" "$OUTPUT_PATH"
            echo -e "  ${YELLOW}복사: .guides/$OUTPUT_NAME (편집 필요)${NC}"
        else
            echo -e "  ${GRAY}건너뜀: .guides/$OUTPUT_NAME (이미 존재)${NC}"
        fi
    done
fi

echo -e "  ${GREEN}가이드 스켈레톤 복사 완료${NC}"

# ─────────────────────────────────────────────
# 8. 완료 요약
# ─────────────────────────────────────────────
echo -e "\n${CYAN}[8/8] 초기화 완료!${NC}"
echo ""
echo -e "  ${WHITE}============================================${NC}"
echo -e "  ${WHITE}프로젝트: $PROJECT_NAME${NC}"
echo -e "  ${WHITE}파이프라인: $PRESET_DISPLAY_NAME (${STAGE_COUNT}단계)${NC}"
echo -e "  ${WHITE}파이프라인: $DYN_PIPELINE_ARROW${NC}"
echo -e "  ${WHITE}============================================${NC}"
echo ""

# 생성된 파일 카운트
FILE_COUNT=$(find "$SCRIPT_DIR" -type f \
    ! -name "*.tmpl" \
    ! -name "init.ps1" ! -name "init.sh" \
    ! -name "template-config.json" \
    ! -name "META-TEMPLATE.md" \
    ! -name "stages.json" \
    ! -path "*/presets/*" \
    ! -path "*/.git/*" | wc -l)

echo -e "  ${GREEN}생성된 파일: ${FILE_COUNT}개${NC}"
echo ""
echo -e "  ${YELLOW}다음 단계:${NC}"
echo -e "  ${YELLOW}  1. .guides/BUILD_GUIDE.md 작성 (프로젝트 빌드 방법)${NC}"
echo -e "  ${YELLOW}  2. .guides/CODE_STYLE.md 작성 (코드 스타일 규칙)${NC}"
echo -e "  ${YELLOW}  3. .guides/TECHNICAL_RULES.md 작성 (기술 규칙)${NC}"
echo -e "  ${YELLOW}  4. .guides/TEST_GUIDE.md 작성 (테스트 가이드)${NC}"
echo -e "  ${YELLOW}  5. PROJECT_SUMMARY.md 내용 채우기${NC}"
echo ""
echo -e "  ${GREEN}사용 시작: Claude Code에서 /project:명령어 로 확인${NC}"
echo ""
