# Hello World App - DevOps Project

A production-ready Flask web application demonstrating modern DevOps practices including containerization, Kubernetes deployment, CI/CD pipelines, GitOps with ArgoCD, and comprehensive monitoring with Prometheus & Grafana.

## 🎯 Project Overview

This project demonstrates a complete DevOps lifecycle for a cloud-native application:

- **Phase 1:** Containerization with Docker
- **Phase 2:** Kubernetes deployment with Helm
- **Phase 3:** CI/CD pipeline with GitHub Actions
- **Phase 4:** GitOps with ArgoCD + Monitoring with Prometheus & Grafana

### Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         GitHub Repository                        │
│  ┌──────────────┐  ┌──────────────┐  ┌────────────────────┐   │
│  │  Source Code │  │ Helm Charts  │  │  ArgoCD Apps       │   │
│  │  (Flask App) │  │  (Templates) │  │  (GitOps Config)   │   │
│  └──────────────┘  └──────────────┘  └────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
         │                    │                    │
         │ push               │ sync               │ watch
         ▼                    ▼                    ▼
  ┌─────────────┐      ┌──────────────┐    ┌──────────────┐
  │   GitHub    │      │    ArgoCD    │───▶│  Kubernetes  │
  │   Actions   │      │  (GitOps)    │    │   Cluster    │
  │  (CI/CD)    │      └──────────────┘    │  (Minikube)  │
  └─────────────┘              │            └──────────────┘
         │                     │                    │
         │ build               │ deploy             │ monitor
         ▼                     ▼                    ▼
  ┌─────────────┐      ┌──────────────┐    ┌──────────────┐
  │   Docker    │      │ 3 Namespaces │    │  Prometheus  │
  │    Hub      │      │ dev/stg/prod │    │   Grafana    │
  └─────────────┘      └──────────────┘    └──────────────┘
```

## 📁 Project Structure

```
DevOpsProject/
├── app/
│   ├── app.py                          # Flask application with Prometheus metrics
│   └── requirements.txt                # Python dependencies (Flask, prometheus-client)
├── helm/
│   └── hello-world-app/
│       ├── templates/
│       │   ├── deployment.yaml         # Kubernetes deployment
│       │   ├── service.yaml            # Service (NodePort)
│       │   ├── configmap.yaml          # Configuration
│       │   ├── secret.yaml             # Secrets
│       │   ├── hpa.yaml                # Horizontal Pod Autoscaler
│       │   ├── cronjob.yaml            # Scheduled jobs
│       │   ├── servicemonitor.yaml     # Prometheus metrics scraping
│       │   ├── prometheusrule.yaml     # Alert rules
│       │   └── grafana-dashboard.yaml  # Grafana dashboard
│       ├── values.yaml                 # Default values
│       ├── values-develop.yaml         # Development overrides
│       ├── values-staging.yaml         # Staging overrides
│       ├── values-production.yaml      # Production overrides
│       └── Chart.yaml                  # Helm chart metadata
├── argocd/
│   ├── application-hello-world-develop.yaml      # ArgoCD app for dev
│   ├── application-hello-world-staging.yaml      # ArgoCD app for staging
│   └── application-hello-world-production.yaml   # ArgoCD app for prod
├── scripts/
│   └── generate-traffic.sh             # Traffic generator for testing metrics
├── k8s/                                # Raw Kubernetes manifests (legacy)
├── .github/
│   └── workflows/
│       └── pipeline.yml                # CI/CD pipeline
├── Dockerfile                          # Container image definition
├── docker-compose.yml                  # Local development with Docker Compose
└── README.md                           # This file
```

## 🛠️ Prerequisites

- **Docker** (v20+)
- **Kubernetes CLI** (`kubectl`)
- **Minikube** (for local Kubernetes cluster)
- **Helm** (v3+)
- **ArgoCD CLI** (optional, for easier management)
- **Git**

### Quick Install (macOS)

```bash
# Install Homebrew packages
brew install docker kubectl minikube helm argocd

# Start Minikube with sufficient resources
minikube start --cpus=4 --memory=8192 --driver=docker
```

## 🚀 Quick Start

### Local Development with Docker

```bash
# Build and run with Docker Compose
docker-compose up --build

# Access the application
open http://localhost:5000
```

### Full Production Setup

Follow the complete setup guide below for a production-grade deployment with GitOps and monitoring.

## 📦 Complete Setup Guide

### Step 1: Install Monitoring Stack (Prometheus & Grafana)

```bash
# Add Prometheus community Helm repository
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install kube-prometheus-stack (Prometheus + Grafana + Alertmanager)
helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
  --set prometheus.prometheusSpec.podMonitorSelectorNilUsesHelmValues=false

# Wait for pods to be ready
kubectl wait --for=condition=ready pod -l "release=kube-prometheus-stack" -n monitoring --timeout=300s
```

### Step 2: Install ArgoCD

```bash
# Create namespace and install ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD to be ready
kubectl wait --for=condition=ready pod -l "app.kubernetes.io/name=argocd-server" -n argocd --timeout=300s

