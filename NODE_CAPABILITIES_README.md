# Endpoint Capabilities Checker

## Overview

The `check_endpoint_capabilities.sh` script queries the **EOSC Beyond Node Registry**
to automatically discover all registered nodes and test their endpoint
capabilities. This eliminates the need to hardcode individual node endpoint
URLs and enables comprehensive monitoring across the entire federation.

### Node Registry Integration

- Queries Node Registry API to discover all nodes dynamically

### Multi-Node Support

- Tests all nodes registered in the EOSC Beyond federation
- Generates separate reports for each node
- Creates a summary report across all nodes

### File Naming

- Report filenames include the node name for easy identification
- Example: `endpoint_report_CESSDA_20260225_143000.txt`
- Node names are sanitised (special characters replaced with underscores)

### Summary Report

- Generates cross-node summary reports
- Provides overview of all tested nodes in single location

## Node Registry API

- Endpoint: `https://node-devel.eosc.grnet.gr/federation-backend/tenants/eosc-beyond/nodes`
- Authentication via API Key in header: `X-Api-Key: API_KEY`
- Response Format:

```json
[
  {
    "id": "6",
    "name": "CESSDA",
    "logo": "https://idp.cessda.eu/static/images/CESSDA_logo.svg",
    "pid": "21.T15999/CESSDA",
    "legal_entity": {
      "name": "Consortium of European Social Science Data Archives",
      "ror_id": "https://ror.org/02wg9xc72"
    },
    "node_endpoint": "https://node-endpoint-staging.beyond.cessda.eu/api/endpoint"
  },
  {
    "id": "4",
    "name": "EOSC-Beyond",
    "logo": "https://core-proxy.sandbox.eosc-beyond.eu/static/images/logo.png",
    "pid": "21.T15999/EOSC-BEYOND",
    "legal_entity": {
      "name": "EGI",
      "ror_id": "https://ror.org/052jj4m32"
    },
    "node_endpoint": "https://providers.sandbox.eosc-beyond.eu/node/endpoint"
  },
  {
    "id": "3",
    "name": "NI4OS-EUROPE",
    "logo": "https://ni4os.eu/wp-content/uploads/2019/10/NI4OS_logo_title-e1570180082953.jpg",
    "pid": "21.T15999/NI4OS-EUROPE",
    "legal_entity": {
      "name": "National Infrastructures for Research and Technology - GRNET S.A",
      "ror_id": "https://ror.org/05tcasm11"
    },
    "node_endpoint": "https://endpoint.mrezhi.net/api/endpoint"
  }
]
```

## Usage

### Basic Usage

```bash
# Test all nodes with both text and JSON reports (default)
./check_endpoint_capabilities.sh API_KEY

# Generate only text reports
./check_endpoint_capabilities.sh API_KEY text

# Generate only JSON reports
./check_endpoint_capabilities.sh API_KEY json

# Generate both formats
./check_endpoint_capabilities.sh API_KEY both
```

### Prerequisites

- `curl` - for HTTP requests
- `jq` (recommended) - for reliable JSON parsing
- `bash` 4.0+ - for script execution

### Installation of jq (if needed)

```bash
# Ubuntu/Debian
sudo apt-get install jq

# macOS
brew install jq

# CentOS/RHEL
sudo yum install jq
```

## Output Files

### Per-Node Reports

For each node discovered in the registry, the script generates:

**Text Report:** `endpoint_report_<NODE_NAME>_<TIMESTAMP>.txt`

- Human-readable format
- Lists all capabilities with status
- Includes endpoint URLs, versions, and HTTP codes

**JSON Report:** `endpoint_report_<NODE_NAME>_<TIMESTAMP>.json`

- Machine-readable format
- Structured data for automated processing
- Can be imported into monitoring systems

**Example filenames:**

```text
endpoint_report_CESSDA_20260225_143000.txt
endpoint_report_CESSDA_20260225_143000.json
endpoint_report_EOSC-Beyond_20260225_143000.txt
endpoint_report_EOSC-Beyond_20260225_143000.json
endpoint_report_NI4OS-EUROPE_20260225_143000.txt
endpoint_report_NI4OS-EUROPE_20260225_143000.json
```

### Summary Reports

**Text Summary:** `node_registry_summary_<TIMESTAMP>.txt`

- Overview of all tested nodes
- Quick reference for total capabilities per node

**JSON Summary:** `node_registry_summary_<TIMESTAMP>.json`

- Structured summary data
- References to individual node report files
- Useful for dashboards and monitoring

## Report Structure

### Individual Node Text Report

```text
==========================================
Node: CESSDA
==========================================
Generated: Tue Feb 25 14:30:00 UTC 2026
Node ID: 6
Node PID: 21.T15999/CESSDA
Node Endpoint: https://node-endpoint-staging.beyond.cessda.eu/api/endpoint
Legal Entity: Consortium of European Social Science Data Archives
Legal Entity ROR: https://ror.org/02wg9xc72
Logo: https://idp.cessda.eu/static/images/CESSDA_logo.svg
==========================================

CESSDA Data Catalogue              Available (HTTP 200)
  └─ Endpoint: https://datacatalogue.cessda.eu/api/DataSets/v2
  └─ Version: 2.0

CESSDA Vocabulary Service          Available (HTTP 200)
  └─ Endpoint: https://vocabularies.cessda.eu/v2
  └─ Version: 2.0

...
```

### Individual Node JSON Report

