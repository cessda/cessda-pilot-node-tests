# CESSDA Endpoint Capabilities Checker

A Bash script for macOS that checks the availability of the Capabilities
listed in the CESSDA Node Endpoint and generates reports.

## Features

- Fetches endpoint data from the CESSDA Node Endpoint API
- Checks HTTP availability of each capability endpoint
- Generates timestamped reports in text and/or JSON format
- Colour-coded terminal output
- Command-line control over report format

## Requirements

- macOS (or Linux)
- `curl` (pre-installed on macOS)
- `jq` (recommended but optional)

### Installing jq (recommended)

```bash
brew install jq
```

The script will work without `jq` using basic grep/sed parsing, but `jq` provides more reliable JSON handling.

## Usage

```bash
chmod +x check_endpoint_capabilities.sh
./check_endpoints.sh [format]
```

### Format Options

- **No argument** (default): Generate both text and JSON reports

  ```bash
  ./check_endpoints.sh
  ```

- **text** or **txt**: Generate only text report

  ```bash
  ./check_endpoints.sh text
  ```

- **json**: Generate only JSON report

  ```bash
  ./check_endpoints.sh json
  ```

- **both**: Explicitly generate both formats

  ```bash
  ./check_endpoints.sh both
  ```

## Output Files

Reports are saved with timestamps in the current directory:

- Text report: `endpoint_report_YYYYMMDD_HHMMSS.txt`
- JSON report: `endpoint_report_YYYYMMDD_HHMMSS.json`

## Status Categories

The script categorizes endpoints into three status types:

- **Available**: HTTP status code 200-399 (shown in green)
- **Not found**: HTTP status code 404 (shown in yellow)
- **Not available**: Connection timeout or other HTTP errors (shown in red)

## Example Output

### Terminal Display

```text
======================================
CESSDA Endpoint Availability Report
======================================
Generated: Wed Feb 18 15:57:48 UTC 2026
API Source: https://node-endpoint-staging.beyond.cessda.eu/api/endpoint
======================================

Data retrieved successfully!

Node Endpoint: https://node-endpoint-staging.beyond.cessda.eu/

Checking capabilities...

Front Office                   Available
CDC API                        Available
OAI-PMH                        Available
Metrics API                    Not found
Legacy System                  Not available

======================================
Reports generated:
  Text: endpoint_report_20260218_155748.txt
  JSON: endpoint_report_20260218_155748.json
======================================
```

### Text Report Format

See `example_endpoint_report.txt` for a sample text report.

### JSON Report Format

See `example_endpoint_report.json` for a sample JSON report structure.

## API Endpoint

The script queries: `https://node-endpoint-staging.beyond.cessda.eu/api/endpoint`

## Error Handling

- If the API cannot be reached, the script will display an error and exit
- Individual endpoint failures are captured in the status field
- HTTP timeout is set to 10 seconds per endpoint

## Contributors

You can find the list of contributors in the [CONTRIBUTORS](CONTRIBUTORS.md)
file.

## License

See the [LICENSE](LICENSE.txt) file.

## CITING

See the [CITATION](CITATION.cff) file.
