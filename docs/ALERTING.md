# Alerting

## Pre-configured Alert Rules

Five rules are provisioned automatically in `grafana/provisioning/alerting/rules.yaml`:

| Alert | Threshold | Severity |
|-------|-----------|----------|
| High Error Rate | > 5% for 5min | critical |
| High Latency (p99) | > 2000ms for 5min | warning |
| Service Down | No spans for 5min | critical |
| Collector Dropping | Dropped spans > 0 for 2min | warning |
| Collector Queue High | Queue > 80% capacity for 2min | warning |

## Changing Thresholds

Edit `grafana/provisioning/alerting/rules.yaml` and modify the `params` value:

```yaml
# Change error rate threshold from 5% to 1%
- evaluator:
    params: [0.01]  # was 0.05
    type: gt
```

Restart Grafana to apply: `docker compose restart grafana`

## Adding Custom Alerts

Add a new rule block under `groups[0].rules` in `grafana/provisioning/alerting/rules.yaml`.

Each rule needs:
- `uid`: unique string identifier
- `title`: display name
- `condition`: ref ID of the threshold condition (e.g., `C`)
- `data`: array with metric query (`A`) and threshold condition (`C`)
- `for`: how long condition must hold before firing
- `annotations.summary`: alert message

## Connecting Notification Channels

In Grafana UI: **Alerting → Contact points → Add contact point**

Supported: Slack, Email, PagerDuty, Opsgenie, Webhook, and more.

To provision contact points as code, add to `grafana/provisioning/alerting/rules.yaml`:

```yaml
contactPoints:
  - orgId: 1
    name: slack-ops
    receivers:
      - uid: slack-ops
        type: slack
        settings:
          url: "https://hooks.slack.com/services/..."
          channel: "#alerts"
```

## Alert Fatigue Prevention

- Start with `critical` alerts only; add `warning` after baseline is stable
- Use `for: 5m` to avoid flapping alerts
- Group related alerts in Grafana's notification policies
- Add `silence` for planned maintenance windows
- Add `silence` for planned maintenance windows
