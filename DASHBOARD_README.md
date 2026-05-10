# EOSC Pilot Node Dashboard

## Naming Conventions

| File | Description |
| ----------------------------- | ----------------------------------------------------------------- |
| `node_registry_summary.json` | Central registry — fixed name, always at `data/` root |
| `endpoint_report.json` | Endpoint capability report (from `check_node_capabilities.sh`) |
| `catalogue_services_report.json` | Catalogue services report (from `check_catalogue_services.sh`) |
| `argo_uptime_report.json` | ARGO uptime report (from `check_service_uptime.sh`) |

Node folder names must exactly match the `node_name` field in
`node_registry_summary.json`.

## Adding a New Node

When a new node has been added to the
[EOSC Node Registry](https://node-devel.eosc.grnet.gr/federation/eosc-beyond/home)
run `check_node_capabilities.sh` and it will appear in `node_registry_summary.json`.
A new directory (`data/NEW_NODE_NAME/`) is created and the `endpoint_report.json`
report is placed inside. Run `check_catalogue_services.sh` and `check_service_uptime.sh` against `NEW_NODE_NAME` and the generated reports will be placed
in the same directory. Reports that are absent are handled gracefully:

- homepage shows "No report" rows/chips
- node detail panels show:
  "Not available"
  "No services listed in this report";
  Raw JSON fallback panels;
  "No report files found for NODE" if all reports are absent.

## Updating Report from the UI

The landing page includes a "Run checks" menu that can trigger
the backend collection scripts asynchronously, via the REST API.

The frontend calls:

- `POST /api/run/node-capabilities`
- `POST /api/run/catalogue-services`
- `POST /api/run/service-uptime`

Each request returns a job ID. The dashboard polls
`/api/run/{jobId}/status` until the job completes and then
automatically refreshes the displayed data.

## Running Locally

```bash
mvn spring-boot:run
# or
python3 -m http.server 8080
# or
npx serve .
# or
java -jar target/pilot-node-dashboard-1.0.0-SNAPSHOT.jar
```

Then view the dashboard at `http://localhost:8080/index.html`.
The dashboard must be served over HTTP. Opening the HTML files
directly via `file://` will not work because browsers block local
JSON fetches.

## Navigation

- `index.html` — landing page showing all nodes with capability bars and
  report availability indicators; includes summary statistics:
  total nodes; healthy nodes; degraded/no data; capability uptime;
  available capabilities. Click any node card to go to its detail page.
- `node.html#CESSDA` — detail view for a specific node; the hash fragment
  carries the node name so it survives server-side URL rewriting
- Overview strip with aggregate metrics
- Endpoint connectivity cards
- Catalogue service table
- ARGO uptime visualisations
- Raw JSON fallback rendering
- Live hash-based navigation with hashchange support
- Use the node switcher dropdown on the detail page to move between nodes
- The breadcrumb at the top of the detail page returns to the landing page.
