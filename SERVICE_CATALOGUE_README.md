# Service Catalogue Checker

A Bash script for macOS that checks the availability of the Exchange services
listed in the Node's Service Catalogue and generates reports.
The script automatically generates a fresh access token from your refresh
token on every run, so you don't need to worry about token expiration.

## Features

- **Automatic token refresh**: Generates new access token from refresh token on each run
- Fetches service data from Node's Service Catalogue API with Bearer token authentication
- Checks HTTP availability of each service's webpage
- Generates timestamped reports in text and/or JSON format
- Colour-coded terminal output
- Command-line control over report format
- Handles services without defined webpages
- Verbose debugging output for troubleshooting

## Requirements

- macOS (or Linux)
- `curl` (pre-installed on macOS)
- `jq` (recommended but optional)
- Valid Bearer token for API authentication

### Installing jq (recommended)

```bash
brew install jq
```

The script will work without `jq` using basic grep/sed parsing, but `jq` provides more reliable JSON handling.

## Usage

```bash
chmod +x check_catalogue_services.sh
./check_catalogue_services.sh [format] [refresh_token]
```

### Command Line Arguments

1. **Format** (optional, default: both)
   - `text` or `txt`: Generate only text report
   - `json`: Generate only JSON report
   - `both`: Generate both text and JSON reports

2. **Refresh Token** (required for actual use)
   - Your refresh token that will be used to generate a fresh access token
   - Access tokens expire after 1 hour, but refresh tokens are long-lived
   - The script generates a new access token on every run
   - If not provided, uses placeholder `YOUR_REFRESH_TOKEN_HERE`

### Usage Examples

**Using placeholder token (for testing structure only):**

```bash
./check_catalogue_services.sh
./check_catalogue_services.sh json
./check_catalogue_services.sh text
```

**Using actual refresh token (recommended):**

```bash
./check_catalogue_services.sh both "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
./check_catalogue_services.sh json "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
./check_catalogue_services.sh text "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
```

### How Token Refresh Works

The script performs these steps automatically:

1. **Token Refresh** (Step 1):
   - Sends your refresh token to the token endpoint
   - Receives a new access token (valid for 1 hour)
   - Validates the access token was received successfully

2. **API Call** (Step 2):
   - Uses the fresh access token to call the services API
   - Retrieves the list of services
   - Checks each service's webpage availability

This ensures you always have a valid access token, even if you run the script multiple times or after long delays.

## Output Files

Reports are saved with timestamps in the current directory:

- Text report: `node_services_report_YYYYMMDD_HHMMSS.txt`
- JSON report: `node_services_report_YYYYMMDD_HHMMSS.json`

## Status Categories

The script categorizes service webpages into four status types:

- **Available**: HTTP status code 200-399 (shown in green)
- **Not found**: HTTP status code 404 (shown in yellow)
- **Not available**: Connection timeout or other HTTP errors (shown in red)
- **No webpage defined**: Service entry has no webpage field (shown in yellow)

## Example Output

### Terminal Display

```text
======================================
Service Catalogue Service Availability Report
======================================
Generated: Wed Feb 18 16:30:45 UTC 2026
API Source: https://providers.sandbox.eosc-beyond.eu/api/service/all...
======================================

Step 1: Generating new access token from refresh token...

Requesting new access token...

=== TOKEN REFRESH VERBOSE OUTPUT ===
[curl verbose output showing token request]
====================================

Token response (first 300 chars):
{"access_token":"eyJhbGc...","expires_in":3600,...}

✓ Access token generated successfully
Token (first 50 chars): eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWI...

Step 2: Fetching service data from API...

=== API CALL VERBOSE OUTPUT ===
[curl verbose output showing API request]
===============================

Data retrieved successfully!

=== JSON RESPONSE (first 500 characters) ===
{"total":7,"from":0,"to":7,"results":[...
============================================

Total services found: 7

Checking service webpages...

CESSDA Data Catalogue                             Available
CESSDA Vocabulary Service                         Available
CESSDA European Language Social Science Thesaurus Available
CESSDA Data Management Expert Guide               Available
CESSDA Data Archiving Guide                       Available

======================================
Reports generated:
  Text: node_services_report_20260218_163045.txt
  JSON: node_services_report_20260218_163045.json
======================================
```

### Text Report Format

Each service entry includes:

- Service name and status
- Abbreviation (if available)
- Service ID
- Webpage URL (if defined)
- HTTP response code (if webpage was checked)

See `example_node_services_report.txt` for a complete sample.

### JSON Report Format

The JSON report includes:

- Metadata: generation timestamp, API source, total services count
- Array of services with: name, abbreviation, service_id, webpage, status, http_code

See `example_node_services_report.json` for a complete sample.

## API Endpoint

The script queries:

```bash
https://providers.sandbox.eosc-beyond.eu/api/service/all?suspended=false&keyword=NODE_NAME&from=0&quantity=20&order=asc
```

**Query Parameters:**

- `suspended=false`: Only active services
- `keyword=NODE_NAME`: Filter by NODE_NAME keyword
- `from=0`: Start from first result
- `quantity=20`: Return up to 20 results
- `order=asc`: Ascending order

You can modify these parameters in the script as needed.

## Authentication

The script uses a two-step authentication process:

### Step 1: Token Refresh

Refresh tokens are long-lived credentials that can generate new access tokens. The script automatically refreshes your access token on every run using this endpoint:

```bash
POST https://core-proxy.sandbox.eosc-beyond.eu/auth/realms/core/protocol/openid-connect/token
Content-Type: application/x-www-form-urlencoded
Body: grant_type=refresh_token&refresh_token=YOUR_REFRESH_TOKEN
```

### Step 2: API Access

The fresh access token (valid for 1 hour) is then used to authenticate with the services API:

```bash
GET https://providers.sandbox.eosc-beyond.eu/api/service/all...
Authorization: Bearer ACCESS_TOKEN
```

### Getting Your Refresh Token

You can obtain a refresh token from the CESSDA Service Catalogue authentication system. The refresh token should be kept secure as it provides long-term access to your account.

### Manual Token Refresh (for testing)

To manually test token refresh:

```bash
curl -X POST \
  --header 'Content-Type: application/x-www-form-urlencoded' \
  --data 'grant_type=refresh_token&refresh_token=YOUR_REFRESH_TOKEN' \
  'https://core-proxy.sandbox.eosc-beyond.eu/auth/realms/core/protocol/openid-connect/token' \
  | python -m json.tool
```

This will return a JSON response containing:

- `access_token`: The new access token (use within 1 hour)
- `expires_in`: Token lifetime in seconds (typically 3600 = 1 hour)
- `refresh_token`: A new refresh token (optional)
- Other OAuth metadata

## Error Handling

- If the API cannot be reached, the script will display an error and exit
- Invalid Bearer tokens will result in API error responses
- Individual webpage failures are captured in the status field
- HTTP timeout is set to 10 seconds per webpage
- Services without defined webpages are handled gracefully

## Data Extracted

From each service in the API response, the script extracts:

- `name`: Service name
- `webpage`: Service webpage URL
- `id`: Service identifier
- `abbreviation`: Service abbreviation (if available)

## Troubleshooting

### Debug Mode

The script runs with verbose curl output enabled, showing all HTTP headers and connection details. This helps diagnose authentication and connection issues.

**What you'll see:**

- Full HTTP request headers
- Server response headers
- HTTP status code
- Connection details
- First 500 characters of JSON response

### Quick API Test

Use the included `test_curl.sh` script to quickly test your token refresh and API connection:

```bash
chmod +x test_curl.sh
./test_curl.sh "your_refresh_token_here"
```

This will:

1. Refresh your access token
2. Show you the token response
3. Use the new access token to call the API
4. Display the full response

This is useful for verifying your refresh token works before running the full checker.

### Common Issues

#### "ERROR: Failed to refresh access token"

- Your refresh token is invalid, expired, or malformed
- Check the token endpoint URL is correct
- Verify the token refresh verbose output for HTTP status codes
- Look for HTTP 401 (unauthorized) or 400 (bad request)

#### "ERROR: Failed to extract access token from response"

- The token refresh succeeded but the response format is unexpected
- Check the token response output shown in the script
- Verify the response contains an `access_token` field
- The refresh token might not have the necessary scopes/permissions

#### "ERROR: Failed to fetch data from API"

- Check your network connection
- Verify the Bearer token is valid
- Ensure the API endpoint is accessible

#### "ERROR: Response is not valid JSON"

- Your Bearer token is likely invalid, expired, or malformed
- The API might be returning an HTML error page (check verbose output)
- Look at the HTTP status code in the verbose output (should be 200)
- Try the test_curl.sh script to see the raw response

#### "WARNING: API response contains error field"

- This might be a false positive if "error" is just a field name
- Check the JSON response shown in the output to verify
- The script will continue processing unless it's a critical error

### Checking Your Refresh Token

Your refresh token should:

- Be a valid OAuth refresh token from  Service Catalogue
- Not be expired (refresh tokens have long lifetimes but can expire)
- Have appropriate permissions/scopes for the services API
- Be properly formatted (no extra spaces or quotes)

To test your refresh token manually:

```bash
curl -X POST \
  --header 'Content-Type: application/x-www-form-urlencoded' \
  --data "grant_type=refresh_token&refresh_token=YOUR_REFRESH_TOKEN" \
  'https://core-proxy.sandbox.eosc-beyond.eu/auth/realms/core/protocol/openid-connect/token'
```

Look for:

- HTTP status 200 (success) - You'll receive an `access_token` in the response
- HTTP status 400 (bad request) - Refresh token is malformed or invalid
- HTTP status 401 (unauthorized) - Refresh token is expired or revoked

### Why Refresh Tokens?

Access tokens expire after 1 hour for security reasons. Refresh tokens solve this by:

- Being long-lived (days, weeks, or months)
- Generating fresh access tokens on demand
- Eliminating the need to re-authenticate every hour
- Allowing the script to be run at any time without manual token management

### Debug Output Files

The script creates temporary files that can help with debugging:

- `/tmp/token_refresh_$$.log` - Token refresh verbose output (connection details)
- `/tmp/token_response_$$.json` - Raw token response with access_token
- `/tmp/curl_output_$$.log` - API call verbose output (connection details)
- `/tmp/curl_response_$$.json` - Raw JSON response from services API

These files persist after the script runs and can be examined for troubleshooting.

**Example: Check the access token you received:**

```bash
cat /tmp/token_response_*.json | python -m json.tool
```

**Example: Check the API response:**

```bash
cat /tmp/curl_response_*.json | python -m json.tool | head -50
```
