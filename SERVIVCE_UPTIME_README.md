# Service Uptime Monitor

A Bash script for monitoring and reporting on service uptime from the ARGO
Monitoring API. The script queries the ARGO API for a specified time period
and generates comprehensive reports showing availability, reliability, and
uptime statistics for all monitored endpoints.

## Features

- Comprehensive uptime reporting with availability and reliability metrics
- Dual output formats: human-readable text and structured JSON
- Colour-coded terminal output for quick status assessment
- Flexible date ranges with sensible defaults
- Input validation and error handling

## Requirements

- macOS (uses macOS-specific `date` commands)
- `curl` - for API requests
- `jq` - for JSON parsing
- `bc` - for calculations

### Installing Dependencies

```bash
# Install jq using Homebrew
brew install jq

# bc is usually pre-installed on macOS
```

## Installation

### Download the script

```bash
curl -O https://example.com/check_service_uptime.sh
```

### Make it executable

```bash
chmod +x check_service_uptime.sh
```

## Usage

```bash
./check_service_uptime.sh [API_KEY] [START_DATE] [END_DATE] [FORMAT]
```

### Arguments

| Argument | Required | Default | Description |
| ---------- | ---------- | --------- | ------------- |
| `API_KEY` | Yes | - | API key for authentication |
| `START_DATE` | No | 30 days ago | Start date in `YYYY-MM-DD` format |
| `END_DATE` | No | Today | End date in `YYYY-MM-DD` format |
| `FORMAT` | No | `both` | Output format: `text`, `json`, or `both` |

### Examples

#### Basic Usage (Last 30 Days)

```bash
./check_service_uptime.sh your-api-key-here
```

Generates reports for the last 30 days in both text and JSON formats.

#### Specific Date Range

```bash
./check_service_uptime.sh your-api-key-here 2026-02-01 2026-02-28
```

Generates reports for February 2026.

#### JSON Output Only

```bash
./check_service_uptime.sh your-api-key-here 2026-02-01 2026-02-28 json
```

Generates only the JSON report, useful for automated processing.

#### Text Output Only

```bash
./check_service_uptime.sh your-api-key-here 2026-02-01 2026-02-28 text
```

Generates only the human-readable text report.

#### Custom Start Date with Default End Date

```bash
./check_service_uptime.sh your-api-key-here 2026-01-01
```

Reports from 1st January 2026 to today.

## Output

### Console Output

The script provides colour-coded console output:

- 🟢 **Green** - Uptime ≥ 99% (excellent)
- 🟡 **Yellow** - Uptime 95-98% (good)
- 🔴 **Red** - Uptime < 95% (requires attention)

### Generated Files

The script generates timestamped report files in the current directory:

#### Text Report: `argo_uptime_report_YYYYMMDD_HHMMSS.txt`

Human-readable report with:

- Report metadata (generation time, period, API source)
- Project name
- Per-endpoint statistics including:
  - Endpoint name and type
  - Uptime percentage
  - Average availability
  - Average reliability
  - Number of days monitored

Example:

```text
==========================================
ARGO Monitoring - Uptime Report
==========================================
Generated: Mon 02 Mar 2026 10:30:00 GMT
Period: 2026-02-01T00:00:00Z to 2026-02-28T23:59:59Z
==========================================

Project: CESSDA

==========================================
Endpoint Uptime Statistics
==========================================

Endpoint: Data Catalogue
  Type: SERVICEGROUPS
  Uptime: 100.00%
  Availability: 100.00%
  Reliability: 100.00%
  Days Monitored: 28
```

#### JSON Report: `argo_uptime_report_YYYYMMDD_HHMMSS.json`

Structured data for programmatic access:

```json
{
  "generated": "2026-03-02T10:30:00+00:00",
  "api_source": "https://api.devel.mon.argo.grnet.gr/api/v2/results/CORE/SERVICEGROUPS?start_time=2026-02-01T00:00:00Z&end_time=2026-02-28T23:59:59Z",
  "period": {
    "start": "2026-02-01T00:00:00Z",
    "end": "2026-02-28T23:59:59Z"
  },
  "project": "CESSDA",
  "endpoints": [
    {
      "name": "Data Catalogue",
      "type": "SERVICEGROUPS",
      "uptime_percentage": 100.00,
      "average_availability": 100.00,
      "average_reliability": 100.00,
      "days_monitored": 28
    }
  ]
}
```

## Metrics Explained

