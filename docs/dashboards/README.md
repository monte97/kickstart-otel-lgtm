# Dashboard Documentation

This folder contains one page per Grafana dashboard included in the stack.

Each page covers: what the dashboard shows, panel-by-panel breakdown, variables, useful queries, and how to interpret the data.

## Available Dashboards

| Dashboard | Signal | Use case |
|-----------|--------|----------|
| [Service Overview](service-overview.md) | Traces → Metrics | RED metrics (Rate, Errors, Duration) per service |
| [Traces Explorer](traces-explorer.md) | Traces | Search and explore distributed traces |
| [Logs Explorer](logs-explorer.md) | Logs | Full-text log search across all services |
| [SLO Dashboard](slo-dashboard.md) | Traces → Metrics | Error budget, burn rate, availability |
| [Alerting Overview](alerting-overview.md) | Metrics | Firing and pending alert rules |
| [Infrastructure](infrastructure.md) | Metrics | CPU, memory, network per Docker container |
| [Infrastructure Full Observability](infra-full-observability.md) | Metrics | Complete infra view + OTel Collector health |
| [OTel Collector Health](otel-collector-health.md) | Metrics | Collector pipeline: ingestion, processing, export |

## Data Flow

```
Your App
  │
  ▼ OTLP (gRPC :4317 / HTTP :4318)
OTel Collector
  ├──► Loki   → Logs Explorer
  ├──► Tempo  → Traces Explorer, Service Overview, SLO Dashboard
  └──► Mimir  → Infrastructure, Infra Full Observability, OTel Collector Health,
                Alerting Overview
```

## Screenshots

Dashboard screenshots are stored in [`images/`](images/).

> **Note:** Screenshots are taken after running the k6 load test (`k6/full-dashboard-populate.js`) which generates realistic traffic with error and latency spikes. Run it before capturing screenshots to get meaningful data in all panels.
