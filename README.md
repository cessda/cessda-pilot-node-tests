# Pilot Node Tests

This repository contains the scripts for testing some of the functionality of
an EOSC Beyond Pilot Node and a dashboard to display the outputs.

See [METRICS](METRICS.md) for details of which script to use for which metric.

## Repository Structure

```text
cessda-pilot-node-tests/
├── CHECK_CATALOGUE_SERVICES.md
├── CHECK_NODE_CAPABILITIES.md
├── CHECK_SERVICE_UPTIME.md
├── DASHBOARD_README.md
├── README.md
├── METRICS.md
├── CONTRIBUTING.md
├── CONTRIBUTORS.md
├── LICENSE.txt
├── CITATION.cff
└── src/
    └── main/
        └── dashboard/
            ├── index.html
            ├── node.html
            ├── logo-eosc-beyond-horizontal-fc.png
            └── data/
                ├── node_registry_summary.json
                ├── CESSDA/
                │   ├── endpoint_report.json
                │   ├── catalogue_services_report.json
                │   └── argo_uptime_report.json
                ├── EOSC-Beyond/
                └── NI4OS-EUROPE/
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
