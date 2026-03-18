#!/bin/bash

# ARGO Uptime Monitor Script
# Queries the ARGO Monitoring API and writes argo_uptime_report.json to the
# node's subdirectory under the dashboard data directory.
#
# Usage: ./check_service_uptime.sh NODE_NAME API_KEY [START_DATE] [END_DATE] [dashboard_dir]
#   NODE_NAME:     Node name — used for the output directory (required)
#   API_KEY:       API key for ARGO authentication (required)
#   START_DATE:    Start date in YYYY-MM-DD format (optional, defaults to 30 days ago)
#   END_DATE:      End date in YYYY-MM-DD format (optional, defaults to today)
#   dashboard_dir: Path to the dashboard data directory (optional, defaults to ../dashboard/data)
#                  Output is written to <dashboard_dir>/<NODE_NAME>/argo_uptime_report.json
#
# Examples:
#   ./check_service_uptime.sh CESSDA my-api-key
#   ./check_service_uptime.sh CESSDA my-api-key 2026-02-01
#   ./check_service_uptime.sh CESSDA my-api-key 2026-02-01 2026-03-17
#   ./check_service_uptime.sh CESSDA my-api-key 2026-02-01 2026-03-17 /path/to/dashboard/data

set -euo pipefail

# Colour codes for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

usage() {
    echo "Usage: $0 NODE_NAME API_KEY [START_DATE] [END_DATE] [dashboard_dir]"
    echo ""
    echo "Arguments:"
    echo "  NODE_NAME     - Node name used for the output directory (required)"
    echo "  API_KEY       - API key for ARGO authentication (required)"
    echo "  START_DATE    - Start date in YYYY-MM-DD format (optional, defaults to 30 days ago)"
    echo "  END_DATE      - End date in YYYY-MM-DD format (optional, defaults to today)"
    echo "  dashboard_dir - Path to dashboard data directory (optional, defaults to ../../dashboard/data)"
    echo ""
    echo "Examples:"
    echo "  $0 CESSDA my-api-key"
    echo "  $0 CESSDA my-api-key 2026-02-01"
    echo "  $0 CESSDA my-api-key 2026-02-01 2026-03-17"
    echo "  $0 CESSDA my-api-key 2026-02-01 2026-03-17 /path/to/dashboard/data"
    exit 1
}

# Validate date format (macOS compatible)
validate_date() {
    local date_str="$1"
    if ! date -j -f "%Y-%m-%d" "$date_str" >/dev/null 2>&1; then
        echo -e "${RED}Error: Invalid date format '$date_str'. Expected YYYY-MM-DD${NC}" >&2
        exit 1
    fi
}

# Convert date to seconds since epoch (macOS compatible)
date_to_seconds() {
    local date_str="$1"
    date -j -f "%Y-%m-%d" "$date_str" "+%s" 2>/dev/null
}

# ── Parse arguments ───────────────────────────────────────────────────────────

NODE_NAME="${1:-}"
API_KEY="${2:-}"
START_DATE="${3:-}"
END_DATE="${4:-}"
DASHBOARD_DIR="${5:-../../dashboard/data}"

if [ -z "$NODE_NAME" ]; then
    echo -e "${RED}Error: NODE_NAME is required${NC}" >&2
    usage
fi

if [ -z "$API_KEY" ]; then
    echo -e "${RED}Error: API_KEY is required${NC}" >&2
    usage
fi

# Apply date defaults
if [ -z "$START_DATE" ]; then
    START_DATE=$(date -v-30d "+%Y-%m-%d")
fi

if [ -z "$END_DATE" ]; then
    END_DATE=$(date "+%Y-%m-%d")
fi

# Validate dates
validate_date "$START_DATE"
validate_date "$END_DATE"

START_SECONDS=$(date_to_seconds "$START_DATE")
END_SECONDS=$(date_to_seconds "$END_DATE")

if [ "$START_SECONDS" -ge "$END_SECONDS" ]; then
    echo -e "${RED}Error: Start date ($START_DATE) must be before end date ($END_DATE)${NC}" >&2
    exit 1
fi

# ── Resolve output path ───────────────────────────────────────────────────────

OUTPUT_DIR="${DASHBOARD_DIR}/${NODE_NAME}"
mkdir -p "$OUTPUT_DIR" || {
    echo -e "${RED}Error: cannot create output directory $OUTPUT_DIR${NC}" >&2
    exit 1
}
REPORT_FILE="${OUTPUT_DIR}/argo_uptime_report.json"

# ── Build API URL ─────────────────────────────────────────────────────────────

START_TIME="${START_DATE}T00:00:00Z"
END_TIME="${END_DATE}T23:59:59Z"
API_URL="https://api.devel.mon.argo.grnet.gr/api/v2/results/CORE/SERVICEGROUPS?start_time=${START_TIME}&end_time=${END_TIME}"

# ── Check dependencies ────────────────────────────────────────────────────────

if ! command -v jq &> /dev/null; then
    echo -e "${RED}Error: jq is required but not installed.${NC}" >&2
    echo "Install it using: brew install jq" >&2
    exit 1
fi

# ── Fetch data ────────────────────────────────────────────────────────────────

