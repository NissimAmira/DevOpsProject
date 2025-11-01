# ArgoCD Setup and Configuration Guide

This guide covers the complete setup and usage of ArgoCD for GitOps-based deployment management in the Hello World Flask application project.

## Table of Contents

- [What is ArgoCD?](#what-is-argocd)
- [Installation](#installation)
- [Configuration](#configuration)
- [Application Management](#application-management)
- [GitOps Workflow](#gitops-workflow)
- [Troubleshooting](#troubleshooting)

## What is ArgoCD?

ArgoCD is a **declarative, GitOps continuous delivery tool** for Kubernetes. It:

- **Monitors Git repositories** for changes to Kubernetes manifests
- **Automatically syncs** desired state (Git) with actual state (cluster)
- **Self-heals** by reverting manual cluster changes
- **Provides visibility** into deployment status and history

### Key Concepts

**Application**: A group of Kubernetes resources defined in Git
**Project**: Logical grouping of applications
**Sync**: Process of applying Git state to cluster
**Sync Policy**: Rules for automatic vs manual sync
**Health**: Whether deployed resources are running correctly

## Installation

### Step 1: Install ArgoCD in Kubernetes

```bash
# Create argocd namespace
kubectl create namespace argocd

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for pods to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s
```

### Step 2: Install ArgoCD CLI (Optional but Recommended)

**macOS:**
```bash
brew install argocd
```

**Linux:**
```bash
curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
chmod +x /usr/local/bin/argocd
```

### Step 3: Access ArgoCD UI

```bash
# Port-forward the ArgoCD server
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Get the initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d && echo
```

**Access:** https://localhost:8080
**Username:** `admin`
**Password:** (from command above)

### Step 4: Login with CLI

```bash
# Login to ArgoCD
argocd login localhost:8080

# Change password (recommended)
argocd account update-password
```

## Configuration

### Project Structure

Our ArgoCD setup uses **one Application per environment**:

```
argocd/
├── application-hello-world-develop.yaml     # Dev environment
├── application-hello-world-staging.yaml     # Staging environment
└── application-hello-world-production.yaml  # Production environment
```

### Application Manifest Breakdown

**Example: `application-hello-world-develop.yaml`**

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: hello-world-app-develop
  namespace: argocd           # ArgoCD watches this namespace
spec:
  project: default            # ArgoCD project (can create custom projects)

  source:
    repoURL: 'https://github.com/NissimAmira/DevOpsProject.git'
    targetRevision: develop   # Git branch to track
    path: helm/hello-world-app
    helm:
      valueFiles:
        - values-develop.yaml # Environment-specific overrides

  destination:
    server: https://kubernetes.default.svc  # Target cluster
    namespace: hello-world-develop          # Target namespace

  syncPolicy:
    automated:
      prune: true             # Delete resources removed from Git
      selfHeal: true          # Revert manual changes
    syncOptions:
      - CreateNamespace=true  # Auto-create namespace if missing
```

### Key Configuration Options

#### Automated Sync

```yaml
syncPolicy:
  automated:
    prune: true      # Remove K8s resources deleted from Git
    selfHeal: true   # Auto-sync when cluster state drifts
```

**When to use:**
- ✅ Development environments (fast feedback)
- ✅ Staging (pre-production testing)
- ⚠️ Production (with proper testing in lower envs)

#### Manual Sync

```yaml
syncPolicy: {}  # No automated section = manual sync only
```

**When to use:**
- ✅ Production (controlled deployments)
- ✅ Critical infrastructure
- ✅ When you need approval gates

#### Sync Options

```yaml
syncOptions:
  - CreateNamespace=true    # Auto-create target namespace
  - PruneLast=true          # Delete resources after new ones are healthy
  - ApplyOutOfSyncOnly=true # Only sync resources that changed
```

### Multi-Environment Setup

We use **branch-based environments**:

| Environment | Git Branch | Namespace | Sync Policy |
|-------------|------------|-----------|-------------|
| Development | `develop` | `hello-world-develop` | Auto (prune + selfHeal) |
| Staging | `staging` | `hello-world-staging` | Auto (prune + selfHeal) |
| Production | `main` | `hello-world-production` | Auto (prune + selfHeal) |

**Promotion Workflow:**
```
develop branch → staging branch → main branch
     ↓               ↓                ↓
   Dev Env      Staging Env      Prod Env
```

## Application Management

### Deploy Applications

```bash
# Deploy all environments
kubectl apply -f argocd/application-hello-world-develop.yaml
kubectl apply -f argocd/application-hello-world-staging.yaml
kubectl apply -f argocd/application-hello-world-production.yaml

# Verify applications were created
kubectl get applications -n argocd
```

**Expected output:**
```
NAME                         SYNC STATUS   HEALTH STATUS
hello-world-app-develop      Synced        Healthy
hello-world-app-staging      Synced        Healthy
hello-world-app-production   Synced        Healthy
```

### View Application Status

**Using kubectl:**
```bash
# Get application status
kubectl get application hello-world-app-develop -n argocd

# Detailed view
kubectl describe application hello-world-app-develop -n argocd

# JSON output for scripting
kubectl get application hello-world-app-develop -n argocd -o json
```

**Using ArgoCD CLI:**
```bash
# List all applications
argocd app list

# Get application details
argocd app get hello-world-app-develop

# Show deployment history
argocd app history hello-world-app-develop
```

### Manual Sync

**Using kubectl:**
```bash
# Trigger sync via patch
kubectl patch application hello-world-app-develop -n argocd \
  --type merge \
  --patch '{"operation": {"initiatedBy": {"username": "admin"}, "sync": {}}}'
```

**Using ArgoCD CLI:**
```bash
# Sync application
argocd app sync hello-world-app-develop

# Sync and wait for completion
argocd app sync hello-world-app-develop --wait

# Sync specific resource
argocd app sync hello-world-app-develop --resource Deployment:hello-world-app-develop
```

### Rollback

```bash
# View deployment history
argocd app history hello-world-app-develop

# Rollback to specific revision
argocd app rollback hello-world-app-develop <REVISION-ID>

# Rollback to previous version
argocd app rollback hello-world-app-develop
```

### Delete Application

```bash
# Delete ArgoCD application (keeps K8s resources)
argocd app delete hello-world-app-develop

# Delete application AND all deployed resources
argocd app delete hello-world-app-develop --cascade
```

## GitOps Workflow

### Making Changes

#### 1. **Update Code or Configuration**

```bash
# Checkout feature branch
git checkout -b feature/update-replicas

# Modify Helm values
vim helm/hello-world-app/values-develop.yaml

# Change replica count
# replicaCount: 1 → replicaCount: 3
```

#### 2. **Commit and Push**

```bash
git add helm/hello-world-app/values-develop.yaml
git commit -m "Scale develop environment to 3 replicas"
git push origin feature/update-replicas
```

#### 3. **Merge to Target Branch**

```bash
# Create PR and merge, or merge directly
git checkout develop
git merge feature/update-replicas
git push origin develop
```

#### 4. **ArgoCD Auto-Syncs**

ArgoCD polls Git every **3 minutes** by default. It will:
1. Detect the change
2. Compare desired state (Git) vs actual state (cluster)
3. Sync the difference
4. Update application status

**Monitor sync:**
```bash
# Watch application status
kubectl get application hello-world-app-develop -n argocd -w

# View sync logs
argocd app logs hello-world-app-develop --follow
```

### Environment Promotion

```bash
# Test in develop
git push origin develop
# Wait for ArgoCD sync, validate in dev namespace

# Promote to staging
git checkout staging
git merge develop
git push origin staging
# Wait for ArgoCD sync, validate in staging namespace

# Promote to production
git checkout main
git merge staging
git push origin main
# Wait for ArgoCD sync, validate in production namespace
```

## Troubleshooting

### Application Stuck in "OutOfSync"

```bash
# Check sync status
argocd app get hello-world-app-develop

# View differences
argocd app diff hello-world-app-develop

# Force sync
argocd app sync hello-world-app-develop --force
```

### Application Shows "Degraded"

```bash
# Check resource health
kubectl get pods -n hello-world-develop

# View application events
kubectl describe application hello-world-app-develop -n argocd

# Check pod logs
kubectl logs -n hello-world-develop -l app.kubernetes.io/name=hello-world-app
```

### Sync Policy Not Working

```bash
# Verify automated sync is enabled
kubectl get application hello-world-app-develop -n argocd -o yaml | grep -A 5 syncPolicy

# Check ArgoCD controller logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller --tail=100

# Refresh application
argocd app get hello-world-app-develop --refresh
```

### Application Not Detecting Git Changes

```bash
# Check repository connection
argocd repo list

# Force refresh repository cache
argocd app get hello-world-app-develop --refresh --hard-refresh

# Check polling interval (default: 3 minutes)
kubectl get configmap argocd-cm -n argocd -o yaml | grep timeout
```

### Reset Admin Password

```bash
# Delete the secret (ArgoCD will generate new password)
kubectl delete secret argocd-initial-admin-secret -n argocd

# Get new password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d && echo
```

## Best Practices

### ✅ Do

- Use **automated sync** for non-production environments
- Enable **selfHeal** to prevent configuration drift
- Use **branch-based environments** (develop → staging → main)
- Create **separate ArgoCD Applications** per environment
- Use **Helm value files** for environment-specific configuration
- Store **secrets in Kubernetes Secrets**, not in Git
- Monitor **ArgoCD notifications** for sync failures

### ❌ Don't

- Don't manually modify resources managed by ArgoCD (will be reverted)
- Don't commit secrets to Git
- Don't use the same Application for multiple environments
- Don't skip staging before production promotion
- Don't ignore sync errors (investigate immediately)

## Advanced Configuration

### Custom Sync Waves

Use sync waves to control deployment order:

```yaml
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "1"  # Deploy after wave 0
```

### Pre-Sync Hooks

Run jobs before deployment:

```yaml
metadata:
  annotations:
    argocd.argoproj.io/hook: PreSync
```

### Health Checks

Custom health assessments for CRDs:

```yaml
spec:
  ignoreDifferences:
  - group: apps
    kind: Deployment
    jsonPointers:
    - /spec/replicas  # Ignore HPA-managed replicas
```

## References

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [ArgoCD Best Practices](https://argo-cd.readthedocs.io/en/stable/user-guide/best_practices/)
- [GitOps Principles](https://opengitops.dev/)

---

**Next Steps:**
- Review [Monitoring Guide](./monitoring-guide.md) for Prometheus/Grafana setup
- Explore [Main README](../README.md) for full project documentation