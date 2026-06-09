# Alerting

## Pre-configured Alert Rules

The following rules fire automatically. Thresholds can be adjusted in the submodule's alerting provisioning.

| Alert | Threshold | Severity |
|-------|-----------|----------|
| High Error Rate | > 5% for 5 min | critical |
| High Latency (p99) | > 2000 ms for 5 min | warning |
| Service Down | No spans for 5 min | critical |
| Collector Dropping | Dropped spans > 0 for 2 min | warning |
| Collector Queue High | Queue > 80% capacity for 2 min | warning |
| **Watchdog** | Always firing | none |

## Watchdog (Dead Man's Switch)

The **Watchdog** alert fires continuously — it is *designed* to always be in `Firing` state.

If it goes silent, it means Grafana itself (or the entire alerting pipeline) is down. Configure Alertmanager to forward this alert to an external dead-man's-switch service that notifies you when the heartbeat stops arriving.

Services that support this pattern:
- [healthchecks.io](https://healthchecks.io) — free tier available
- [DeadMansSnitch](https://deadmanssnitch.com)
- [Better Uptime](https://betteruptime.com)

To wire it up, edit `alertmanager/config.yml`:

```yaml
receivers:
  - name: watchdog
    webhook_configs:
      - url: 'https://hc-ping.com/YOUR-UUID-HERE'
        send_resolved: false
```

## Alertmanager

Alertmanager handles routing, deduplication, and delivery of alerts from Grafana to external systems. It is available at [http://localhost:9093](http://localhost:9093).

### Configuration

Edit `alertmanager/config.yml`. The file ships with a `null` receiver (silent) and commented examples for Slack, email, and PagerDuty.

**Slack example:**

```yaml
receivers:
  - name: slack
    slack_configs:
      - api_url: 'https://hooks.slack.com/services/T.../B.../...'
        channel: '#alerts'
        title: '[{{ .Status | toUpper }}] {{ .GroupLabels.alertname }}'
        text: '{{ range .Alerts }}{{ .Annotations.summary }}{{ end }}'
        send_resolved: true
```

**Email example:**

```yaml
receivers:
  - name: email
    email_configs:
      - to: 'ops@example.com'
        from: 'alertmanager@example.com'
        smarthost: 'smtp.example.com:587'
        auth_username: 'alertmanager@example.com'
        auth_password: 'secret'
        send_resolved: true
```

**PagerDuty example:**

```yaml
receivers:
  - name: pagerduty
    pagerduty_configs:
      - routing_key: 'YOUR_INTEGRATION_KEY'
```

After editing, apply changes without restart:

```bash
curl -X POST http://localhost:9093/-/reload
```

### Routing

By default all alerts go to the `null` receiver (silent). To route critical alerts to Slack:

```yaml
route:
  receiver: 'null'
  routes:
    - matchers:
        - severity = critical
      receiver: slack
    - matchers:
        - alertname = Watchdog
      receiver: watchdog
      repeat_interval: 1m
```

## Adding Custom Alert Rules

Add a new rule file under `grafana/provisioning/alerting/` and mount it as a single file in `docker-compose.yml` (same pattern as `watchdog.yaml`):

```yaml
# docker-compose.yml — grafana volumes
- ./grafana/provisioning/alerting/my-rules.yaml:/etc/grafana/provisioning/alerting/my-rules.yaml:ro
```

Each rule needs a unique `uid`, a `condition` refId, a `data` array with queries and threshold expressions, and `annotations.summary`.

## Changing Thresholds

The pre-configured rules live in the `grafana-dashboards` submodule. To override a threshold, add a new rule with the same `uid` in a local file — Grafana's last-writer-wins provisioning will apply your version.

## Alert Fatigue Prevention

- Start with `critical` alerts only; add `warning` after baseline is stable
- Use `for: 5m` to avoid flapping on transient spikes
- Group related alerts in Alertmanager's `group_by`
- Use Alertmanager `inhibit_rules` to suppress warnings when a critical fires for the same service
- Create silence windows for planned maintenance in the Grafana UI: **Alerting → Silences**