echo -e "${BLUE}==========================================${NC}"
echo -e "${BLUE}ARGO Monitoring - Uptime Report${NC}"
echo -e "${BLUE}==========================================${NC}"
echo ""
echo -e "${YELLOW}Node:${NC}   $NODE_NAME"
echo -e "${YELLOW}Period:${NC} ${START_TIME} to ${END_TIME}"
echo ""
echo -e "${YELLOW}Fetching data from API...${NC}"

RESPONSE=$(curl -s -w "\n%{http_code}" "$API_URL" \
    --header "Accept: application/json" \
    --header "x-api-key: ${API_KEY}")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" -ne 200 ]; then
    echo -e "${RED}Error: API request failed with HTTP status code $HTTP_CODE${NC}" >&2
    echo "$BODY" >&2
    exit 1
fi

echo -e "${GREEN}Data retrieved successfully!${NC}"
echo ""

# ── Parse and display results ─────────────────────────────────────────────────

PROJECT_NAME=$(echo "$BODY" | jq -r '.results[0].name // "Unknown Project"')

echo -e "${GREEN}Results:${NC}"
echo -e "${BLUE}==========================================${NC}"
echo -e "${YELLOW}Project:${NC} $PROJECT_NAME"
echo ""

TEMP_JSON="/tmp/argo_endpoints_$$.json"
echo "[]" > "$TEMP_JSON"

echo "$BODY" | jq -c '.results[0].endpoints[]?' | while read -r endpoint; do

    ENDPOINT_NAME=$(echo "$endpoint" | jq -r '.name')
    ENDPOINT_TYPE=$(echo "$endpoint" | jq -r '.type')

    # Calculate uptime, availability and reliability averages across all days
    TOTAL_UPTIME=0
    TOTAL_AVAILABILITY=0
    TOTAL_RELIABILITY=0
    TOTAL_DAYS=0

    while read -r result; do
        TOTAL_UPTIME=$(echo "$TOTAL_UPTIME + $(echo "$result" | jq -r '.uptime')" | bc)
        TOTAL_AVAILABILITY=$(echo "$TOTAL_AVAILABILITY + $(echo "$result" | jq -r '.availability')" | bc)
        TOTAL_RELIABILITY=$(echo "$TOTAL_RELIABILITY + $(echo "$result" | jq -r '.reliability')" | bc)
        TOTAL_DAYS=$((TOTAL_DAYS + 1))
    done < <(echo "$endpoint" | jq -c '.results[]?')

    if [ "$TOTAL_DAYS" -gt 0 ]; then
        UPTIME_PCT=$(echo "scale=2; ($TOTAL_UPTIME / $TOTAL_DAYS) * 100" | bc)
        AVG_AVAIL=$(echo "scale=2; $TOTAL_AVAILABILITY / $TOTAL_DAYS" | bc)
        AVG_REL=$(echo "scale=2; $TOTAL_RELIABILITY / $TOTAL_DAYS" | bc)
    else
        UPTIME_PCT="0.00"
        AVG_AVAIL="0.00"
        AVG_REL="0.00"
    fi

    # Colour-code uptime for terminal output
    UPTIME_INT=$(echo "$UPTIME_PCT" | cut -d. -f1)
    if [ "$UPTIME_INT" -ge 99 ]; then
        COLOUR=$GREEN
    elif [ "$UPTIME_INT" -ge 95 ]; then
        COLOUR=$YELLOW
    else
        COLOUR=$RED
    fi

    echo -e "${CYAN}Endpoint:${NC} $ENDPOINT_NAME"
    echo -e "  ${COLOUR}Uptime:       ${UPTIME_PCT}%${NC}"
    echo -e "  Availability: ${AVG_AVAIL}%"
    echo -e "  Reliability:  ${AVG_REL}%"
    echo -e "  Days monitored: $TOTAL_DAYS"
    echo ""

    # Accumulate into temp JSON array
    ENDPOINT_NAME_ESC=$(echo "$ENDPOINT_NAME" | sed 's/"/\\"/g')
    ENDPOINT_TYPE_ESC=$(echo "$ENDPOINT_TYPE" | sed 's/"/\\"/g')

    ENTRY=$(cat <<JSONENTRY
{
  "name": "$ENDPOINT_NAME_ESC",
  "type": "$ENDPOINT_TYPE_ESC",
  "uptime_percentage": $UPTIME_PCT,
  "average_availability": $AVG_AVAIL,
  "average_reliability": $AVG_REL,
  "days_monitored": $TOTAL_DAYS
}
JSONENTRY
)
    jq ". += [$ENTRY]" "$TEMP_JSON" > "${TEMP_JSON}.tmp" && mv "${TEMP_JSON}.tmp" "$TEMP_JSON"
done

# ── Write JSON report ─────────────────────────────────────────────────────────

ENDPOINTS_ARRAY=$(cat "$TEMP_JSON")
rm -f "$TEMP_JSON"

cat > "$REPORT_FILE" <<JSONEOF
{
  "generated": "$(date -Iseconds)",
  "api_source": "$API_URL",
  "period": {
    "start": "$START_TIME",
    "end": "$END_TIME"
  },
  "project": "$PROJECT_NAME",
  "endpoints": $ENDPOINTS_ARRAY
}
JSONEOF

echo -e "${BLUE}==========================================${NC}"
echo -e "${GREEN}Report complete${NC}"
echo ""
echo -e "  ${CYAN}JSON:${NC} $REPORT_FILE"
echo -e "${BLUE}==========================================${NC}"