# Get initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

### Step 3: Deploy Applications with ArgoCD

```bash
# Apply ArgoCD application manifests
kubectl apply -f argocd/application-hello-world-develop.yaml
kubectl apply -f argocd/application-hello-world-staging.yaml
kubectl apply -f argocd/application-hello-world-production.yaml

# Check ArgoCD application status
kubectl get applications -n argocd
```

**ArgoCD will automatically:**
- Sync applications from Git
- Deploy to respective namespaces (develop/staging/production)
- Monitor for Git changes every 3 minutes
- Self-heal if manual changes are made to the cluster

### Step 4: Build and Push Application Image

```bash
# Use Minikube's Docker daemon
eval $(minikube docker-env)

# Build image with monitoring support
docker build -t amiranissim/hello-world-app:v1.1.0-monitoring .

# Verify image exists
docker images | grep hello-world-app
```

### Step 5: Verify Deployments

```bash
# Check all namespaces
kubectl get pods --all-namespaces | grep hello-world

# Check specific environment
kubectl get all -n hello-world-develop

# View application logs
kubectl logs -n hello-world-develop -l app.kubernetes.io/name=hello-world-app

# Check ArgoCD sync status
kubectl get application hello-world-app-develop -n argocd
```

## 📊 Monitoring & Observability

### Accessing Grafana

```bash
# Port-forward Grafana service
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80

# Get Grafana admin password
kubectl get secret -n monitoring kube-prometheus-stack-grafana \
  -o jsonpath="{.data.admin-password}" | base64 --decode && echo

# Open Grafana in browser
open http://localhost:3000
```

**Login:** `admin` / `<password-from-above>`

**Navigate to:** Dashboards → Search for "Hello World App - Application Metrics"

### Accessing Prometheus

```bash
# Port-forward Prometheus service
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090

# Open Prometheus in browser
open http://localhost:9090
```

**Useful Queries:**
```promql
# Request rate per endpoint
rate(flask_app_request_count_total[5m])

# 95th percentile latency
histogram_quantile(0.95, rate(flask_app_request_latency_seconds_bucket[5m]))

# Error rate percentage
(sum(rate(flask_app_request_count_total{http_status=~"5.."}[5m])) /
 sum(rate(flask_app_request_count_total[5m]))) * 100
```

### Generating Test Traffic

Use the included script to populate metrics for dashboard testing:

```bash
# Generate traffic for 60 seconds in develop environment
./scripts/generate-traffic.sh hello-world-develop 60

# Generate traffic for staging
./scripts/generate-traffic.sh hello-world-staging 120
```

The script will:
- Send requests to all endpoints (/, /hello, /metrics)
- Generate realistic traffic patterns
- Create some 404 errors for testing
- Generate a traffic spike

**Wait 30-60 seconds after running** for metrics to appear in Prometheus and Grafana.

### Viewing Alerts

```bash
# Check alert status in Prometheus
open http://localhost:9090/alerts

# View PrometheusRule resources
kubectl get prometheusrules -n hello-world-develop

# Describe alert rules
kubectl describe prometheusrule hello-world-app-develop -n hello-world-develop
```

**Configured Alerts:**
- **HighErrorRate:** Triggers when 5xx error rate exceeds threshold (env-specific)
- **PodDown:** Fires when pods are unavailable for >1 minute
- **HighLatency:** Warns when p95 latency exceeds threshold (env-specific)
- **FrequentPodRestarts:** Detects container crash loops

### Monitoring by Environment

| Metric | Development | Staging | Production |
|--------|-------------|---------|------------|
| **Error Rate Threshold** | 50% | 10% | 2% |
| **Latency Threshold** | 5s | 2s | 1s |
| **Scrape Interval** | 60s | 30s | 15s |
| **Philosophy** | Lenient for testing | Pre-prod validation | Strict SLAs |

## 🌐 Accessing the Application

### Via Minikube Service

```bash
# Get service URL for develop environment
minikube service hello-world-app-develop -n hello-world-develop --url

# Open in browser
open $(minikube service hello-world-app-develop -n hello-world-develop --url)
```

### Via Port Forward

```bash
# Port-forward to local machine
kubectl port-forward -n hello-world-develop svc/hello-world-app-develop 5000:5000

# Access endpoints
curl http://localhost:5000/           # Hello World!
curl http://localhost:5000/hello      # Greeting with ConfigMap/Secret
curl http://localhost:5000/metrics    # Prometheus metrics
```

### Application Endpoints

- **`/`** - Returns "Hello World!"
- **`/hello`** - Returns greeting from ConfigMap and Secret
- **`/metrics`** - Prometheus metrics endpoint (request count, latency, etc.)

## 🔄 GitOps Workflow

### Making Changes

