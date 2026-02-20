#!/bin/bash

# CESSDA Endpoint Capabilities Checker
# Reads JSON from API and checks availability of each capability endpoint
#
# Usage: ./check_endpoint_capabilities.sh [format]
#   format: text, json, or both (default: both)
#   Example: ./check_endpoint_capabilities.sh json

API_URL="https://node-endpoint-staging.beyond.cessda.eu/api/endpoint"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT_FILE_TXT="endpoint_report_${TIMESTAMP}.txt"
REPORT_FILE_JSON="endpoint_report_${TIMESTAMP}.json"

# Parse command line argument
FORMAT="${1:-both}"
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
        echo "Usage: $0 [text|json|both]"
        exit 1
        ;;
esac

# Colours for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Colour

echo "======================================"
echo "CESSDA Endpoint Availability Report"
echo "======================================"
echo "Generated: $(date)"
echo "API Source: $API_URL"
echo "======================================"
echo ""

# Fetch JSON from API
echo "Fetching endpoint data..."
JSON_DATA=$(curl -s "$API_URL")

if [ $? -ne 0 ] || [ -z "$JSON_DATA" ]; then
    echo -e "${RED}ERROR: Failed to fetch data from API${NC}"
    exit 1
fi

echo "Data retrieved successfully!"
echo ""

# Initialse text report if needed
if [ "$GENERATE_TEXT" = true ]; then
    {
        echo "======================================"
        echo "CESSDA Endpoint Availability Report"
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

# Extract node_endpoint
NODE_ENDPOINT=$(echo "$JSON_DATA" | grep -o '"node_endpoint"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/"node_endpoint"[[:space:]]*:[[:space:]]*"\([^"]*\)"/\1/')
echo "Node Endpoint: $NODE_ENDPOINT"

if [ "$GENERATE_TEXT" = true ]; then
    echo "Node Endpoint: $NODE_ENDPOINT" >> "$REPORT_FILE_TXT"
    echo "" >> "$REPORT_FILE_TXT"
fi

echo ""

# Parse capabilities and check each endpoint
echo "Checking capabilities..."
echo ""

# Use jq if available, otherwise use grep/sed parsing
if command -v jq &> /dev/null; then
    # Using jq for reliable JSON parsing
    COUNTER=0
    echo "$JSON_DATA" | jq -r '.capabilities[] | "\(.capability_type)|\(.endpoint)|\(.version)"' | while IFS='|' read -r capability_type endpoint version; do
        
        printf "%-30s " "$capability_type"
        
        # Ping the endpoint (HTTP HEAD request with timeout)
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 --head "$endpoint" 2>/dev/null)
        
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
        
        # Add to text report
        if [ "$GENERATE_TEXT" = true ]; then
            printf "%-30s %s\n" "$capability_type" "$STATUS" >> "$REPORT_FILE_TXT"
            printf "  └─ Endpoint: %s\n" "$endpoint" >> "$REPORT_FILE_TXT"
            printf "  └─ Version: %s\n" "$version" >> "$REPORT_FILE_TXT"
            printf "  └─ HTTP Code: %s\n\n" "$HTTP_CODE" >> "$REPORT_FILE_TXT"
        fi
        
        # Add to JSON report (append to temporary file since we're in a subshell)
        if [ "$GENERATE_JSON" = true ]; then
            TEMP_JSON="/tmp/endpoint_check_$$.json"
            if [ ! -f "$TEMP_JSON" ]; then
                echo "[]" > "$TEMP_JSON"
            fi
            
            # Escape quotes in capability_type and endpoint for JSON
            capability_escaped=$(echo "$capability_type" | sed 's/"/\\"/g')
            endpoint_escaped=$(echo "$endpoint" | sed 's/"/\\"/g')
            version_escaped=$(echo "$version" | sed 's/"/\\"/g')
            
            # Create JSON entry
            ENTRY=$(cat <<EOF
{
  "capability_type": "$capability_escaped",
  "endpoint": "$endpoint_escaped",
  "version": "$version_escaped",
  "status": "$STATUS",
  "http_code": "$HTTP_CODE"
}
EOF
)
            # Append to array in temp file
            jq ". += [$ENTRY]" "$TEMP_JSON" > "${TEMP_JSON}.tmp" && mv "${TEMP_JSON}.tmp" "$TEMP_JSON"
        fi
        
        COUNTER=$((COUNTER + 1))
    done
    
    # Finalise JSON report
    if [ "$GENERATE_JSON" = true ]; then
        TEMP_JSON="/tmp/endpoint_check_$$.json"
        if [ -f "$TEMP_JSON" ]; then
            # Create final JSON structure
            cat > "$REPORT_FILE_JSON" <<EOF
{
  "generated": "$(date -Iseconds)",
  "api_source": "$API_URL",
  "node_endpoint": "$NODE_ENDPOINT",
  "capabilities": $(cat "$TEMP_JSON")
}
EOF
            rm -f "$TEMP_JSON"
        fi
    fi
