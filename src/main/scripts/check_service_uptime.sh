#!/bin/bash

# ARGO Uptime Monitor Script
# Usage: ./argo_uptime.sh [API_KEY] [START_DATE] [END_DATE] [FORMAT]
# Dates should be in format: YYYY-MM-DD
# Format: text, json, or both (default: both)

set -euo pipefail

# Colour codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Colour

# Function to display usage
usage() {
    echo "Usage: $0 API_KEY [START_DATE] [END_DATE] [FORMAT]"
    echo ""
    echo "Arguments:"
    echo "  API_KEY     - API key for authentication (required)"
    echo "  START_DATE  - Start date in YYYY-MM-DD format (optional, defaults to 30 days ago)"
    echo "  END_DATE    - End date in YYYY-MM-DD format (optional, defaults to today)"
    echo "  FORMAT      - Output format: text, json, or both (optional, defaults to both)"
    echo ""
    echo "Examples:"
    echo "  $0 my-api-key-here"
    echo "  $0 my-api-key-here 2026-02-01"
    echo "  $0 my-api-key-here 2026-02-01 2026-02-28"
    echo "  $0 my-api-key-here 2026-02-01 2026-02-28 json"
    exit 1
}

# Function to validate date format
validate_date() {
    local date_str="$1"
    if ! date -j -f "%Y-%m-%d" "$date_str" >/dev/null 2>&1; then
        echo -e "${RED}Error: Invalid date format '$date_str'. Expected YYYY-MM-DD${NC}" >&2
        exit 1
    fi
}

# Function to convert date to seconds since epoch (macOS compatible)
date_to_seconds() {
    local date_str="$1"
    date -j -f "%Y-%m-%d" "$date_str" "+%s" 2>/dev/null
}

# Parse command line arguments
API_KEY="${1:-}"
START_DATE="${2:-}"
END_DATE="${3:-}"
FORMAT="${4:-both}"

# Check if API key is provided
if [ -z "$API_KEY" ]; then
    echo -e "${RED}Error: API key is required${NC}" >&2
    usage
fi

# Set default dates if not provided
if [ -z "$START_DATE" ]; then
    # Default to 30 days ago (macOS date command)
    START_DATE=$(date -v-30d "+%Y-%m-%d")
fi

if [ -z "$END_DATE" ]; then
    # Default to today
    END_DATE=$(date "+%Y-%m-%d")
fi

# Validate format argument
case "$FORMAT" in
    text|txt)
        GENERATE_TEXT=true
        GENERATE_JSON=false
        ;;
    json)
        GENERATE_TEXT=false
        GENERATE_JSON=true
        ;;
    both)
        GENERATE_TEXT=true
        GENERATE_JSON=true
        ;;
    *)
        echo -e "${RED}Invalid format: $FORMAT${NC}"
        echo "Valid formats: text, json, both"
        exit 1
        ;;
esac

# Validate date formats
validate_date "$START_DATE"
validate_date "$END_DATE"

# Check that start_date is before end_date
START_SECONDS=$(date_to_seconds "$START_DATE")
END_SECONDS=$(date_to_seconds "$END_DATE")

if [ "$START_SECONDS" -ge "$END_SECONDS" ]; then
    echo -e "${RED}Error: Start date ($START_DATE) must be before end date ($END_DATE)${NC}" >&2
    exit 1
fi

# Construct API URL with timestamps
START_TIME="${START_DATE}T00:00:00Z"
END_TIME="${END_DATE}T23:59:59Z"
API_URL="https://api.devel.mon.argo.grnet.gr/api/v2/results/CORE/SERVICEGROUPS?start_time=${START_TIME}&end_time=${END_TIME}"

# Create timestamp for filenames
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT_FILE_TXT="argo_uptime_report_${TIMESTAMP}.txt"
REPORT_FILE_JSON="argo_uptime_report_${TIMESTAMP}.json"

echo -e "${BLUE}==========================================${NC}"
echo -e "${BLUE}ARGO Monitoring - Uptime Report${NC}"
echo -e "${BLUE}==========================================${NC}"
echo ""
echo -e "${YELLOW}Period:${NC} ${START_TIME} to ${END_TIME}"
echo ""

