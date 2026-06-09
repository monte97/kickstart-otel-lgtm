# kickstart-otel-lgtm

> Production-ready LGTM stack with OpenTelemetry. Clone, configure, observe.

[![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)
[![Last Commit](https://img.shields.io/github/last-commit/monte97/kickstart-otel-lgtm)]()

```
Your App → OTel Collector → ┌─ Loki         (logs)    ┐
           (OTLP 4317/18)   ├─ Tempo        (traces)  ├─► Grafana
                            └─ Mimir        (metrics) ┘

Node Exporter ─────────────────────────────────────────► Mimir (host metrics)
Grafana Alerting ──────────────────────────────────────► Alertmanager
```

A plug-and-play observability stack for development and staging. Bring your own app, connect it in 5 minutes.

**Not sure where to start?** → [Book a free 15-min call](https://calendly.com/montelli/consulenza)

---

## Quick Start

```bash
git clone https://github.com/monte97/kickstart-otel-lgtm.git
cd kickstart-otel-lgtm
make setup        # initialise submodules + copy .env
make configure    # interactive wizard (credentials, sampling, retention)
make up           # start all services
make check        # verify all services are healthy
```

Open [http://localhost:3000](http://localhost:3000) — credentials from your `.env` (default: `admin` / `admin`)

Three dashboards are pre-loaded: **Service Overview**, **Infrastructure**, **OTel Collector Health**.

> **First time on a fresh server?** Run `make deps` before `make setup` to install Docker Engine and the Compose plugin.

---

## Connect Your App

Set these env vars in your app:

```bash
OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4317
OTEL_SERVICE_NAME=my-service
```

That's it. Logs, traces, and metrics flow automatically.

→ [Detailed setup for .NET, Go, Python, Node.js](docs/INSTRUMENTATION.md)

---

## Try with MockMart

[MockMart](https://github.com/monte97/MockMart) is a fully instrumented Node.js microservices e-commerce app. Use it to generate real traffic and see the stack in action with distributed traces, RED metrics, and correlated logs.

---

## What's Inside

| Component | Version | Role |
|-----------|---------|------|
| [OTel Collector](https://opentelemetry.io/docs/collector/) | 0.149.0 | Receives OTLP, routes to backends, tail sampling |
| [Grafana](https://grafana.com/) | 12.4.2 | Dashboards, alerting |
| [Loki](https://grafana.com/oss/loki/) | 3.7.1 | Log storage |
| [Tempo](https://grafana.com/oss/tempo/) | 2.10.4 | Trace storage + RED metrics |
| [Mimir](https://grafana.com/oss/mimir/) | 3.0.5 | Metrics storage |
| [Node Exporter](https://github.com/prometheus/node_exporter) | 1.8.2 | Host metrics (CPU, RAM, disk, network) |
| [Alertmanager](https://prometheus.io/docs/alerting/latest/alertmanager/) | 0.27.0 | Alert routing (Slack, email, PagerDuty…) |

Pre-configured:
- ✅ 3 Grafana dashboards (Service Overview, Infrastructure, OTel Collector Health)
- ✅ 5 alert rules (error rate, latency, service down, collector health)
- ✅ Watchdog (dead man's switch) — fires if alerting pipeline goes down
- ✅ Datasources auto-provisioned (Loki, Tempo, Mimir, Alertmanager)
- ✅ RED metrics without SDK configuration (via Tempo span-metrics)
- ✅ Container metrics via docker_stats + host metrics via Node Exporter
- ✅ Tail sampling — 100% errors/slow traces, configurable % for healthy ones
- ✅ Persistent storage — named volumes survive `docker compose down`
- ✅ Log-trace correlation — `trace_id` indexed in Loki for one-click navigation

---

## Makefile Reference

```bash
make deps              # install Docker + Compose (Debian/Ubuntu)
make setup             # init submodules + copy .env
make configure         # interactive wizard → writes .env

make up                # start all services
make down              # stop and remove containers
make restart           # restart all services
make restart s=<svc>   # restart a specific service
make update            # pull latest images and restart

make check             # health check all services
make logs s=<svc>      # follow logs for a service
make open              # open Grafana in the browser
make smoke-test        # send a test trace end-to-end

make backup            # backup all volumes to ./backups/
make restore file=<f>  # restore from backup

make clean             # remove containers, networks, and volumes
```

---

## Add Your Own App

Use `docker-compose.override.yml` to connect your app without modifying this repo:

```bash
cp docker-compose.override.yml.example docker-compose.override.yml
# edit docker-compose.override.yml to reference your service
docker compose up -d
```

→ See [docker-compose.override.yml.example](docker-compose.override.yml.example) for a full example.

---

## Documentation

- [Architecture](docs/ARCHITECTURE.md) — data flow, components, ports
- [Instrumentation](docs/INSTRUMENTATION.md) — connect your app
- [Customization](docs/CUSTOMIZATION.md) — sampling, retention, pipelines
- [Alerting](docs/ALERTING.md) — alert rules, Alertmanager, dead man's switch
- [Grafana](docs/GRAFANA.md) — dashboards, variables, datasources
- [Troubleshooting](docs/TROUBLESHOOTING.md) — common issues

---

## Commercial Support

Need this configured for your team? I offer productized observability setup services with fixed scope, transparent pricing, and training included.

→ **[View services and pricing](https://montelli.dev/servizi/observability)**
→ **[Book a free 15-min call](https://calendly.com/montelli/consulenza)**

This repo is the "do it yourself" version. The service includes:
- Personalization for your specific stack
- Instrumentation of your existing services
- 4–8h hands-on workshop with your team
- Operational runbook tailored to your environment
- Ongoing support retainer

---

## Contributing

Contributions welcome! Open an issue or PR.

## License

[Apache License 2.0](LICENSE)
