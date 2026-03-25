# Troubleshooting

## No traces in Grafana

**Check 1: Is the Collector receiving spans?**

```bash
curl -s http://localhost:13133/
# Should return {"status":"Server available","upSince":"..."}
```

**Check 2: Is your app sending to the right endpoint?**

Verify `OTEL_EXPORTER_OTLP_ENDPOINT` is set and points to `localhost:4317` (gRPC) or `localhost:4318` (HTTP).

**Check 3: Collector logs**

```bash
docker compose logs otel-collector | grep -i "error\|refused\|drop"
```

**Check 4: Test with a manual span**

```bash
# Requires grpcurl: https://github.com/fullstorydev/grpcurl
grpcurl -plaintext -d '{}' localhost:4317 opentelemetry.proto.collector.trace.v1.TraceService/Export
```

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

Components may still be starting. Wait 30 seconds and check again:
```bash
docker compose logs --since 30s otel-collector
```

**"memory limit reached"**

The memory_limiter is dropping data. Increase limit in `.env`:
```bash
OTELCOL_MEMORY_LIMIT_MIB=1024
```
Then restart: `docker compose restart otel-collector`

---

## Missing metrics (Infrastructure dashboard empty)

The Infrastructure dashboard requires the `docker_stats` receiver, which needs `/var/run/docker.sock` mounted in the Collector container. Verify:

```bash
docker compose exec otel-collector ls /var/run/docker.sock
```

If not found, check that your user has permission to mount the socket.

---

## How to verify my app is sending data

Send a test request to your app, then immediately check:

```bash
# Check Loki for logs from your service
curl -s "http://localhost:3100/loki/api/v1/query?query={service_name=\"my-service\"}" | python3 -m json.tool

# Check Tempo for traces
curl -s "http://localhost:3200/api/search?service.name=my-service" | python3 -m json.tool
```

Replace `my-service` with the value of your `OTEL_SERVICE_NAME`.
