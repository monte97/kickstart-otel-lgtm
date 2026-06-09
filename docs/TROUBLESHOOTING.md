# Troubleshooting

## First Steps

Run these two commands before digging deeper:

```bash
make check       # health check all services — shows UP/DOWN at a glance
make smoke-test  # sends a test trace end-to-end and verifies it arrives in Tempo
```

---

## No traces in Grafana

**Check 1: Are all services healthy?**

```bash
make check
```

**Check 2: Is your app sending to the right endpoint?**

Verify `OTEL_EXPORTER_OTLP_ENDPOINT` is set and points to `localhost:4317` (gRPC) or `localhost:4318` (HTTP).

**Check 3: Collector logs**

```bash
make logs s=otel-collector
# or filter for errors only:
docker compose logs otel-collector | grep -i "error\|refused\|drop"
```

**Check 4: Verify with the built-in smoke test**

```bash
make smoke-test
```

This sends a trace with `status=ERROR` (always sampled) and waits for it to appear in Tempo. If it doesn't arrive, the output shows where in the pipeline to look.

---

## Dashboard is empty (no data)

**Check 1: Are the datasources connected?**

In Grafana: **Connections → Data sources** → click each datasource → **Save & test**

**Check 2: Is Mimir receiving metrics?**

```bash
curl -s "http://localhost:9009/prometheus/api/v1/label/__name__/values" | python3 -m json.tool | head -20
```

If empty, Mimir hasn't received any data yet. Send some telemetry first.

**Check 3: Time range**

Make sure the Grafana time range covers the period when you sent data.

---

## Collector errors in logs

**"connection refused" to Loki/Tempo/Mimir**

Components may still be starting. Check status:

```bash
make check
docker compose logs --since 30s otel-collector
```

**"memory limit reached" / data being dropped**

The memory_limiter is dropping data. Increase the limit in `otel-collector/config.yaml`:

```yaml
processors:
  memory_limiter:
    limit_mib: 1024
    spike_limit_mib: 256
```

Also raise the Docker memory limit in `docker-compose.yml`:

```yaml
# otel-collector service
deploy:
  resources:
    limits:
      memory: 1200m
```

Restart: `make restart s=otel-collector`

---

## Missing host metrics (Node Exporter)

The Infrastructure dashboard requires Node Exporter to have access to the host's `/proc`, `/sys`, and `/` filesystem. Verify the container is running and its bind mounts are accessible:

```bash
make check
docker compose exec node-exporter wget -qO- http://localhost:9100/metrics | head -20
```

On some systems, `pid: host` in `docker-compose.yml` requires privileged mode or specific kernel capabilities.

---

## Missing container metrics (Infrastructure dashboard empty)

The Infrastructure dashboard requires the `docker_stats` receiver, which needs `/var/run/docker.sock` mounted. Verify:

```bash
docker compose exec otel-collector ls /var/run/docker.sock
```

If not found, check that your user has permission to access the Docker socket.

---

## Alertmanager not receiving alerts

**Check 1: Is Alertmanager healthy?**

```bash
make check
curl http://localhost:9093/-/healthy
```

**Check 2: Is Grafana configured to use it?**

In Grafana: **Alerting → Alertmanagers** — the `Alertmanager` datasource should appear as active.

**Check 3: Check Alertmanager logs**

```bash
make logs s=alertmanager
```

**Check 4: Test a notification manually**

```bash
curl -X POST http://localhost:9093/api/v1/alerts \
  -H "Content-Type: application/json" \
  -d '[{"labels":{"alertname":"test","severity":"info"},"annotations":{"summary":"manual test"}}]'
```

---

## How to verify my app is sending data

Send a test request to your app, then:

```bash
# Check Loki for logs from your service
curl -s "http://localhost:3100/loki/api/v1/query?query={service_name=\"my-service\"}" | python3 -m json.tool

# Check Tempo for traces
curl -s "http://localhost:3200/api/search?service.name=my-service" | python3 -m json.tool
```

Replace `my-service` with the value of your `OTEL_SERVICE_NAME`.

---

## Logs visible but no trace correlation

Trace correlation requires the app SDK to populate `traceId` on log records. The collector then promotes it to a Loki label automatically. Verify:

```bash
# Check if trace_id appears as an attribute in a recent log
curl -s 'http://localhost:3100/loki/api/v1/query?query={service_name="my-service"}&limit=1' \
  | python3 -m json.tool | grep trace_id
```

If `trace_id` is missing, check your SDK's logging integration (e.g., `opentelemetry-instrumentation-logging` for Python, `@opentelemetry/winston-transport` for Node.js).
