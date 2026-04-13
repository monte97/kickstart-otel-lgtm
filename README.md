# kickstart-otel-lgtm

> Production-ready LGTM stack with OpenTelemetry. Clone, compose up, observe.

[![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)
[![Last Commit](https://img.shields.io/github/last-commit/monte97/kickstart-otel-lgtm)]()

```
Your App → OTel Collector → ┌─ Loki   (logs)    ┐
           (OTLP 4317/18)   ├─ Tempo  (traces)  ├─► Grafana
                            └─ Mimir  (metrics) ┘
```

A plug-and-play observability stack for development and staging. Bring your own app, connect it in 5 minutes.

**Not sure where to start?** → [Book a free 15-min call](https://calendly.com/montelli/consulenza)

---

## Quick Start

```bash
git clone https://github.com/monte97/kickstart-otel-lgtm.git
cd kickstart-otel-lgtm
cp .env.example .env
docker compose up -d
```

Open [http://localhost:3000](http://localhost:3000) — default credentials: `admin` / `admin` (or the value in `.env`)

Three dashboards are pre-loaded: **Service Overview**, **Infrastructure**, **OTel Collector Health**.

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
| [OTel Collector](https://opentelemetry.io/docs/collector/) | 0.120.0 | Receives OTLP, routes to backends |
| [Grafana](https://grafana.com/) | 11.6.0 | Dashboards, alerting |
| [Loki](https://grafana.com/oss/loki/) | 3.3.2 | Log storage |
| [Tempo](https://grafana.com/oss/tempo/) | 2.6.1 | Trace storage + RED metrics |
| [Mimir](https://grafana.com/oss/mimir/) | 2.14.0 | Metrics storage |

Pre-configured:
- ✅ 3 Grafana dashboards (Service Overview, Infrastructure, OTel Collector Health)
- ✅ 5 alert rules (error rate, latency, service down, collector health)
- ✅ Datasources auto-provisioned (Loki, Tempo, Mimir)
- ✅ RED metrics without SDK configuration (via Tempo span-metrics)
- ✅ Container metrics via docker_stats receiver

---

## Documentation

- [Architecture](docs/ARCHITECTURE.md) — data flow, components, Mimir vs Prometheus
- [Instrumentation](docs/INSTRUMENTATION.md) — connect your app
- [Customization](docs/CUSTOMIZATION.md) — ports, retention, auth, pipelines
- [Alerting](docs/ALERTING.md) — customize alert rules
- [Troubleshooting](docs/TROUBLESHOOTING.md) — common issues

---

## Blog Posts

- *(coming soon)*

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
