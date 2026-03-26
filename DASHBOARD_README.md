# EOSC Pilot Node Dashboard

## Naming Conventions

| File | Description |
| ----------------------------- | ----------------------------------------------------------------- |
| `node_registry_summary.json` | Central registry — fixed name, always at `data/` root |
| `endpoint_report.json` | Endpoint capability report (from `check_node_capabilities.sh`) |
| `catalogue_services_report.json` | Catalogue services report (from `check_catalogue_services.sh`) |
| `argo_uptime_report.json` | ARGO uptime report (from `check_service_uptime.sh`) |

Node folder names must exactly match the `name` field in `node_registry_summary.json`.

## Adding a New Node

When a new node has been added to the
[EOSC Node Registry](https://node-devel.eosc.grnet.gr/federation/eosc-beyond/home)
run `check_node_capabilities.sh` and it will appear in `node_registry_summary.json`.
A new directory (`data/NEW_NODE_NAME/`) is created and the `endpoint_report.json`
report is placed inside. Run `catalogue_services_report.json` and
`argo_uptime_report.json` against `NEW_NODE_NAME` and the generated reports will
be place in the same directory. Reports that are absent are handled gracefully:
the panel shows "No report file found".

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

```bash
mvn spring-boot:run

OR

java -jar target/pilot-node-dashboard-1.0.0-SNAPSHOT.jar
```

Then view the dashboard at `http://localhost:8080/index.html`.

## Navigation

- `index.html` — landing page showing all nodes with capability bars and
  report availability indicators; click any node card to go to its detail page
- `node.html#CESSDA` — detail view for a specific node; the hash fragment
  carries the node name so it survives server-side URL rewriting
- Use the node switcher dropdown on the detail page to move between nodes
- The breadcrumb at the top of the detail page returns to the landing page
