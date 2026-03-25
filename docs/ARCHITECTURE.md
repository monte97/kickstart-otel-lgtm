# Architecture

## Data Flow

```
Your App
  │
  ├── Logs (OTLP)    ─────────────────────────────► Loki ◄─── Grafana (query)
  ├── Traces (OTLP)  ──► OTel Collector ──────────► Tempo ◄── Grafana (query)
  └── Metrics (OTLP) ──►  (4317/4318)  ──────────► Mimir ◄── Grafana (query)
                               │
                               ├── docker_stats receiver → container metrics → Mimir
                               └── self-monitoring (port 8888) → collector metrics → Mimir
```

## Components

| Component | Image | Role | Ports |
|-----------|-------|------|-------|
| **OTel Collector** | `otel/opentelemetry-collector-contrib:0.120.0` | Receives OTLP telemetry, routes to backends | `4317` (gRPC), `4318` (HTTP) |
| **Grafana** | `grafana/grafana:11.6.0` | Visualization, dashboards, alerting | `3000` |
| **Loki** | `grafana/loki:3.3.2` | Log storage and querying | `3100` |
| **Tempo** | `grafana/tempo:2.6.1` | Trace storage (also generates RED metrics via span-metrics) | `3200` |
| **Mimir** | `grafana/mimir:2.14.0` | Metrics storage (Prometheus-compatible remote write) | `9009` |

## Why Mimir instead of Prometheus

Prometheus needs to **pull** (scrape) metrics from services. This means you have to expose a `/metrics` endpoint from every service, and Prometheus needs network access to all of them.

OTel apps **push** metrics via OTLP. Mimir accepts this via **remote write** — no scraping needed. The OTel Collector receives OTLP metrics from your app and forwards them to Mimir via remote write.

Result: simpler architecture, no service discovery configuration, works the same in Docker, Kubernetes, and cloud.

## Ports Exposed to Host

| Port | Service | Use |
|------|---------|-----|
| `4317` | OTel Collector | Connect your app via OTLP gRPC |
| `4318` | OTel Collector | Connect your app via OTLP HTTP |
| `3000` | Grafana | Browser UI |
| `3100` | Loki | Direct log query (optional) |
| `3200` | Tempo | Direct trace query (optional) |
| `9009` | Mimir | Direct metric query (optional) |
| `13133` | OTel Collector | Health check |

## RED Metrics: How They Work

The **Service Overview** dashboard shows Request Rate, Error Rate, and Duration (latency) without requiring you to emit explicit metrics from your app.

Tempo's `metrics_generator` with `span-metrics` processor automatically generates Prometheus metrics from every trace it receives:
- `traces_spanmetrics_calls_total` — for rate and error rate
- `traces_spanmetrics_duration_milliseconds_bucket` — for latency histograms

These are written to Mimir and queried by Grafana. **No code changes needed in your app** beyond basic OTel tracing setup.

## Single-binary Mode

All components (Loki, Tempo, Mimir) run in single-binary mode with local filesystem storage. This means:
- **Data is ephemeral** — `docker compose down` deletes traces/logs/metrics
- **Not for production** — no replication, no HA, no durable storage

For production, see the [commercial support](#commercial-support) section in the main README.
