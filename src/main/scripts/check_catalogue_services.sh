#!/bin/bash

# CESDA Resource Catalogue services Checker
# Reads JSON from API and checks availability of each service webpage
#
# Usage: ./check_catalogue_services.sh [format] [bearer_token]
#   format: text, json, or both (default: both)
#   bearer_token: Optional Bearer token for API authentication
#   Example: ./check_catalogue_services.sh json "your-token-here"
#   Example: ./check_catalogue_services.sh both "your-token-here"

API_URL="https://providers.sandbox.eosc-beyond.eu/api/service/all?suspended=false&keyword=CESSDA&from=0&quantity=20&order=asc"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT_FILE_TXT="catalogue_services_report_${TIMESTAMP}.txt"
REPORT_FILE_JSON="catalogue_services_report_${TIMESTAMP}.json"

# Parse command line arguments
FORMAT="${1:-both}"
BEARER_TOKEN="${2:-YOUR_BEARER_TOKEN_HERE}"

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
        echo "Invalid format: $FORMAT"
        echo "Usage: $0 [text|json|both] [bearer_token]"
        exit 1
        ;;
esac

# Colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "======================================"
echo "EOSC BEYOND Service Availability Report"
echo "======================================"
echo "Generated: $(date)"
echo "API Source: $API_URL"
echo "======================================"
echo ""

# Fetch JSON from API with Bearer token
echo "Fetching service data..."
if [ "$BEARER_TOKEN" = "YOUR_BEARER_TOKEN_HERE" ]; then
    echo -e "${YELLOW}WARNING: Using placeholder Bearer token. Replace with actual token.${NC}"
    echo ""
fi

echo "Executing curl command with verbose output..."
echo "URL: $API_URL"
echo ""

# Create temporary files for curl output
CURL_OUTPUT="/tmp/curl_output_$$.log"
CURL_RESPONSE="/tmp/curl_response_$$.json"

# Execute curl with verbose output
curl -v \
  --header 'Content-Type: application/json' \
  --header "Authorization: Bearer $BEARER_TOKEN" \
  --header 'Accept: application/json' \
  "$API_URL" \
  -o "$CURL_RESPONSE" \
  2> "$CURL_OUTPUT"

CURL_EXIT_CODE=$?

echo ""
echo "=== CURL VERBOSE OUTPUT ==="
cat "$CURL_OUTPUT"
echo "==========================="
echo ""

# Read the JSON response
JSON_DATA=$(cat "$CURL_RESPONSE" 2>/dev/null)

if [ $CURL_EXIT_CODE -ne 0 ]; then
    echo -e "${RED}ERROR: curl command failed with exit code $CURL_EXIT_CODE${NC}"
    echo "Please check:"
    echo "  - Network connectivity"
    echo "  - API endpoint accessibility"
    echo ""
    echo "Verbose output above shows connection details"
    exit 1
fi

if [ -z "$JSON_DATA" ]; then
    echo -e "${RED}ERROR: No data received from API${NC}"
    echo "Please check:"
    echo "  - Bearer token validity"
    echo "  - API endpoint accessibility"
    echo "  - HTTP status code in verbose output above"
    exit 1
fi

# Check if response is valid JSON
if ! echo "$JSON_DATA" | grep -q '^{'; then
    echo -e "${RED}ERROR: Response is not valid JSON${NC}"
    echo "Response received:"
    echo "$JSON_DATA"
    echo ""
    echo "This might indicate:"
    echo "  - Invalid or expired Bearer token"
    echo "  - API endpoint returned HTML error page"
    echo "  - Incorrect API URL"
    exit 1
fi

# Check if response contains an error
if echo "$JSON_DATA" | grep -qi '"error"'; then
    echo -e "${YELLOW}WARNING: API response contains error field${NC}"
    echo "Response: $JSON_DATA"
    echo ""
    # Continue anyway in case it's just a field name
fi