### Uptime Percentage

The proportion of time the service was operational, calculated as the average of daily uptime values across the monitoring period.

**Formula:** `(Sum of daily uptime values / Number of days) × 100`

### Availability

The percentage of time the service was reachable and responding, averaged across all monitoring days.

### Reliability

The percentage of time the service provided correct and consistent responses, averaged across all monitoring days.

### Days Monitored

The total number of days within the specified period for which monitoring data is available.

## Error Handling

The script includes comprehensive error handling:

- Validates date formats (must be `YYYY-MM-DD`)
- Ensures start date is before end date
- Checks for required dependencies (`jq`, `bc`)
- Validates API responses (HTTP status codes)
- Handles missing or empty data gracefully

### Common Errors

#### "jq is required but not installed"

```bash
brew install jq
```

**"Invalid date format"**
Ensure dates are in `YYYY-MM-DD` format (e.g., `2026-02-01`)

**"Start date must be before end date"**
Check that your start date precedes your end date
### "API request failed with HTTP status code XXX"

- `401`: Invalid or missing API key
- `404`: Resource not found
- `500`: Server error - try again later

## API Details

The script queries the ARGO Monitoring API:

**Endpoint:** `https://api.devel.mon.argo.grnet.gr/api/v2/results/CORE/SERVICEGROUPS`

**Time Format:** Timestamps are automatically formatted as:

- Start time: `YYYY-MM-DDT00:00:00Z`
- End time: `YYYY-MM-DDT23:59:59Z`

You don't need to specify the time component; it's handled automatically by the script.

## Integration Examples

### Automated Daily Reports

```bash
#!/bin/bash
# Run daily at 9 AM to generate weekly reports
0 9 * * * /path/to/check_service_uptime.sh $API_KEY $(date -v-7d +\%Y-\%m-\%d) $(date +\%Y-\%m-\%d) json >> /var/log/uptime-reports.log 2>&1
```

### Processing JSON Output

```bash
# Extract endpoints with uptime < 99%
./check_service_uptime.sh $API_KEY 2026-02-01 2026-02-28 json
jq '.endpoints[] | select(.uptime_percentage < 99)' argo_uptime_report_*.json
```

### Alert on Low Uptime

```bash
#!/bin/bash
./check_service_uptime.sh $API_KEY "" "" json > /dev/null
LATEST_REPORT=$(ls -t argo_uptime_report_*.json | head -1)
LOW_UPTIME=$(jq '.endpoints[] | select(.uptime_percentage < 99) | .name' "$LATEST_REPORT")

if [ -n "$LOW_UPTIME" ]; then
    echo "Alert: Services with uptime < 99%:"
    echo "$LOW_UPTIME"
    # Send notification
fi
```

## Security Considerations

### API Key Protection

**Do not hardcode API keys in scripts.** Use one of these methods:

### Environment variable

```bash
export ARGO_API_KEY="your-api-key-here"
./check_service_uptime.sh $ARGO_API_KEY
```

### Configuration file (with restricted permissions)

```bash
# Create config file
echo "ARGO_API_KEY=your-api-key-here" > ~/.argo_config
chmod 600 ~/.argo_config

# Use in script
source ~/.argo_config
./check_service_uptime.sh $ARGO_API_KEY
```

### Command-line argument (secure terminal only)

```bash
./check_service_uptime.sh your-api-key-here
```

## Troubleshooting

### Script doesn't run

```bash
# Ensure script is executable
chmod +x check_service_uptime.sh

# Check shebang line
head -1 check_service_uptime.sh
# Should output: #!/bin/bash
```

### Date parsing errors

The script uses macOS-specific date commands. On Linux, you'll need to adapt the date calculations:

```bash
# macOS (current):
date -v-30d "+%Y-%m-%d"

# Linux equivalent:
date -d "30 days ago" "+%Y-%m-%d"
```

### Empty or missing data

- Verify the API endpoint is accessible
- Check your API key is valid and has appropriate permissions
- Ensure the date range contains monitoring data

## Contributing

Contributions are welcome! Please ensure:

- Code follows existing style conventions
- Error handling is comprehensive
- Documentation is updated accordingly

## Support

For issues related to:

- **Script functionality**: Check this README or review error messages
- **ARGO API**: Consult the [ARGO Monitoring API documentation](https://argoeu.github.io/argo-web-api/)
- **Missing data**: Verify with the Monitoring Team @ GRNET
