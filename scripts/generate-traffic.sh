#!/bin/bash

# Traffic Generation Script for Monitoring Dashboard Testing
# This script generates various types of HTTP traffic to populate Prometheus metrics and Grafana dashboards

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE=${1:-"hello-world-develop"}
SERVICE_NAME="hello-world-app"
DURATION=${2:-60}  # Duration in seconds

echo -e "${GREEN}=== Traffic Generator for Hello World App ===${NC}"
echo "Namespace: $NAMESPACE"
echo "Duration: ${DURATION}s"
echo ""

# Check if namespace exists
if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
    echo -e "${RED}Error: Namespace '$NAMESPACE' not found${NC}"
    echo "Available namespaces:"
    kubectl get namespaces | grep hello-world
    exit 1
fi

# Get service endpoint
SERVICE_FULL_NAME="${SERVICE_NAME}"
if [[ "$NAMESPACE" != "default" ]]; then
    SERVICE_FULL_NAME="${SERVICE_NAME}-${NAMESPACE##*-}"
fi

echo -e "${YELLOW}Starting traffic generation...${NC}"
echo "Press Ctrl+C to stop"
echo ""

# Function to generate normal traffic
generate_traffic() {
    local endpoint=$1
    local expected_status=$2

    kubectl run -n "$NAMESPACE" traffic-gen-$$ \
        --image=curlimages/curl:latest \
        --rm -i --restart=Never \
        --command -- sh -c "
            curl -s -o /dev/null -w 'Status: %{http_code}\n' \
            http://${SERVICE_FULL_NAME}:5000${endpoint}
        " 2>/dev/null || true
}

# Function to generate sustained load
generate_load() {
    echo -e "${GREEN}Generating normal traffic patterns...${NC}"

    local end_time=$((SECONDS + DURATION))
    local request_count=0

    while [ $SECONDS -lt $end_time ]; do
        # 70% to index, 20% to hello, 10% to metrics
        local rand=$((RANDOM % 10))

        if [ $rand -lt 7 ]; then
            endpoint="/"
        elif [ $rand -lt 9 ]; then
            endpoint="/hello"
        else
            endpoint="/metrics"
        fi

        # Send request from within cluster
        kubectl run -n "$NAMESPACE" "traffic-gen-$$-$request_count" \
            --image=curlimages/curl:latest \
            --rm -i --restart=Never \
            --command -- sh -c \
            "curl -s http://${SERVICE_FULL_NAME}:5000${endpoint} > /dev/null" \
            2>/dev/null &

        request_count=$((request_count + 1))

        # Progress indicator
        if [ $((request_count % 10)) -eq 0 ]; then
            echo -e "${GREEN}✓${NC} Sent $request_count requests ($(($end_time - SECONDS))s remaining)"
        fi

        # Random delay between 0.5-2 seconds
        sleep $(awk "BEGIN {print (0.5 + rand() * 1.5)}")
    done

    echo -e "${GREEN}Total requests sent: $request_count${NC}"
}

# Function to generate error traffic
generate_errors() {
    echo ""
    echo -e "${YELLOW}Generating error traffic (404s)...${NC}"

    for i in {1..5}; do
        kubectl run -n "$NAMESPACE" "error-gen-$$-$i" \
            --image=curlimages/curl:latest \
            --rm -i --restart=Never \
            --command -- sh -c \
            "curl -s http://${SERVICE_FULL_NAME}:5000/nonexistent > /dev/null" \
            2>/dev/null &
        echo -e "${YELLOW}✓${NC} Error request $i/5 sent"
        sleep 1
    done
}

# Function to generate spike
generate_spike() {
    echo ""
    echo -e "${YELLOW}Generating traffic spike...${NC}"

    for i in {1..20}; do
        kubectl run -n "$NAMESPACE" "spike-gen-$$-$i" \
            --image=curlimages/curl:latest \
            --rm -i --restart=Never \
            --command -- sh -c \
            "curl -s http://${SERVICE_FULL_NAME}:5000/ > /dev/null" \
            2>/dev/null &
    done

    echo -e "${GREEN}✓${NC} Spike of 20 concurrent requests sent"
}

# Main execution
trap 'echo -e "\n${YELLOW}Traffic generation stopped${NC}"; exit 0' INT

# Generate load
generate_load

# Optional: Generate some errors
generate_errors

# Optional: Generate a spike
generate_spike

echo ""
echo -e "${GREEN}=== Traffic Generation Complete ===${NC}"
echo ""
echo "Next steps:"
echo "1. Wait 30-60 seconds for Prometheus to scrape metrics"
echo "2. Open Grafana: kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80"
echo "3. View dashboard: http://localhost:3000 (admin / <password>)"
echo "4. Open Prometheus: kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090"
echo "5. Query metrics: rate(flask_app_request_count_total[5m])"