# Make API call
echo -e "${YELLOW}Fetching data from API...${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" "$API_URL" \
    --header "Accept: application/json" \
    --header "x-api-key: ${API_KEY}")

# Extract HTTP status code and response body
HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

# Check if API call was successful
if [ "$HTTP_CODE" -ne 200 ]; then
    echo -e "${RED}Error: API request failed with HTTP status code $HTTP_CODE${NC}" >&2
    echo "$BODY" >&2
    exit 1
fi

# Check if jq is available
if ! command -v jq &> /dev/null; then
    echo -e "${RED}Error: jq is required but not installed.${NC}" >&2
    echo "Install it using: brew install jq" >&2
    exit 1
fi

echo -e "${GREEN}Data retrieved successfully!${NC}"
echo ""

# Get project name
PROJECT_NAME=$(echo "$BODY" | jq -r '.results[0].name // "Unknown Project"')

# Initialize text report
if [ "$GENERATE_TEXT" = true ]; then
    {
        echo "=========================================="
        echo "ARGO Monitoring - Uptime Report"
        echo "=========================================="
        echo "Generated: $(date)"
        echo "API Source: $API_URL"
        echo "Period: ${START_TIME} to ${END_TIME}"
        echo "=========================================="
        echo ""
        echo "Project: $PROJECT_NAME"
        echo ""
        echo "=========================================="
        echo "Endpoint Uptime Statistics"
        echo "=========================================="
        echo ""
    } > "$REPORT_FILE_TXT"
fi

# Initialize JSON report
if [ "$GENERATE_JSON" = true ]; then
    cat > "$REPORT_FILE_JSON" <<JSONEOF
{
  "generated": "$(date -Iseconds)",
  "api_source": "$API_URL",
  "period": {
    "start": "$START_TIME",
    "end": "$END_TIME"
  },
  "project": "$PROJECT_NAME",
  "endpoints": []
}
JSONEOF
fi

# Display results header
echo -e "${GREEN}Results:${NC}"
echo -e "${BLUE}==========================================${NC}"
echo -e "${YELLOW}Project:${NC} $PROJECT_NAME"
echo ""

# Temporary file for JSON endpoint data
if [ "$GENERATE_JSON" = true ]; then
    TEMP_JSON="/tmp/argo_endpoints_$$.json"
    echo "[]" > "$TEMP_JSON"
fi