```bash
# 1. Create feature branch
git checkout -b feature/my-change

# 2. Make changes to code or Helm values
vim app/app.py
vim helm/hello-world-app/values-develop.yaml

# 3. Commit and push
git add .
git commit -m "Update feature X"
git push origin feature/my-change

# 4. Merge to develop branch
git checkout develop
git merge feature/my-change
git push origin develop

# 5. ArgoCD automatically syncs within 3 minutes
kubectl get application hello-world-app-develop -n argocd -w
```

### Promoting to Staging/Production

```bash
# After testing in develop, promote to staging
git checkout staging
git merge develop
git push origin staging

# Monitor staging deployment
kubectl get pods -n hello-world-staging -w

# After staging validation, promote to production
git checkout main
git merge staging
git push origin main

# Monitor production deployment
kubectl get pods -n hello-world-production -w
```

### Manual Sync (Optional)

```bash
# Trigger immediate sync
kubectl patch application hello-world-app-develop -n argocd \
  --type merge -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{}}}'

# Or using ArgoCD CLI
argocd app sync hello-world-app-develop
```

## 🔧 CI/CD Pipeline

GitHub Actions automatically:
- **Lints code** with `pylint` on push/PR
- **Tests** against multiple Python versions
- **Validates** Helm charts
- **Builds** Docker images (on main branch)

View workflow: `.github/workflows/pipeline.yml`

### Triggering a Build

```bash
# Push to trigger CI
git push origin develop

# Check workflow status
gh run list --workflow=pipeline.yml

# View logs
gh run view --log
```

## 🛠️ Troubleshooting

### ArgoCD Not Syncing

```bash
# Check application status
kubectl get application hello-world-app-develop -n argocd -o yaml

# View sync errors
kubectl describe application hello-world-app-develop -n argocd

# Manual refresh
argocd app get hello-world-app-develop --refresh
```

### Metrics Not Appearing

```bash
# Check if ServiceMonitor exists
kubectl get servicemonitor -n hello-world-develop

# Verify Prometheus is scraping
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
# Visit: http://localhost:9090/targets

# Check app metrics endpoint
kubectl exec -n hello-world-develop deploy/hello-world-app-develop -- \
  python -c "import urllib.request; print(urllib.request.urlopen('http://localhost:5000/metrics').read().decode()[:500])"
```

### Dashboard Not Loading

```bash
# Check if dashboard ConfigMap exists
kubectl get configmap -n hello-world-develop -l grafana_dashboard=1

# Restart Grafana to reload dashboards
kubectl rollout restart deployment -n monitoring kube-prometheus-stack-grafana

# Check Grafana logs
kubectl logs -n monitoring -l app.kubernetes.io/name=grafana
```

### Pod Crash Loops

```bash
# View pod logs
kubectl logs -n hello-world-develop -l app.kubernetes.io/name=hello-world-app --tail=100

# Describe pod for events
kubectl describe pod -n hello-world-develop -l app.kubernetes.io/name=hello-world-app

# Check resource limits
kubectl top pod -n hello-world-develop
```

### Minikube Issues

```bash
# Check Minikube status
minikube status

# Restart Minikube
minikube stop && minikube start

# Increase resources
minikube delete
minikube start --cpus=4 --memory=8192 --driver=docker

# Access Minikube Docker daemon
eval $(minikube docker-env)
```

## 📚 Documentation

- **ArgoCD Setup:** See `docs/argocd-setup.md` (to be created)
- **Monitoring Guide:** See `docs/monitoring-guide.md` (to be created)
- **Helm Chart:** See `helm/hello-world-app/README.md`

## 🎓 Learning Outcomes

This project demonstrates:

**✅ Containerization**
- Multi-stage Docker builds
- Image optimization
- Container registries

**✅ Kubernetes**
- Deployments, Services, ConfigMaps, Secrets
- HPA (Horizontal Pod Autoscaling)
- CronJobs for scheduled tasks
- Multi-environment namespaces

**✅ Helm**
- Chart templating
- Values files per environment
- Helm repositories

**✅ GitOps with ArgoCD**
- Declarative deployments
- Auto-sync and self-healing
- Git as source of truth
- Multi-environment management

**✅ Monitoring & Observability**
- Prometheus metrics collection
- Custom application metrics
- Grafana dashboards
- Alert rules and thresholds
- ServiceMonitor CRDs

**✅ CI/CD**
- GitHub Actions workflows
- Automated testing and linting
- Container image builds

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is part of a DevOps course and is for educational purposes.

## 👨‍💻 Author

Nissim Amira - DevOps Course Final Project

---

**Quick Reference Commands:**

```bash
# Access Grafana
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80

# Access Prometheus
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090

# Access ArgoCD
kubectl port-forward -n argocd svc/argocd-server 8080:443

# Generate test traffic
./scripts/generate-traffic.sh hello-world-develop 60

# Check all applications
kubectl get applications -n argocd

# View app logs
kubectl logs -n hello-world-develop -l app.kubernetes.io/name=hello-world-app -f
```