echo "Data retrieved successfully!"
echo ""
echo "=== JSON RESPONSE (first 500 characters) ==="
echo "$JSON_DATA" | head -c 500
echo ""
echo "============================================"
echo ""

# Initialise text report if needed
if [ "$GENERATE_TEXT" = true ]; then
    {
        echo "======================================"
        echo "EOSC BEYOND Service Availability Report"
        echo "======================================"
        echo "Generated: $(date)"
        echo "API Source: $API_URL"
        echo "======================================"
        echo ""
    } > "$REPORT_FILE_TXT"
fi

# Initialise JSON report if needed
if [ "$GENERATE_JSON" = true ]; then
    JSON_RESULTS="[]"
fi

# Extract total count
TOTAL=$(echo "$JSON_DATA" | grep -o '"total"[[:space:]]*:[[:space:]]*[0-9]*' | grep -o '[0-9]*')
echo "Total services found: $TOTAL"
if [ "$GENERATE_TEXT" = true ]; then
    echo "Total services found: $TOTAL" >> "$REPORT_FILE_TXT"
    echo "" >> "$REPORT_FILE_TXT"
fi
echo ""

# Parse services and check each webpage
echo "Checking service webpages..."
echo ""

# Use jq if available, otherwise use grep/sed parsing
if command -v jq &> /dev/null; then
    # Using jq for reliable JSON parsing
    COUNTER=0
    echo "$JSON_DATA" | jq -r '.results[] | "\(.name)|\(.webpage // "NO_WEBPAGE")|\(.id // "NO_ID")|\(.abbreviation // "NO_ABBR")"' | while IFS='|' read -r name webpage service_id abbreviation; do
        
        # Handle services without webpage
        if [ "$webpage" = "NO_WEBPAGE" ] || [ -z "$webpage" ]; then
            printf "%-50s " "$name"
            STATUS="No webpage defined"
            COLOUR=$YELLOW
            HTTP_CODE="N/A"
            echo -e "${COLOUR}${STATUS}${NC}"
        else
            printf "%-50s " "$name"
            
            # Ping the webpage (HTTP HEAD request with timeout)
            HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 --head "$webpage" 2>/dev/null)
            
            if [ "$HTTP_CODE" = "000" ]; then
                STATUS="Not available"
                COLOUR=$RED
            elif [ "$HTTP_CODE" = "404" ]; then
                STATUS="Not found"
                COLOUR=$YELLOW
            elif [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -lt 400 ]; then
                STATUS="Available"
                COLOUR=$GREEN
            else
                STATUS="Not available"
                COLOUR=$RED
            fi
            
            echo -e "${COLOUR}${STATUS}${NC}"
        fi
        
        # Add to text report
        if [ "$GENERATE_TEXT" = true ]; then
            printf "%-50s %s\n" "$name" "$STATUS" >> "$REPORT_FILE_TXT"
            if [ "$abbreviation" != "NO_ABBR" ] && [ -n "$abbreviation" ]; then
                printf "  └─ Abbreviation: %s\n" "$abbreviation" >> "$REPORT_FILE_TXT"
            fi
            printf "  └─ Service ID: %s\n" "$service_id" >> "$REPORT_FILE_TXT"
            if [ "$webpage" != "NO_WEBPAGE" ] && [ -n "$webpage" ]; then
                printf "  └─ Webpage: %s\n" "$webpage" >> "$REPORT_FILE_TXT"
                printf "  └─ HTTP Code: %s\n\n" "$HTTP_CODE" >> "$REPORT_FILE_TXT"
            else
                printf "  └─ Webpage: Not defined\n\n" >> "$REPORT_FILE_TXT"
            fi
        fi
        
        # Add to JSON report (append to temporary file since we're in a subshell)
        if [ "$GENERATE_JSON" = true ]; then
            TEMP_JSON="/tmp/cat_check_$$.json"
            if [ ! -f "$TEMP_JSON" ]; then
                echo "[]" > "$TEMP_JSON"
            fi
            
            # Escape quotes for JSON
            name_escaped=$(echo "$name" | sed 's/"/\\"/g')
            webpage_escaped=$(echo "$webpage" | sed 's/"/\\"/g')
            service_id_escaped=$(echo "$service_id" | sed 's/"/\\"/g')
            abbreviation_escaped=$(echo "$abbreviation" | sed 's/"/\\"/g')
            
            # Create JSON entry
            if [ "$webpage" = "NO_WEBPAGE" ] || [ -z "$webpage" ]; then
                ENTRY=$(cat <<EOF
{
  "name": "$name_escaped",
  "abbreviation": "$abbreviation_escaped",
  "service_id": "$service_id_escaped",
  "webpage": null,
  "status": "No webpage defined",
  "http_code": null
}
EOF
)
            else
                ENTRY=$(cat <<EOF
{
  "name": "$name_escaped",
  "abbreviation": "$abbreviation_escaped",
  "service_id": "$service_id_escaped",
  "webpage": "$webpage_escaped",
  "status": "$STATUS",
  "http_code": "$HTTP_CODE"
}
EOF
)
            fi
            
            # Append to array in temp file
            jq ". += [$ENTRY]" "$TEMP_JSON" > "${TEMP_JSON}.tmp" && mv "${TEMP_JSON}.tmp" "$TEMP_JSON"
        fi
        
        COUNTER=$((COUNTER + 1))
    done
    
    # Finalise JSON report
    if [ "$GENERATE_JSON" = true ]; then
        TEMP_JSON="/tmp/cat_check_$$.json"
        if [ -f "$TEMP_JSON" ]; then
            # Create final JSON structure
            cat > "$REPORT_FILE_JSON" <<EOF
{
  "generated": "$(date -Iseconds)",
  "api_source": "$API_URL",
  "total_services": $TOTAL,
  "services": $(cat "$TEMP_JSON")
}
EOF
            rm -f "$TEMP_JSON"
        fi
    fi
