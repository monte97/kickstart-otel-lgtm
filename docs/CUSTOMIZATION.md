# Customization

Common adjustments for adapting the stack to your environment.

---

## Grafana Credentials

Set in `.env` (copy from `.env.example`):

```bash
GF_SECURITY_ADMIN_USER=admin
GF_SECURITY_ADMIN_PASSWORD=changeme
```

Restart Grafana to apply: `docker compose restart grafana`

## Disable Anonymous Access

By default, unauthenticated users can browse Grafana as Viewers. To require login:

```yaml
# docker-compose.yml — grafana environment
- GF_AUTH_ANONYMOUS_ENABLED=false
```

## Tail-based Trace Sampling

By default the collector forwards every trace. For high-volume environments you typically want to keep **all** traces that contain errors or are slow, and sample down the healthy ones.

Add the `tail_sampling` processor in `otel-collector/config.yaml`:

```yaml
processors:
  tail_sampling:
    decision_wait: 10s   # how long to buffer spans before deciding
    policies:
      # always keep traces with errors
      - name: keep-errors
        type: status_code
        status_code: { status_codes: [ERROR] }
      # always keep slow traces (> 1s)
      - name: keep-slow
        type: latency
        latency: { threshold_ms: 1000 }
      # sample 10% of everything else
      - name: sample-healthy
        type: probabilistic
        probabilistic: { sampling_percentage: 10 }
```

Then add `tail_sampling` to the `traces` pipeline:

```yaml
pipelines:
  traces:
    receivers: [otlp]
    processors: [memory_limiter, tail_sampling, resourcedetection, batch]
    exporters: [otlp_grpc/tempo, debug]
```

> **Note:** `tail_sampling` buffers spans in memory for `decision_wait` seconds before deciding. Increase `memory_limiter.limit_mib` if you handle high trace volume.

## Data Retention

Each backend has independent retention. Data is stored on the container's local filesystem and deleted on `docker compose down` unless you mount a named volume.

### Logs (Loki)

Edit `loki/config.yaml`:

```yaml
limits_config:
  retention_period: 744h  # 31 days — change to e.g. 168h (7d) or 2160h (90d)
```

Restart: `docker compose restart loki`

### Traces (Tempo)

Edit `tempo/config.yaml`:

```yaml
compactor:
  compaction:
    block_retention: 24h  # default — increase to e.g. 168h (7d)
```

Restart: `docker compose restart tempo`

### Metrics (Mimir)

Add a retention period under `limits` in `mimir/config.yaml`:

```yaml
limits:
  compactor_blocks_retention_period: 30d  # e.g. 30d, 90d, 1y
```

Restart: `docker compose restart mimir`

## Collector Memory Limit

The OTel Collector is capped at 512 MiB by default. Increase for high-traffic environments:

```yaml
# otel-collector/config.yaml
processors:
  memory_limiter:
    limit_mib: 1024
    spike_limit_mib: 256
```

## Disable the Debug Exporter

The `debug` exporter prints sample telemetry to the collector logs. Remove it in non-development environments:

1. Delete the `debug` block under `exporters`
2. Remove `debug` from the `traces` pipeline exporters

## Expose Only What You Need

By default, Loki (3100), Tempo (3200), and Mimir (9009) are exposed to the host for direct querying. If you only need Grafana, remove those port mappings from `docker-compose.yml` — the services still communicate internally.

## Change Exposed Ports

Edit `docker-compose.yml`. Example — move Grafana to port 8080:

```yaml
ports:
  - "8080:3000"
```

## Use a Custom Grafana Dashboard

Place your dashboard JSON in `grafana/dashboards/`. It will be provisioned automatically on next startup.

To disable the default dashboards, remove the files from `grafana/dashboards/` and the `grafana-dashboards` volume mount from `docker-compose.yml`.

## Add a Signal Pipeline

To add a new pipeline (e.g., a second metrics pipeline with different processors), add a named pipeline in `otel-collector/config.yaml`:

```yaml
service:
  pipelines:
    metrics/custom:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [prometheusremotewrite/mimir]
```

## Skip a Signal Entirely

If your app does not emit logs, remove the `logs` pipeline from `otel-collector/config.yaml` and the corresponding exporter. Less noise, less resource usage.

## Reverse Proxy (Grafana)

Set the root URL so redirects and cookie paths work correctly:

```yaml
# docker-compose.yml — grafana environment
- GF_SERVER_ROOT_URL=https://grafana.yourdomain.com
- GF_SERVER_SERVE_FROM_SUB_PATH=true  # only if hosted at a sub-path
```

## Drop Noisy Spans

Health checks, readiness probes, and similar endpoints generate spans that add no value. Filter them out in `otel-collector/config.yaml` using the `filter` processor:

```yaml
processors:
  filter/drop-health-checks:
    error_mode: ignore
    traces:
      span:
        # drop spans where the URL path is a health/readiness endpoint
        - attributes["url.path"] == "/health"
        - attributes["url.path"] == "/ready"
        - attributes["url.path"] == "/metrics"
        - attributes["http.target"] == "/health"
```

Add it to the `traces` pipeline (before `batch`):

```yaml
pipelines:
  traces:
    receivers: [otlp]
    processors: [memory_limiter, filter/drop-health-checks, resourcedetection, batch]
    exporters: [otlp_grpc/tempo, debug]
```

Adjust the attribute names to match your instrumentation library (`url.path` for OTel semantic conventions, `http.target` for older SDKs).

## Rate Limiting per Service

Prevent a single noisy service from saturating the collector and starving everything else. Use the `ratelimit` extension or, more commonly, the `memory_limiter` in combination with a per-service `routing` processor.

A simpler approach for most setups: cap ingestion with `memory_limiter` (already configured) and rely on `batch` to smooth bursts. If you need hard per-service limits, add a named pipeline per service with its own `memory_limiter` threshold:

```yaml
processors:
  memory_limiter/noisy-service:
    check_interval: 1s
    limit_mib: 128       # cap this service's pipeline at 128 MiB
    spike_limit_mib: 32

service:
  pipelines:
    traces/noisy-service:
      receivers: [otlp]
      processors: [memory_limiter/noisy-service, batch]
      exporters: [otlp_grpc/tempo]
```

Route traffic to the right pipeline using the `routing` processor keyed on `service.name`.

## Grafana Dashboard Variables

The pre-loaded dashboards use template variables (`$service`, `$environment`) to filter data without hardcoding queries. If you build custom dashboards, follow the same pattern.

In Grafana: **Dashboard settings → Variables → Add variable**

Useful variables to define:

| Variable | Type | Query example |
|---|---|---|
| `service` | Query | `label_values(traces_spanmetrics_calls_total, service_name)` |
| `environment` | Query | `label_values(traces_spanmetrics_calls_total, deployment_environment)` |
| `interval` | Interval | `1m,5m,15m,1h` |

Then reference them in panel queries as `$service`, `$environment`, `$__rate_interval`.

> **Tip:** set `Multi-value` and `Include All option` on service/environment variables so you can select multiple services at once or see the full picture.

## Update Component Versions

Versions are pinned in `docker-compose.yml`. To update:

```bash
# Edit the image tag, then:
docker compose pull
docker compose up -d
```

Check the collector config after updates — component names and config keys occasionally change between minor versions.
