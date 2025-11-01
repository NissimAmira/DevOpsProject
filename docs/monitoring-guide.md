# Monitoring & Observability Guide

Complete guide to Prometheus and Grafana monitoring setup for the Hello World Flask application.

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Installation](#installation)
- [Application Metrics](#application-metrics)
- [Prometheus Configuration](#prometheus-configuration)
- [Grafana Dashboards](#grafana-dashboards)
- [Alert Rules](#alert-rules)
- [Troubleshooting](#troubleshooting)

## Overview

This project uses the **kube-prometheus-stack** which includes:
- **Prometheus** - Metrics collection and storage
- **Grafana** - Visualization and dashboards
- **Alertmanager** - Alert routing and notifications
- **Prometheus Operator** - Manages Prometheus instances via CRDs

### Monitoring Stack Components

```
┌──────────────────────────────────────────────────────────┐
│                    Flask Application                      │
│              (exposes /metrics endpoint)                  │
└───────────────────────┬──────────────────────────────────┘
                        │
                        │ HTTP scrape :5000/metrics
                        ▼
┌──────────────────────────────────────────────────────────┐
│                    ServiceMonitor                         │
│           (tells Prometheus where to scrape)              │
└───────────────────────┬──────────────────────────────────┘
                        │
                        ▼
┌──────────────────────────────────────────────────────────┐
│                     Prometheus                            │
│      (collects, stores, and queries metrics)              │
└─────┬──────────────────────────────────────────┬─────────┘
      │                                           │
      │ PromQL queries                            │ Alert evaluation
      ▼                                           ▼
┌──────────────────┐                    ┌──────────────────┐
│     Grafana      │                    │  PrometheusRule  │
│  (dashboards)    │                    │    (alerts)      │
└──────────────────┘                    └─────────┬────────┘
                                                  │
                                                  ▼
                                        ┌──────────────────┐
                                        │  Alertmanager    │
                                        │ (notifications)  │
                                        └──────────────────┘
```

## Architecture

### Key Components

**1. prometheus-client (Python library)**
- Instruments Flask application
- Exposes metrics in Prometheus format
- Tracks requests, latency, custom business metrics

**2. ServiceMonitor (CRD)**
- Kubernetes custom resource
- Defines scrape targets for Prometheus
- Configured via Helm templates

**3. Prometheus**
- Time-series database
- Scrapes metrics from targets
- Evaluates alert rules
- Provides PromQL query language

**4. Grafana**
- Visualization platform
- Connects to Prometheus as data source
- Renders dashboards from ConfigMaps
- Supports alerting and annotations

**5. PrometheusRule (CRD)**
- Defines alert conditions
- Environment-specific thresholds
- Severity levels (critical, warning, info)

## Installation

### Step 1: Install kube-prometheus-stack

```bash
# Add Prometheus Helm repository
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install with custom values
helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
  --set prometheus.prometheusSpec.podMonitorSelectorNilUsesHelmValues=false \
  --set prometheus.prometheusSpec.ruleSelectorNilUsesHelmValues=false

# Wait for deployment
kubectl wait --for=condition=ready pod \
  -l "release=kube-prometheus-stack" \
  -n monitoring \
  --timeout=300s
```

**Important flags:**
- `serviceMonitorSelectorNilUsesHelmValues=false` - Allows ServiceMonitors from any namespace
- `podMonitorSelectorNilUsesHelmValues=false` - Allows PodMonitors from any namespace
- `ruleSelectorNilUsesHelmValues=false` - Allows PrometheusRules from any namespace

### Step 2: Verify Installation

```bash
# Check all monitoring pods
kubectl get pods -n monitoring

# Expected pods:
# - prometheus-kube-prometheus-stack-prometheus-0
# - kube-prometheus-stack-grafana-*
# - alertmanager-kube-prometheus-stack-alertmanager-0
# - kube-prometheus-stack-operator-*
# - kube-prometheus-stack-kube-state-metrics-*
# - kube-prometheus-stack-prometheus-node-exporter-*
```

### Step 3: Access Grafana

```bash
# Port-forward Grafana
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80

# Get admin password
kubectl get secret -n monitoring kube-prometheus-stack-grafana \
  -o jsonpath="{.data.admin-password}" | base64 --decode && echo

# Access: http://localhost:3000
# Username: admin
# Password: (from command above)
```

### Step 4: Access Prometheus

```bash
# Port-forward Prometheus
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090

# Access: http://localhost:9090
```

## Application Metrics

### Flask Metrics Implementation

The Flask app (`app/app.py`) uses `prometheus_client` to expose metrics:

```python
from prometheus_client import Counter, Histogram, generate_latest, REGISTRY

# Define metrics
REQUEST_COUNT = Counter(
    'flask_app_request_count',
    'Total number of requests',
    ['method', 'endpoint', 'http_status']
)

REQUEST_LATENCY = Histogram(
    'flask_app_request_latency_seconds',
    'Request latency in seconds',
    ['method', 'endpoint']
)

# Expose metrics endpoint
@app.route('/metrics')
def metrics():
    return Response(generate_latest(REGISTRY), mimetype='text/plain')
```

### Metrics Exposed

**1. Request Count** (`flask_app_request_count_total`)
```promql
# Example metric
flask_app_request_count_total{endpoint="/",http_status="200",method="GET"} 42
```

**Labels:**
- `method` - HTTP method (GET, POST, etc.)
- `endpoint` - Flask route name (index, hello, metrics)
- `http_status` - HTTP status code (200, 404, 500, etc.)

**2. Request Latency** (`flask_app_request_latency_seconds`)
```promql
# Histogram buckets
flask_app_request_latency_seconds_bucket{endpoint="/",le="0.005",method="GET"} 10
flask_app_request_latency_seconds_bucket{endpoint="/",le="0.01",method="GET"} 20
# ...
flask_app_request_latency_seconds_sum{endpoint="/",method="GET"} 1.234
flask_app_request_latency_seconds_count{endpoint="/",method="GET"} 42
```

**Labels:**
- `method` - HTTP method
- `endpoint` - Flask route name
- `le` - Less than or equal to (histogram buckets)

### Testing Metrics Endpoint

```bash
# From within cluster
kubectl exec -n hello-world-develop deploy/hello-world-app-develop -- \
  python -c "import urllib.request; print(urllib.request.urlopen('http://localhost:5000/metrics').read().decode()[:500])"

# From local machine (with port-forward)
kubectl port-forward -n hello-world-develop svc/hello-world-app-develop 5000:5000
curl http://localhost:5000/metrics
```

## Prometheus Configuration

### ServiceMonitor

Located at: `helm/hello-world-app/templates/servicemonitor.yaml`

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: hello-world-app-develop
  labels:
    release: kube-prometheus-stack  # REQUIRED for discovery
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: hello-world-app
  endpoints:
    - port: http
      path: /metrics
      interval: 60s        # Scrape every 60 seconds
      scrapeTimeout: 10s   # Timeout after 10 seconds
```

**Key Points:**
- Must have `release: kube-prometheus-stack` label
- `selector` matches Service labels (not Pod labels)
- `interval` is environment-specific (dev: 60s, staging: 30s, prod: 15s)

### Verify ServiceMonitor

```bash
# Check if ServiceMonitor exists
kubectl get servicemonitor -n hello-world-develop

# Describe ServiceMonitor
kubectl describe servicemonitor hello-world-app-develop -n hello-world-develop

# Check if Prometheus discovered the target
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
# Visit: http://localhost:9090/targets
# Look for: hello-world-app-develop
```

### PromQL Queries

**Request Rate (per second):**
```promql
rate(flask_app_request_count_total[5m])
```

**Request Rate by Endpoint:**
```promql
sum(rate(flask_app_request_count_total[5m])) by (endpoint)
```

**Error Rate (5xx errors):**
```promql
sum(rate(flask_app_request_count_total{http_status=~"5.."}[5m])) /
sum(rate(flask_app_request_count_total[5m]))
```

**95th Percentile Latency:**
```promql
histogram_quantile(0.95,
  sum(rate(flask_app_request_latency_seconds_bucket[5m])) by (le, endpoint)
)
```

**50th Percentile (Median) Latency:**
```promql
histogram_quantile(0.50,
  sum(rate(flask_app_request_latency_seconds_bucket[5m])) by (le)
)
```

## Grafana Dashboards

### Dashboard Auto-Discovery

Dashboards are automatically loaded from ConfigMaps with label `grafana_dashboard: "1"`.

**Dashboard ConfigMap:** `helm/hello-world-app/templates/grafana-dashboard.yaml`

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: hello-world-app-develop-dashboard
  labels:
    grafana_dashboard: "1"  # Auto-discovery label
data:
  hello-world-app-dashboard.json: |
    {
      "title": "Hello World App - Application Metrics",
      "panels": [ ... ]
    }
```

### Dashboard Panels

**1. Request Rate by Endpoint** (Time Series)
- Query: `sum(rate(flask_app_request_count_total[5m])) by (endpoint)`
- Shows: Requests per second for each endpoint
- Type: Line graph

**2. Error Rate (5xx)** (Gauge)
- Query: `(sum(rate(flask_app_request_count_total{http_status=~"5.."}[5m])) / sum(rate(flask_app_request_count_total[5m]))) * 100`
- Shows: Percentage of 5xx errors
- Type: Gauge with thresholds (green < 2%, yellow < 5%, red > 5%)

**3. Request Latency (p95 & p50)** (Time Series)
- Query p95: `histogram_quantile(0.95, sum(rate(flask_app_request_latency_seconds_bucket[5m])) by (le, endpoint))`
- Query p50: `histogram_quantile(0.50, sum(rate(flask_app_request_latency_seconds_bucket[5m])) by (le, endpoint))`
- Shows: Latency distribution over time
- Type: Line graph

**4. HTTP Status Code Distribution** (Pie Chart)
- Query: `sum(increase(flask_app_request_count_total[5m])) by (http_status)`
- Shows: Breakdown of 200s, 404s, 500s
- Type: Pie chart

**5. Pod Health Status** (Stat)
- Query: `up{job=~".*hello-world-app.*"}`
- Shows: Up (1) or Down (0) for each pod
- Type: Stat panel with value mappings

### Accessing Dashboards

```bash
# Port-forward Grafana
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80

# Login
# User: admin
# Pass: (get from secret)

# Navigate: Dashboards → Search "Hello World App"
```

### Creating Custom Dashboards

**Option 1: Via UI**
1. Create dashboard in Grafana UI
2. Export JSON (Dashboard settings → JSON Model)
3. Add to ConfigMap template
4. Commit to Git

**Option 2: Via ConfigMap**
1. Create ConfigMap with `grafana_dashboard: "1"` label
2. Add dashboard JSON in `data` section
3. Apply to cluster
4. Grafana sidecar auto-loads it

## Alert Rules

### PrometheusRule Configuration

Located at: `helm/hello-world-app/templates/prometheusrule.yaml`

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: hello-world-app-develop
  labels:
    release: kube-prometheus-stack  # REQUIRED for discovery
spec:
  groups:
    - name: hello-world-app-develop.rules
      interval: 30s
      rules:
        - alert: HighErrorRate
          expr: (sum(rate(...)) / sum(rate(...))) > 0.50
          for: 2m
          labels:
            severity: critical
          annotations:
            summary: "High error rate detected"
```

### Alert Rules Defined

**1. HighErrorRate**
- **Condition:** Error rate > threshold (dev: 50%, staging: 10%, prod: 2%)
- **Duration:** Must be true for 2 minutes
- **Severity:** Critical
- **Purpose:** Detect application failures

**2. PodDown**
- **Condition:** `up{job="hello-world-app-develop"} == 0`
- **Duration:** Must be true for 1 minute
- **Severity:** Critical
- **Purpose:** Detect pod crashes

**3. HighLatency**
- **Condition:** p95 latency > threshold (dev: 5s, staging: 2s, prod: 1s)
- **Duration:** Must be true for 3 minutes
- **Severity:** Warning
- **Purpose:** Detect performance degradation

**4. FrequentPodRestarts**
- **Condition:** Restart rate > threshold
- **Duration:** Must be true for 5 minutes
- **Severity:** Warning
- **Purpose:** Detect crash loops

### Environment-Specific Thresholds

Configured in `helm/hello-world-app/values-*.yaml`:

**Development:**
```yaml
monitoring:
  prometheusRule:
    highErrorRateThreshold: 0.50  # 50%
    highLatencyThreshold: 5.0     # 5 seconds
    podRestartThreshold: 0.05
```

**Staging:**
```yaml
monitoring:
  prometheusRule:
    highErrorRateThreshold: 0.10  # 10%
    highLatencyThreshold: 2.0     # 2 seconds
    podRestartThreshold: 0.02
```

**Production:**
```yaml
monitoring:
  prometheusRule:
    highErrorRateThreshold: 0.02  # 2%
    highLatencyThreshold: 1.0     # 1 second
    podRestartThreshold: 0.01
```

### Viewing Alerts

**Prometheus UI:**
```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
# Visit: http://localhost:9090/alerts
```

**Grafana:**
```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
# Visit: http://localhost:3000/alerting/list
```

**CLI:**
```bash
# Get PrometheusRule resources
kubectl get prometheusrules -n hello-world-develop

# Describe alert rules
kubectl describe prometheusrule hello-world-app-develop -n hello-world-develop
```

## Troubleshooting

### Metrics Not Appearing in Prometheus

**1. Check if ServiceMonitor exists:**
```bash
kubectl get servicemonitor -n hello-world-develop
```

**2. Verify ServiceMonitor has correct label:**
```bash
kubectl get servicemonitor hello-world-app-develop -n hello-world-develop \
  -o jsonpath='{.metadata.labels.release}'
# Should output: kube-prometheus-stack
```

**3. Check if Prometheus discovered the target:**
```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
# Visit: http://localhost:9090/targets
# Look for job "hello-world-app-develop"
```

**4. Test metrics endpoint manually:**
```bash
kubectl exec -n hello-world-develop deploy/hello-world-app-develop -- \
  python -c "import urllib.request; print(urllib.request.urlopen('http://localhost:5000/metrics').read().decode()[:200])"
```

### Dashboard Not Loading

**1. Check if ConfigMap exists:**
```bash
kubectl get configmap -n hello-world-develop -l grafana_dashboard=1
```

**2. Verify Grafana sidecar is running:**
```bash
kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana
kubectl logs -n monitoring -l app.kubernetes.io/name=grafana -c grafana-sc-dashboard
```

**3. Restart Grafana to reload dashboards:**
```bash
kubectl rollout restart deployment -n monitoring kube-prometheus-stack-grafana
```

### Alerts Not Firing

**1. Check if PrometheusRule exists:**
```bash
kubectl get prometheusrules -n hello-world-develop
```

**2. Verify rule has correct label:**
```bash
kubectl get prometheusrule hello-world-app-develop -n hello-world-develop \
  -o jsonpath='{.metadata.labels.release}'
# Should output: kube-prometheus-stack
```

**3. Check alert expression in Prometheus:**
```bash
# Port-forward Prometheus
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
# Visit: http://localhost:9090/alerts
# Check if rules are loaded and in "inactive" state
```

**4. Test alert expression manually:**
```bash
# Visit Prometheus and run the query
# Example: (sum(rate(flask_app_request_count_total{http_status=~"5.."}[5m])) / sum(rate(flask_app_request_count_total[5m]))) > 0.50
```

### Generate Test Traffic

Use the traffic generation script to populate metrics:

```bash
# Generate traffic for 60 seconds
./scripts/generate-traffic.sh hello-world-develop 60

# Wait 30-60 seconds for metrics to appear
# (Prometheus scrapes every 15-60 seconds depending on environment)
```

## Best Practices

### ✅ Do

- **Use Counter for cumulative metrics** (total requests, total errors)
- **Use Histogram for latency** (allows percentile calculations)
- **Use Gauge for current values** (current connections, queue size)
- **Add meaningful labels** (endpoint, method, status)
- **Keep cardinality low** (avoid user IDs or unique values as labels)
- **Set appropriate scrape intervals** (dev: 60s, prod: 15s)
- **Use environment-specific thresholds** (lenient dev, strict prod)
- **Test alerts in lower environments** before enabling in production

### ❌ Don't

- Don't use high-cardinality labels (user_id, request_id, timestamp)
- Don't scrape too frequently (increases load)
- Don't ignore metric naming conventions (`_total`, `_seconds`, `_bytes`)
- Don't forget to add units to metric names
- Don't set alert thresholds too tight (causes alert fatigue)
- Don't rely solely on metrics (add logging and tracing)

## Advanced Topics

### Custom Metrics

Add application-specific metrics:

```python
from prometheus_client import Gauge

# Business metric example
ACTIVE_USERS = Gauge('flask_app_active_users', 'Number of active users')

@app.route('/login')
def login():
    ACTIVE_USERS.inc()  # Increment
    return "Logged in"

@app.route('/logout')
def logout():
    ACTIVE_USERS.dec()  # Decrement
    return "Logged out"
```

### Recording Rules

Pre-compute expensive queries:

```yaml
spec:
  groups:
    - name: hello-world-app.recording-rules
      interval: 30s
      rules:
        - record: job:flask_app_request_rate:5m
          expr: sum(rate(flask_app_request_count_total[5m])) by (job)
```

### Alertmanager Configuration

Configure notifications (Slack, email, PagerDuty):

```yaml
receivers:
  - name: slack
    slack_configs:
      - api_url: 'https://hooks.slack.com/services/...'
        channel: '#alerts'
        text: '{{ range .Alerts }}{{ .Annotations.summary }}{{ end }}'

route:
  group_by: ['alertname', 'cluster']
  receiver: 'slack'
  routes:
    - match:
        severity: critical
      receiver: pagerduty
```

## References

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)
- [prometheus_client Python Library](https://github.com/prometheus/client_python)
- [PromQL Basics](https://prometheus.io/docs/prometheus/latest/querying/basics/)

---

**Next Steps:**
- Review [ArgoCD Setup Guide](./argocd-setup.md) for GitOps configuration
- Explore [Main README](../README.md) for full project documentation