else
    # Fallback: manual parsing without jq (less reliable but works without dependencies)
    echo "Note: jq not found, using basic parsing. Install jq for better reliability."
    echo ""
    
    # Extract capabilities array content
    CAPABILITIES=$(echo "$JSON_DATA" | sed -n '/"capabilities"/,/]/p')
    
    # Initialise temp file for JSON
    if [ "$GENERATE_JSON" = true ]; then
        TEMP_JSON="/tmp/endpoint_check_$$.json"
        echo "[]" > "$TEMP_JSON"
    fi
    
    # Split by capability objects and process each
    echo "$CAPABILITIES" | grep -E '"capability_type"|"endpoint"|"version"' | while read -r line; do
        if echo "$line" | grep -q '"capability_type"'; then
            capability_type=$(echo "$line" | sed 's/.*"capability_type"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
            read -r line
            endpoint=$(echo "$line" | sed 's/.*"endpoint"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
            read -r line
            version=$(echo "$line" | sed 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
            
            printf "%-30s " "$capability_type"
            
            # Ping the endpoint
            HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 --head "$endpoint" 2>/dev/null)
            
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
            
            # Add to text report
            if [ "$GENERATE_TEXT" = true ]; then
                printf "%-30s %s\n" "$capability_type" "$STATUS" >> "$REPORT_FILE_TXT"
                printf "  └─ Endpoint: %s\n" "$endpoint" >> "$REPORT_FILE_TXT"
                printf "  └─ Version: %s\n" "$version" >> "$REPORT_FILE_TXT"
                printf "  └─ HTTP Code: %s\n\n" "$HTTP_CODE" >> "$REPORT_FILE_TXT"
            fi
            
            # Add to JSON report
            if [ "$GENERATE_JSON" = true ]; then
                # Escape quotes for JSON
                capability_escaped=$(echo "$capability_type" | sed 's/"/\\"/g')
                endpoint_escaped=$(echo "$endpoint" | sed 's/"/\\"/g')
                version_escaped=$(echo "$version" | sed 's/"/\\"/g')
                
                # Append to temp JSON file (manual JSON construction)
                CURRENT=$(cat "$TEMP_JSON")
                if [ "$CURRENT" = "[]" ]; then
                    cat > "$TEMP_JSON" <<EOF
[{
  "capability_type": "$capability_escaped",
  "endpoint": "$endpoint_escaped",
  "version": "$version_escaped",
  "status": "$STATUS",
  "http_code": "$HTTP_CODE"
}]
EOF
                else
                    # Remove closing bracket, add comma and new entry
                    sed -i '' '$ d' "$TEMP_JSON" 2>/dev/null || sed -i '$ d' "$TEMP_JSON"
                    cat >> "$TEMP_JSON" <<EOF
,{
  "capability_type": "$capability_escaped",
  "endpoint": "$endpoint_escaped",
  "version": "$version_escaped",
  "status": "$STATUS",
  "http_code": "$HTTP_CODE"
}]
EOF
                fi
            fi
        fi
    done
    
    # Finalise JSON report
    if [ "$GENERATE_JSON" = true ]; then
        TEMP_JSON="/tmp/endpoint_check_$$.json"
        if [ -f "$TEMP_JSON" ]; then
            cat > "$REPORT_FILE_JSON" <<EOF
{
  "generated": "$(date -Iseconds)",
  "api_source": "$API_URL",
  "node_endpoint": "$NODE_ENDPOINT",
  "capabilities": $(cat "$TEMP_JSON")
}
EOF
            rm -f "$TEMP_JSON"
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
