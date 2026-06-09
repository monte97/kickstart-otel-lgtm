# Customization

Common adjustments for adapting the stack to your environment.

---

## Interactive Configuration

The fastest way to change any setting is the guided wizard:

```bash
make configure
```

It covers Grafana credentials, trace sampling parameters, and data retention. Values are written to `.env` and picked up automatically on next startup.

---

## Grafana Credentials

Set in `.env`:

```bash
GF_SECURITY_ADMIN_USER=admin
GF_SECURITY_ADMIN_PASSWORD=changeme
```

Or run `make configure` and answer the first section.

Restart to apply: `make restart s=grafana`

## Disable Anonymous Access

By default, unauthenticated users can browse Grafana as Viewers. To require login:

```yaml
# docker-compose.yml — grafana environment
- GF_AUTH_ANONYMOUS_ENABLED=false
```

---

## Tail-based Trace Sampling

The collector keeps 100% of error traces and slow traces, and samples a configurable percentage of healthy ones.

Configure via `.env`:

```bash
TRACE_SAMPLING_RATE=20          # % of healthy traces to keep (0–100)
TRACE_LATENCY_THRESHOLD_MS=2000 # traces slower than this are always kept
TRACE_DECISION_WAIT=10s         # buffer window to collect all spans before deciding
```

Or run `make configure` and answer section [2/3].

The tail sampler buffers spans in memory during `TRACE_DECISION_WAIT`. If you handle very high trace volume, increase `memory_limiter.limit_mib` in `otel-collector/config.yaml` accordingly.

---

## Data Retention

Each backend has independent configurable retention. Configure via `.env`:

```bash
LOKI_RETENTION_PERIOD=744h    # logs:    31 days  (h / d / w)
TEMPO_BLOCK_RETENTION=168h    # traces:   7 days
MIMIR_BLOCKS_RETENTION=2160h  # metrics: 90 days
```

Or run `make configure` and answer section [3/3].

Restart the relevant backend to apply:

```bash
make restart s=loki
make restart s=tempo
make restart s=mimir
```

---

## Collector Memory Limit

The OTel Collector is capped at 512 MiB by default. Increase for high-traffic environments:

```yaml
# otel-collector/config.yaml
processors:
  memory_limiter:
    limit_mib: 1024
    spike_limit_mib: 256
```

The Docker-level limit in `docker-compose.yml` (`deploy.resources.limits.memory`) should be set slightly higher (e.g., `1200m`) to account for Go runtime overhead.

## Disable the Debug Exporter

The `debug` exporter prints sample telemetry to the collector logs. Remove it in non-development environments:

1. Delete the `debug` block under `exporters` in `otel-collector/config.yaml`
2. Remove `debug` from the `traces` pipeline exporters

---

## Expose Only What You Need

By default, Loki (3100), Tempo (3200), and Mimir (9009) are exposed to the host for direct querying. If you only need Grafana, remove those port mappings from `docker-compose.yml` — the services still communicate internally.

## Change Exposed Ports

Edit `docker-compose.yml`. Example — move Grafana to port 8080:

```yaml
ports:
  - "8080:3000"
```

---

## Add a Custom Dashboard

Place your dashboard JSON in the `grafana-dashboards` submodule, or mount an additional directory:

```yaml
# docker-compose.yml — grafana volumes
- ./my-dashboards:/var/lib/grafana/dashboards/custom:ro
```

---

## Add a Signal Pipeline

To add a new pipeline (e.g., a second metrics pipeline with different processors):

```yaml
# otel-collector/config.yaml
service:
  pipelines:
    metrics/custom:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [prometheusremotewrite/mimir]
```

## Skip a Signal Entirely

If your app does not emit logs, remove the `logs` pipeline from `otel-collector/config.yaml` and the corresponding exporter. Less noise, less resource usage.

---

## Reverse Proxy (Grafana)

Set the root URL so redirects and cookie paths work correctly:

```yaml
# docker-compose.yml — grafana environment
- GF_SERVER_ROOT_URL=https://grafana.yourdomain.com
- GF_SERVER_SERVE_FROM_SUB_PATH=true  # only if hosted at a sub-path
```

---

## Drop Noisy Spans

Health checks and readiness probes generate spans with no value. Filter them in `otel-collector/config.yaml`:

```yaml
processors:
  filter/drop-health-checks:
    error_mode: ignore
    traces:
      span:
        - attributes["url.path"] == "/health"
        - attributes["url.path"] == "/ready"
        - attributes["url.path"] == "/metrics"
        - attributes["http.target"] == "/health"
```

Add `filter/drop-health-checks` to the `traces` pipeline before `batch`.

---

## Add Your Own App (docker-compose override)

Use `docker-compose.override.yml` to connect your app without modifying this repo:

```bash
cp docker-compose.override.yml.example docker-compose.override.yml
# edit to reference your service image and env vars
docker compose up -d
```

Docker Compose loads the override automatically alongside the main file.

---

## Configure Alertmanager Notification Channels

Edit `alertmanager/config.yml` to add Slack, email, PagerDuty, or webhook receivers. See [ALERTING.md](ALERTING.md) for examples and the dead man's switch setup.

Apply without restart:

```bash
curl -X POST http://localhost:9093/-/reload
```

---

## Grafana Dashboard Variables

The pre-loaded dashboards use template variables (`$service`, `$environment`) to filter data. If you build custom dashboards, follow the same pattern.

In Grafana: **Dashboard settings → Variables → Add variable**

| Variable | Type | Query example |
|---|---|---|
| `service` | Query | `label_values(traces_spanmetrics_calls_total, service_name)` |
| `environment` | Query | `label_values(traces_spanmetrics_calls_total, deployment_environment)` |
| `interval` | Interval | `1m,5m,15m,1h` |

---

## Update Component Versions

Versions are pinned in `docker-compose.yml`. To update:

```bash
make update   # pulls latest pinned images and restarts
```

To change a version, edit the image tag in `docker-compose.yml` first, then run `make update`. Check the collector config after updates — component names and config keys occasionally change between minor versions.
