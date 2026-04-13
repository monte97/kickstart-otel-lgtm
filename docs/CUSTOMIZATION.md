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

## Log Retention (Loki)

Edit `loki/config.yaml`:

```yaml
limits_config:
  retention_period: 744h  # 31 days — change to e.g. 168h (7d) or 2160h (90d)
```

Restart Loki: `docker compose restart loki`

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

## Update Component Versions

Versions are pinned in `docker-compose.yml`. To update:

```bash
# Edit the image tag, then:
docker compose pull
docker compose up -d
```

Check the collector config after updates — component names and config keys occasionally change between minor versions.
