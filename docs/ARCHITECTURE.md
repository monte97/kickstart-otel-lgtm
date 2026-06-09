# Architecture

## Data Flow

```
Your App
  │
  ├── Logs (OTLP)    ──────────────────────────────► Loki ◄──── Grafana (query)
  ├── Traces (OTLP)  ──► OTel Collector ───────────► Tempo ◄─── Grafana (query)
  └── Metrics (OTLP) ──►  (4317/4318)  ───────────► Mimir ◄─── Grafana (query)
                               │
                               ├── docker_stats ──► container metrics ──► Mimir
                               ├── node-exporter ─► host metrics ────────► Mimir
                               └── self-scrape ───► collector metrics ───► Mimir

Grafana Alerting ────────────────────────────────► Alertmanager ──► Slack/email/…
```

## Components

| Component | Image | Role | Ports |
|-----------|-------|------|-------|
| **OTel Collector** | `otel/opentelemetry-collector-contrib:0.149.0` | Receives OTLP telemetry, tail sampling, routes to backends | `4317` gRPC, `4318` HTTP |
| **Grafana** | `grafana/grafana:12.4.2` | Visualization, dashboards, alerting | `3000` |
| **Loki** | `grafana/loki:3.7.1` | Log storage and querying | `3100` |
| **Tempo** | `grafana/tempo:2.10.4` | Trace storage, span-metrics generator | `3200` |
| **Mimir** | `grafana/mimir:3.0.5` | Metrics storage (Prometheus-compatible) | `9009` |
| **Node Exporter** | `prom/node-exporter:v1.8.2` | Host CPU, RAM, disk, network metrics | `9100` |
| **Alertmanager** | `prom/alertmanager:v0.27.0` | Alert routing and deduplication | `9093` |

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
| `9093` | Alertmanager | Alert routing UI |
| `9100` | Node Exporter | Host metrics endpoint (internal use) |
| `13133` | OTel Collector | Health check |

## RED Metrics: How They Work

The **Service Overview** dashboard shows Request Rate, Error Rate, and Duration (latency) without requiring you to emit explicit metrics from your app.

Tempo's `metrics_generator` with `span-metrics` processor automatically generates Prometheus metrics from every trace it receives:
- `traces_spanmetrics_calls_total` — for rate and error rate
- `traces_spanmetrics_duration_milliseconds_bucket` — for latency histograms

These are written to Mimir and queried by Grafana. **No code changes needed in your app** beyond basic OTel tracing setup.

## Log-Trace Correlation

The OTel Collector promotes `trace_id` and `span_id` from OTLP log records to Loki attributes before ingestion. This means every log line that belongs to a trace is searchable by trace ID in Loki, and Grafana can navigate directly from a log entry to the corresponding trace in Tempo.

## Tail Sampling

The collector buffers spans in memory for a configurable window (`TRACE_DECISION_WAIT`) before deciding what to keep:

1. **keep-errors** — 100% of traces containing at least one error span
2. **keep-slow** — 100% of traces exceeding `TRACE_LATENCY_THRESHOLD_MS`
3. **sample-rest** — `TRACE_SAMPLING_RATE`% of healthy, fast traces

Run `make configure` to adjust these values interactively.

## Storage

All backends use **named Docker volumes** for persistence:

| Volume | Backend | Data |
|--------|---------|------|
| `loki-data` | Loki | Log chunks and index |
| `tempo-data` | Tempo | Trace blocks and WAL |
| `mimir-data` | Mimir | Metric blocks |
| `grafana-data` | Grafana | Dashboards, users, alert state |

Data persists across `docker compose down` and `docker compose up`. Use `make backup` / `make restore` to snapshot volumes before upgrades.

`make clean` (`docker compose down -v`) removes volumes — **data is lost**.

## Single-binary Mode

All components (Loki, Tempo, Mimir) run in single-binary mode. This means:
- **No replication** — suitable for development and staging
- **Not for production** — no HA, no durable object storage

For production, see the [commercial support](../README.md#commercial-support) section.
