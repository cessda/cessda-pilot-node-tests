# Pilot Node Tests

This repository contains the scripts for testing some of the functionality of
an EOSC Beyond Pilot Node and a dashboard to display the outputs.

See [METRICS](METRICS.md) for details of which script to use for which metric.

## Repository Structure

```text
src/main/java/eu/cessda/pilotnode/
├── PilotNodeDashboardApplication.java   ← @EnableScheduling, @EnableConfigurationProperties
├── DashboardDataController.java         ← serves /api/data/** (unchanged)
├── WebMvcConfig.java                    ← static resource config (unchanged)
├── config/
│   └── CollectorProperties.java        ← typed @ConfigurationProperties binding
├── collector/
│   ├── CollectorException.java         ← unchecked exception for API failures
│   ├── NodeCapabilitiesCollector.java  ← replaces check_node_capabilities.sh
│   ├── ExchangeServicesCollector.java  ← replaces check_exchange_services.sh
│   └── ArgoUptimeCollector.java        ← replaces check_service_uptime.sh
└── model/
    ├── LegalEntity.java
    ├── NodeRegistryEntry.java          ← registry API response element
    ├── Capability.java
    ├── EndpointReport.java             ← → endpoint_report.json
    ├── NodeSummary.java
    ├── NodeRegistrySummary.java        ← → node_registry_summary.json
    ├── CatalogueService.java
    ├── CatalogueServicesReport.java    ← → catalogue_services_report.json
    ├── ArgoPeriod.java
    ├── ArgoEndpoint.java
    └── ArgoUptimeReport.java           ← → argo_uptime_report.json




cessda-pilot-node-tests/
├── CHECK_CATALOGUE_SERVICES.md
├── CHECK_NODE_CAPABILITIES.md
├── CHECK_SERVICE_UPTIME.md
├── CITATION.cff
├── CODE_OF_CONDUCT.md
├── CONTRIBUTING.md
├── CONTRIBUTORS.md
├── DASHBOARD_README.md
├── LICENSE.txt
├── METRICS.md
├── pom.xml
├── README.md
└── src/
    └── main/
        └── dashboard/
            ├── index.html
            ├── node.html
            ├── logo-eosc-beyond-horizontal-fc.png
            └── data/
                ├── node_registry_summary.json
                ├── <NODE_NAME_1>/
                │   ├── endpoint_report.json
                │   ├── catalogue_services_report.json
                │   └── argo_uptime_report.json
                ├── <NODE_NAME_2>/
                └── <NODE_NAME_N>/
        ├── java/eu/cessda/pilotnode/
           ├── PilotNodeDashboardApplication.java
           ├── DashboardController.java
           └── WebMvcConfig.java
        ├── resources/
            ├── application.properties
            └── static/
                ├── index.html
                ├── node.html
                └── logo-eosc-beyond-horizontal-fc.png
        ├── scripts/
        │   ├── check_node_capabilities.sh
        │   ├── check_catalogue_services.sh
        │   └── check_service_uptime.sh
 
```

Report files in `src/main/dashboard/data/` use canonical names (no timestamp,
no node name suffix). Each script defaults to writing directly into the
appropriate node subdirectory when run from `src/main/scripts/`, so the
dashboard data is updated in place without any manual file management.

## Configuration

See the following for details of what each script does and how to run it:

- [Check Node Capabilities](CHECK_NODE_CAPABILITIES.md)
- [Check Catalogue Services](CHECK_CATALOGUE_SERVICES.md)
- [Check Service Uptime](CHECK_SERVICE_UPTIME.md)
- [Dashboard](DASHBOARD_README.md)

## Contributing

Please read [CONTRIBUTING](CONTRIBUTING.md) for details on our code of conduct
and the process for submitting pull requests.

## Versioning

See [Semantic Versioning](https://semver.org/) for guidance.

## Contributors

You can find the list of contributors in the [CONTRIBUTORS](CONTRIBUTORS.md)
file.

## Licence

See the [LICENSE](LICENSE.txt) file.

## Citing

See the [CITATION](CITATION.cff) file.

## Support

If you have any issues or suggestions concerning the scripts, please create a
ticket in the [EOSC Beyond Helpdesk](https://helpdesk.sandbox.eosc-beyond.eu/#login).

## TODO

Running the scripts from `cessda-pilot-node-tests/src/main/scripts` directory
works fine when running the application locally. If the app runs in Kubernetes,
define three CronJob resources.Each job runs a small container
(Alpine + bash + jq + curl) that executes one script and writes the output to a
shared PersistentVolumeClaim mounted by both the job pod and the dashboard pod:

```text
PersistentVolumeClaim (ReadWriteMany)
    ├── mounted at /data/dashboard in the Spring Boot pod  (reads)
    └── mounted at /data/dashboard in each CronJob pod     (writes)
```

The Spring Boot property becomes `dashboard.data-dir=/data/dashboard`.

### Where the JSON files live in each approach

| Approach | JSON file location | Spring Boot configuration |
| ---------- | -------- | ------- |
| Local development | src/main/dashboard/data/ | dashboard.data-dir=src/main/dashboard/data |
| Kubernetes + PVC | /data/dashboard/ in pod | DASHBOARD_DATA_DIR=/data/dashboard |