```json
{
  "generated": "2026-02-25T14:30:00+00:00",
  "node_name": "CESSDA",
  "node_id": "6",
  "node_pid": "21.T15999/CESSDA",
  "node_endpoint": "https://node-endpoint-staging.beyond.cessda.eu/api/endpoint",
  "legal_entity": {
    "name": "Consortium of European Social Science Data Archives",
    "ror_id": "https://ror.org/02wg9xc72"
  },
  "capabilities": [
    {
      "capability_type": "CESSDA Data Catalogue",
      "endpoint": "https://datacatalogue.cessda.eu/api/DataSets/v2",
      "version": "2.0",
      "status": "Available",
      "http_code": "200"
    },
    {
      "capability_type": "CESSDA Vocabulary Service",
      "endpoint": "https://vocabularies.cessda.eu/v2",
      "version": "2.0",
      "status": "Available",
      "http_code": "200"
    }
  ]
}
```

### Summary JSON Report

```json
{
  "generated": "2026-02-25T14:30:00+00:00",
  "registry_source": "https://node-devel.eosc.grnet.gr/federation-backend/tenants/eosc-beyond/nodes",
  "nodes": [
    {
      "name": "CESSDA",
      "endpoint": "https://node-endpoint-staging.beyond.cessda.eu/api/endpoint",
      "total_capabilities": 5,
      "report_file": "endpoint_report_CESSDA_20260225_143000.json"
    },
    {
      "name": "EOSC-Beyond",
      "endpoint": "https://providers.sandbox.eosc-beyond.eu/node/endpoint",
      "total_capabilities": 8,
      "report_file": "endpoint_report_EOSC-Beyond_20260225_143000.json"
    },
    {
      "name": "NI4OS-EUROPE",
      "endpoint": "https://endpoint.mrezhi.net/api/endpoint",
      "total_capabilities": 6,
      "report_file": "endpoint_report_NI4OS-EUROPE_20260225_143000.json"
    }
  ]
}
```

## Status Indicators

The script reports three status levels:

| Status | Colour | HTTP Code | Description |
|--------|-------|-----------|-------------|
| **Available** | Green | 200-399 | Service is accessible and responding |
| **Not found** | Yellow | 404 | Endpoint exists but resource not found |
| **Not available** | Red | 000, 400+ | Service is unreachable or error |

## Script Workflow

```text
1. Query Node Registry
   └─> Fetch list of all registered nodes

2. For each node:
   ├─> Extract node metadata (name, ID, PID, endpoint, legal entity)
   ├─> Query node's capabilities endpoint
   ├─> For each capability:
   │   ├─> Send HTTP HEAD request to endpoint
   │   ├─> Record HTTP status code
   │   └─> Determine availability status
   ├─> Generate node-specific reports
   └─> Add to summary

3. Generate summary reports
   └─> Aggregate results across all nodes
```

## Error Handling

The script handles various error conditions:

- **Registry unreachable:** Exits with error message
- **Node endpoint unreachable:** Logs error in node report, continues with other nodes
- **Invalid JSON:** Falls back to basic parsing if jq unavailable
- **Timeout:** 10-second timeout per endpoint check

## Integration with Monitoring Systems

### Prometheus Integration

The JSON output can be scraped by Prometheus using a custom exporter:

```python
# Example: Convert JSON to Prometheus metrics
import json

with open('node_registry_summary_<timestamp>.json') as f:
    data = json.load(f)

for node in data['nodes']:
    with open(node['report_file']) as nf:
        node_data = json.load(nf)
        for cap in node_data['capabilities']:
            status_value = 1 if cap['status'] == 'Available' else 0
            print(f'endpoint_status{{node="{node["name"]}",capability="{cap["capability_type"]}"}} {status_value}')
```

### Grafana Dashboard

Use the JSON reports to create visualizations:

- Heatmap of endpoint availability across nodes
- Time series of uptime percentages
- Alerts for unavailable services

### Cron Job Setup

Run the script periodically:

```bash
# Add to crontab (every 15 minutes)
*/15 * * * * /path/to/check_endpoint_capabilities.sh json > /var/log/endpoint_check.log 2>&1
```

## Automation and CI/CD

### GitHub Actions Example

```yaml
name: Endpoint Health Check
on:
  schedule:
    - cron: '0 */6 * * *'  # Every 6 hours
  workflow_dispatch:

jobs:
  check-endpoints:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Install jq
        run: sudo apt-get install -y jq
      - name: Run endpoint check
        run: ./check_endpoint_capabilities.sh json
      - name: Upload reports
        uses: actions/upload-artifact@v3
        with:
          name: endpoint-reports
          path: |
            endpoint_report_*.json
            node_registry_summary_*.json
```

## Troubleshooting

### Issue: "jq not found" warning

**Solution:** Install jq for better reliability, or continue with basic parsing

### Issue: All endpoints show "Not available"

**Possible causes:**

- Network connectivity issues
- Firewall blocking outbound requests
- Node endpoints are down
**Solution:** Check network connectivity and node status

### Issue: Empty capability lists

**Possible causes:**

- Node endpoint returns invalid JSON
- Node has no capabilities registered
**Solution:** Check node endpoint manually with curl

### Issue: Script hangs

**Possible cause:** Slow endpoint responses
**Solution:** Script has 10-second timeout per endpoint; wait for completion

## Best Practices

1. **Run regularly:** Schedule hourly or daily checks via cron
2. **Archive reports:** Keep historical data for trend analysis
3. **Monitor trends:** Look for patterns in availability
4. **Alert on failures:** Set up notifications for critical endpoints
5. **Document incidents:** Track when services go down and recovery time

## Future Enhancements

Potential improvements for future versions:

1. **Historical tracking:** Store results in database
2. **Trend analysis:** Calculate uptime percentages over time (or use [check_service_uptime.sh](check_service_uptime.sh))
3. **Alerting:** Email/Slack notifications for failures
4. **Response time tracking:** Measure and record latency
5. **Service-level agreement (SLA) monitoring:** Track against SLA targets
6. **Interactive dashboard:** Web UI for viewing results