# Process each endpoint
ENDPOINT_COUNT=0
echo "$BODY" | jq -c '.results[0].endpoints[]?' | while read -r endpoint; do
    ENDPOINT_COUNT=$((ENDPOINT_COUNT + 1))
    
    ENDPOINT_NAME=$(echo "$endpoint" | jq -r '.name')
    ENDPOINT_TYPE=$(echo "$endpoint" | jq -r '.type')
    
    # Calculate uptime percentage
    TOTAL_UPTIME=0
    TOTAL_DAYS=0
    
    while read -r result; do
        UPTIME=$(echo "$result" | jq -r '.uptime')
        TOTAL_UPTIME=$(echo "$TOTAL_UPTIME + $UPTIME" | bc)
        TOTAL_DAYS=$((TOTAL_DAYS + 1))
    done < <(echo "$endpoint" | jq -c '.results[]?')
    
    if [ "$TOTAL_DAYS" -gt 0 ]; then
        UPTIME_PERCENTAGE=$(echo "scale=2; ($TOTAL_UPTIME / $TOTAL_DAYS) * 100" | bc)
    else
        UPTIME_PERCENTAGE="0.00"
    fi
    
    # Get availability and reliability averages
    TOTAL_AVAILABILITY=0
    TOTAL_RELIABILITY=0
    
    while read -r result; do
        AVAIL=$(echo "$result" | jq -r '.availability')
        REL=$(echo "$result" | jq -r '.reliability')
        TOTAL_AVAILABILITY=$(echo "$TOTAL_AVAILABILITY + $AVAIL" | bc)
        TOTAL_RELIABILITY=$(echo "$TOTAL_RELIABILITY + $REL" | bc)
    done < <(echo "$endpoint" | jq -c '.results[]?')
    
    if [ "$TOTAL_DAYS" -gt 0 ]; then
        AVG_AVAILABILITY=$(echo "scale=2; $TOTAL_AVAILABILITY / $TOTAL_DAYS" | bc)
        AVG_RELIABILITY=$(echo "scale=2; $TOTAL_RELIABILITY / $TOTAL_DAYS" | bc)
    else
        AVG_AVAILABILITY="0.00"
        AVG_RELIABILITY="0.00"
    fi
    
    # Colour code based on uptime percentage
    UPTIME_INT=$(echo "$UPTIME_PERCENTAGE" | cut -d. -f1)
    if [ "$UPTIME_INT" -ge 99 ]; then
        COLOUR=$GREEN
    elif [ "$UPTIME_INT" -ge 95 ]; then
        COLOUR=$YELLOW
    else
        COLOUR=$RED
    fi
    
    # Terminal output
    echo -e "${CYAN}Endpoint:${NC} $ENDPOINT_NAME"
    echo -e "  ${COLOUR}Uptime: ${UPTIME_PERCENTAGE}%${NC}"
    echo -e "  Availability: ${AVG_AVAILABILITY}%"
    echo -e "  Reliability: ${AVG_RELIABILITY}%"
    echo -e "  Days monitored: $TOTAL_DAYS"
    echo ""
    
    # Add to text report
    if [ "$GENERATE_TEXT" = true ]; then
        {
            echo "Endpoint: $ENDPOINT_NAME"
            echo "  Type: $ENDPOINT_TYPE"
            echo "  Uptime: ${UPTIME_PERCENTAGE}%"
            echo "  Availability: ${AVG_AVAILABILITY}%"
            echo "  Reliability: ${AVG_RELIABILITY}%"
            echo "  Days Monitored: $TOTAL_DAYS"
            echo ""
        } >> "$REPORT_FILE_TXT"
    fi
    
    # Add to JSON (escape values properly)
    if [ "$GENERATE_JSON" = true ]; then
        ENDPOINT_NAME_ESC=$(echo "$ENDPOINT_NAME" | sed 's/"/\\"/g')
        ENDPOINT_TYPE_ESC=$(echo "$ENDPOINT_TYPE" | sed 's/"/\\"/g')
        
        ENTRY=$(cat <<JSONENTRY
{
  "name": "$ENDPOINT_NAME_ESC",
  "type": "$ENDPOINT_TYPE_ESC",
  "uptime_percentage": $UPTIME_PERCENTAGE,
  "average_availability": $AVG_AVAILABILITY,
  "average_reliability": $AVG_RELIABILITY,
  "days_monitored": $TOTAL_DAYS
}
JSONENTRY
)
        jq ". += [$ENTRY]" "$TEMP_JSON" > "${TEMP_JSON}.tmp" && mv "${TEMP_JSON}.tmp" "$TEMP_JSON"
    fi
done

# Finalize JSON report
if [ "$GENERATE_JSON" = true ] && [ -f "$TEMP_JSON" ]; then
    # Read the endpoints array from temp file and merge into main JSON
    ENDPOINTS_ARRAY=$(cat "$TEMP_JSON")
    
    # Update the JSON file with the endpoints array
    jq ".endpoints = $ENDPOINTS_ARRAY" "$REPORT_FILE_JSON" > "${REPORT_FILE_JSON}.tmp" && mv "${REPORT_FILE_JSON}.tmp" "$REPORT_FILE_JSON"
    
    rm -f "$TEMP_JSON"
fi

# Add footer to text report
if [ "$GENERATE_TEXT" = true ]; then
    {
        echo "=========================================="
        echo "End of Report"
        echo "=========================================="
    } >> "$REPORT_FILE_TXT"
fi

echo -e "${BLUE}==========================================${NC}"
echo -e "${GREEN}Report complete${NC}"
echo ""
echo "Reports generated:"
if [ "$GENERATE_TEXT" = true ]; then
    echo -e "  ${CYAN}Text:${NC} $REPORT_FILE_TXT"
fi
if [ "$GENERATE_JSON" = true ]; then
    echo -e "  ${CYAN}JSON:${NC} $REPORT_FILE_JSON"
fi
echo -e "${BLUE}==========================================${NC}"