# DevOps Project

A simple Flask web application containerized with Docker and deployable on Kubernetes.

## Project Structure

```
DevOpsProject/
├── Dockerfile
├── docker-compose.yml
├── README.md
├── app/
│   ├── app.py
│   └── requirements.txt
└── k8s/
    ├── flask-app-config-map.yaml
    ├── flask-app-cronjob.yaml
    ├── flask-app-deployment.yaml
    ├── flask-app-hpa.yaml
    ├── flask-app-secret.yaml
    └── flask-app-service.yaml
```

## Prerequisites

- Docker
- Docker Compose (optional, for easier management)
- Kubernetes (kubectl)
- Minikube (for local Kubernetes development)

## Building and Running the Docker Container

### Method 1: Using Docker Commands

1. **Build the Docker image:**
   ```bash
   docker build -t flask-app .
   ```

2. **Run the container:**
   ```bash
   docker run -p 5000:5000 flask-app
   ```

3. **Access the application:**
   Open your browser and go to `http://localhost:5000`

### Method 2: Using Docker Compose

1. **Build and run with Docker Compose:**
   ```bash
   docker-compose up --build
   ```

2. **Run in detached mode (background):**
   ```bash
   docker-compose up -d --build
   ```

3. **Stop the application:**
   ```bash
   docker-compose down
   ```

4. **Access the application:**
   Open your browser and go to `http://localhost:5000`

## Kubernetes Deployment

### Setting up Minikube

1. **Start Minikube:**
   ```bash
   minikube start
   ```

2. **Verify cluster status:**
   ```bash
   kubectl cluster-info
   ```

### Deploying to Kubernetes

1. **Build and push Docker image to Minikube:**
   ```bash
   eval $(minikube docker-env)
   docker build -t flask-app .
   ```

2. **Deploy all Kubernetes resources:**
   ```bash
   kubectl apply -f k8s/
   ```

3. **Check deployment status:**
   ```bash
   kubectl get deployments
   kubectl get pods
   kubectl get services
   ```

4. **Access the application:**
   ```bash
   minikube service flask-app --url
   ```
   Then open the returned URL in your browser.

### Kubernetes Resources

- **Deployment** (`flask-app-deployment.yaml`): Manages application pods
- **Service** (`flask-app-service.yaml`): Exposes the application
- **ConfigMap** (`flask-app-config-map.yaml`): Configuration data
- **Secret** (`flask-app-secret.yaml`): Sensitive configuration
- **HPA** (`flask-app-hpa.yaml`): Horizontal Pod Autoscaler
- **CronJob** (`flask-app-cronjob.yaml`): Scheduled tasks

### Managing the Deployment

1. **Scale the deployment:**
   ```bash
   kubectl scale deployment flask-app --replicas=3
   ```

2. **Update deployment:**
   ```bash
   kubectl rollout restart deployment/flask-app
   ```

3. **View logs:**
   ```bash
   kubectl logs -l app=flask-app
   ```

4. **Delete deployment:**
   ```bash
   kubectl delete -f k8s/
   ```

## Development

The application is a simple Flask web server with the following endpoints:

### Application Details

- **Framework:** Flask
- **Port:** 5000
- **Endpoints:** 
  - `/` returns "Hello World!"
  - `/hello` returns greeting with environment variables

### Docker Configuration

- **Base Image:** python:3.12-slim
- **Working Directory:** /app
- **Exposed Port:** 5000
- **Dependencies:** Flask (from requirements.txt)

## Troubleshooting

### Docker Issues
- Ensure Docker is running before executing any Docker commands
- Use `docker logs <container-id>` to view container logs if the application doesn't start properly

### Kubernetes Issues
- Check cluster status: `kubectl cluster-info`
- View pod logs: `kubectl logs <pod-name>`
- Describe resources for details: `kubectl describe deployment flask-app`
- Ensure Minikube is running: `minikube status`