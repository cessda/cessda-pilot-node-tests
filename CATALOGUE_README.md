# CESSDA Service Catalogue Checker

A Bash script for macOS that checks the availability of Exchange services
listed in the Sandbox/CESSDA Resource Catalogue and txt generates reports.

## Features

- Fetches service data from Catalogue API with Bearer token authentication
- Checks HTTP availability of each service's webpage
- Generates timestamped reports in text and/or JSON format
- Color-coded terminal output
- Command-line control over report format
- Handles services without defined webpages

## Requirements

- macOS (or Linux)
- `curl` (pre-installed on macOS)
- `jq` (recommended but optional)
- Valid Bearer token for API authentication

### Installing jq (recommended)

```bash
brew install jq
```

The script will work without `jq` using basic grep/sed parsing,
but `jq` provides more reliable JSON handling.

## Usage

```bash
chmod +x check_eosc_services.sh
./check_catalogue_services.sh [format] [bearer_token]
```

### Command Line Arguments

1. **Format** (optional, default: both)
   - `text` or `txt`: Generate only text report
   - `json`: Generate only JSON report
   - `both`: Generate both text and JSON reports

2. **Bearer Token** (optional, default: placeholder)
   - Your API authentication token
   - If not provided, uses placeholder `YOUR_BEARER_TOKEN_HERE`

### Usage Examples

**Using placeholder token (for testing structure):**

```bash
./check_eosc_services.sh
./check_eosc_services.sh json
./check_eosc_services.sh text
```

**Using actual Bearer token:**

```bash
./check_eosc_services.sh both "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
./check_eosc_services.sh json "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
./check_eosc_services.sh text "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
```

## Output Files

Reports are saved with timestamps in the current directory:

- Text report: `eosc_services_report_YYYYMMDD_HHMMSS.txt`
- JSON report: `eosc_services_report_YYYYMMDD_HHMMSS.json`

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
EOSC BEYOND Service Availability Report
======================================
Generated: Wed Feb 18 16:30:45 UTC 2026
API Source: https://providers.sandbox.eosc-beyond.eu/api/service/all...
======================================

Fetching service data...
Data retrieved successfully!

Total services found: 7

Checking service webpages...

CESSDA Data Catalogue                             Available
CESSDA Vocabulary Service                         Available
CESSDA European Language Social Science Thesaurus Available
Cessda example instrument 2                       Not available
CESSDA Data Management Expert Guide               Available
Cessda example instrument 1                       Not available
CESSDA Data Archiving Guide                       Available

======================================
Reports generated:
  Text: eosc_services_report_20260218_163045.txt
  JSON: eosc_services_report_20260218_163045.json
======================================
```

### Text Report Format

Each service entry includes:

- Service name and status
- Abbreviation (if available)
- Service ID
- Webpage URL (if defined)
- HTTP response code (if webpage was checked)

See `example_eosc_services_report.txt` for a complete sample.

### JSON Report Format

The JSON report includes:

- Metadata: generation timestamp, API source, total services count
- Array of services with: name, abbreviation, service_id, webpage, status, http_code

See `example_eosc_services_report.json` for a complete sample.

## API Endpoint

The script queries:

```text
https://providers.sandbox.eosc-beyond.eu/api/service/all?suspended=false&keyword=CESSDA&from=0&quantity=20&order=asc
```

**Query Parameters:**

- `suspended=false`: Only active services
- `keyword=CESSDA`: Filter by CESSDA keyword
- `from=0`: Start from first result
- `quantity=20`: Return up to 20 results
- `order=asc`: Ascending order

You can modify these parameters in the script as needed.

## Authentication

The script uses Bearer token authentication. To use your actual token:

1. **Via command line:**

   ```bash
   ./check_eosc_services.sh both "YOUR_ACTUAL_TOKEN"
   ```

2. **Edit the script:**
   - Open `check_eosc_services.sh`
   - Find the line: `BEARER_TOKEN="${2:-YOUR_BEARER_TOKEN_HERE}"`
   - Replace `YOUR_BEARER_TOKEN_HERE` with your actual token
   - Save and run without the token argument

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

### "ERROR: Failed to fetch data from API"

- Check your network connection
- Verify the Bearer token is valid
- Ensure the API endpoint is accessible

### "API returned an error response"

- Your Bearer token may be invalid or expired
- You may not have permission to access this endpoint
- Check the API response in the error message

### Services show "No webpage defined"

- This is normal for services that don't have a webpage field in the API response
- The service exists but has no associated webpage to check

## Contributors

You can find the list of contributors in the [CONTRIBUTORS](CONTRIBUTORS.md)
file.

## License

See the [LICENSE](LICENSE.txt) file.

## CITING

See the [CITATION](CITATION.cff) file.