else
    # Fallback: manual parsing without jq (less reliable but works without dependencies)
    echo "Note: jq not found, using basic parsing. Install jq for better reliability."
    echo ""
    
    # Extract results array content
    RESULTS=$(echo "$JSON_DATA" | sed -n '/"results"/,/]/p')
    
    # Initialise temp file for JSON
    if [ "$GENERATE_JSON" = true ]; then
        TEMP_JSON="/tmp/cat_check_$$.json"
        echo "[]" > "$TEMP_JSON"
    fi
    
    # Counter for JSON array building
    JSON_FIRST=true
    
    # Parse each service entry
    echo "$JSON_DATA" | grep -o '"name"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/"name"[[:space:]]*:[[:space:]]*"\([^"]*\)"/\1/' | while read -r name; do
        # For each name, find the corresponding webpage in the same object
        # This is a simplified approach - may not work perfectly for all cases
        
        # Try to extract webpage for this service
        webpage=$(echo "$JSON_DATA" | grep -A 20 "\"name\"[[:space:]]*:[[:space:]]*\"$name\"" | grep -m 1 '"webpage"' | sed 's/.*"webpage"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
        service_id=$(echo "$JSON_DATA" | grep -A 20 "\"name\"[[:space:]]*:[[:space:]]*\"$name\"" | grep -m 1 '"id"' | sed 's/.*"id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
        abbreviation=$(echo "$JSON_DATA" | grep -A 20 "\"name\"[[:space:]]*:[[:space:]]*\"$name\"" | grep -m 1 '"abbreviation"' | sed 's/.*"abbreviation"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
        
        # Handle services without webpage
        if [ -z "$webpage" ]; then
            printf "%-50s " "$name"
            STATUS="No webpage defined"
            COLOUR=$YELLOW
            HTTP_CODE="N/A"
            echo -e "${COLOUR}${STATUS}${NC}"
        else
            printf "%-50s " "$name"
            
            # Ping the webpage
            HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 --head "$webpage" 2>/dev/null)
            
            if [ "$HTTP_CODE" = "000" ]; then
                STATUS="Not available"
                COLOUR=$RED
            elif [ "$HTTP_CODE" = "404" ]; then
                STATUS="Not found"
                COLOUR=$YELLOW
            elif [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -lt 400 ]; then
                STATUS="Available"
                COLOUR=$GREEN
            else
                STATUS="Not available"
                COLOUR=$RED
            fi
            
            echo -e "${COLOUR}${STATUS}${NC}"
        fi
        
        # Add to text report
        if [ "$GENERATE_TEXT" = true ]; then
            printf "%-50s %s\n" "$name" "$STATUS" >> "$REPORT_FILE_TXT"
            if [ -n "$abbreviation" ]; then
                printf "  └─ Abbreviation: %s\n" "$abbreviation" >> "$REPORT_FILE_TXT"
            fi
            if [ -n "$service_id" ]; then
                printf "  └─ Service ID: %s\n" "$service_id" >> "$REPORT_FILE_TXT"
            fi
            if [ -n "$webpage" ]; then
                printf "  └─ Webpage: %s\n" "$webpage" >> "$REPORT_FILE_TXT"
                printf "  └─ HTTP Code: %s\n\n" "$HTTP_CODE" >> "$REPORT_FILE_TXT"
            else
                printf "  └─ Webpage: Not defined\n\n" >> "$REPORT_FILE_TXT"
            fi
        fi
        
        # Add to JSON report
        if [ "$GENERATE_JSON" = true ]; then
            # Escape quotes for JSON
            name_escaped=$(echo "$name" | sed 's/"/\\"/g')
            webpage_escaped=$(echo "$webpage" | sed 's/"/\\"/g')
            service_id_escaped=$(echo "$service_id" | sed 's/"/\\"/g')
            abbreviation_escaped=$(echo "$abbreviation" | sed 's/"/\\"/g')
            
            # Build JSON entry
            if [ -z "$webpage" ]; then
                ENTRY="{\"name\":\"$name_escaped\",\"abbreviation\":\"$abbreviation_escaped\",\"service_id\":\"$service_id_escaped\",\"webpage\":null,\"status\":\"No webpage defined\",\"http_code\":null}"
            else
                ENTRY="{\"name\":\"$name_escaped\",\"abbreviation\":\"$abbreviation_escaped\",\"service_id\":\"$service_id_escaped\",\"webpage\":\"$webpage_escaped\",\"status\":\"$STATUS\",\"http_code\":\"$HTTP_CODE\"}"
            fi
            
            # Append to temp JSON file (manual JSON construction)
            CURRENT=$(cat "$TEMP_JSON")
            if [ "$JSON_FIRST" = true ]; then
                echo "[$ENTRY]" > "$TEMP_JSON"
                JSON_FIRST=false
            else
                # Remove closing bracket, add comma and new entry
                sed -i.bak '$ d' "$TEMP_JSON" 2>/dev/null || sed -i '$ d' "$TEMP_JSON"
                echo ",$ENTRY]" >> "$TEMP_JSON"
            fi
        fi
    done
    
    # Finalise JSON report
    if [ "$GENERATE_JSON" = true ]; then
        TEMP_JSON="/tmp/cat_check_$$.json"
        if [ -f "$TEMP_JSON" ]; then
            cat > "$REPORT_FILE_JSON" <<EOF
{
  "generated": "$(date -Iseconds)",
  "api_source": "$API_URL",
  "total_services": $TOTAL,
  "services": $(cat "$TEMP_JSON")
}
EOF
            rm -f "$TEMP_JSON" "${TEMP_JSON}.bak"
        fi
    fi
fi

echo ""
echo "======================================"
echo "Reports generated:"
if [ "$GENERATE_TEXT" = true ]; then
    echo "  Text: $REPORT_FILE_TXT"
fi
if [ "$GENERATE_JSON" = true ]; then
    echo "  JSON: $REPORT_FILE_JSON"
fi
echo "======================================"
