# EOSC Pilot Node Dashboard

## File Structure

```text
src/main/dashboard/
├── index.html                              ← Landing page (all-nodes summary)
├── node.html                               ← Node detail page (shared, URL-driven)
├── logo-eosc-beyond-horizontal-fc.png      ← EOSC Beyond logo
├── README.md
└── data/
    ├── node_registry_summary.json          ← Master registry: drives node list & switcher
    ├── CESSDA/
    │   ├── endpoint_report.json
    │   ├── catalogue_services_report.json
    │   └── argo_uptime_report.json
    ├── EOSC-Beyond/
    │   ├── endpoint_report.json
    │   ├── catalogue_services_report.json
    │   └── argo_uptime_report.json
    └── NI4OS-EUROPE/
        ├── endpoint_report.json
        ├── catalogue_services_report.json
        └── argo_uptime_report.json
```

## Naming Conventions

| File | Description |
|---|---|
| `node_registry_summary.json` | Central registry — fixed name, always at `data/` root |
| `endpoint_report.json` | Endpoint capability report (from `check_node_capabilities.sh`) |
| `catalogue_services_report.json` | Catalogue services report (from `check_catalogue_services.sh`) |
| `argo_uptime_report.json` | ARGO uptime report (from `check_service_uptime.sh`) |

Node folder names must exactly match the `name` field in `node_registry_summary.json`.

## Adding a New Node

1. Add an entry to `data/node_registry_summary.json`:

```json
{
  "name": "MY-NODE",
  "endpoint": "https://...",
  "total_capabilities": 0,
  "available_capabilities": 0,
  "report_file": "endpoint_report.json"
}
```

2. Create `data/MY-NODE/` and place any available reports inside.
   Reports that are absent are handled gracefully — the panel shows "No report file found".

## Updating Report Data

The simplest way to refresh the dashboard data is to run the scripts with the
`dashboard_dir` argument pointing at `src/main/dashboard/data/`. Each script
writes directly to the appropriate node subdirectory using the canonical
filename, so no manual file copying or renaming is needed. For example, from
`src/main/scripts/`:

```bash
./check_node_capabilities.sh YOUR_API_KEY json
./check_catalogue_services.sh CESSDA json
./check_service_uptime.sh CESSDA YOUR_ARGO_KEY
```

## Running Locally

Browsers block `fetch()` requests when HTML files are opened directly from
disk (`file://` URLs). If you open `index.html` directly, both pages will
display a clear error message explaining this. The dashboard must be served
over HTTP.

Run any one of the following commands from the `src/main/dashboard/` directory,
then open the URL shown in your browser.

```bash
# Node.js (default port 3000)
npx serve .
```

```bash
# Python 3 (no additional dependencies)
python3 -m http.server 8080
```

```bash
# PHP
php -S localhost:8080
```

## Navigation

- `index.html` — landing page showing all nodes with capability bars and
  report availability indicators; click any node card to go to its detail page
- `node.html#CESSDA` — detail view for a specific node; the hash fragment
  carries the node name so it survives server-side URL rewriting
- Use the node switcher dropdown on the detail page to move between nodes
- The breadcrumb at the top of the detail page returns to the landing page
