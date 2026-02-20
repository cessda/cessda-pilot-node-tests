#!/bin/bash

# Quick test script to check the Resource Catalogue API endpoint
# Usage: ./test_curl.sh [your_bearer_token]

BEARER_TOKEN="${1:-YOUR_BEARER_TOKEN_HERE}"
API_URL="https://providers.sandbox.eosc-beyond.eu/api/service/all?suspended=false&keyword=CESSDA&from=0&quantity=20&order=asc"

echo "======================================"
echo "EOSC API Curl Test"
echo "======================================"
echo "URL: $API_URL"
echo "Token: ${BEARER_TOKEN:0:20}... (truncated)"
echo ""
echo "Executing curl command..."
echo ""

# Show the command that will be executed
echo "Command:"
echo "curl -v \\"
echo "  --header 'Content-Type: application/json' \\"
echo "  --header 'Authorization: Bearer [TOKEN]' \\"
echo "  --header 'Accept: application/json' \\"
echo "  '$API_URL'"
echo ""
echo "======================================"
echo ""

# Execute curl
curl -v \
  --header 'Content-Type: application/json' \
  --header "Authorization: Bearer $BEARER_TOKEN" \
  --header 'Accept: application/json' \
  "$API_URL"

echo ""
echo ""
echo "======================================"
echo "Test complete"
echo "======================================"
