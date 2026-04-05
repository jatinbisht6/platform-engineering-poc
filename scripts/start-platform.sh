#!/bin/bash

# =========================================
# start-platform.sh
# Bootstraps the local single-platform environment
# =========================================

set -e  # Exit on any error

# ---------------------------
# 1️⃣ Cluster Creation
# ---------------------------
CLUSTER_NAME="platform-cluster"
K3D_CONFIG="infrastructure/k3d/cluster-config.yaml"

echo "✅ Creating k3d cluster..."
# Delete existing cluster if it exists
if k3d cluster list | grep -q "$CLUSTER_NAME"; then
    echo "⚠️ Cluster $CLUSTER_NAME already exists, deleting it first..."
    k3d cluster delete "$CLUSTER_NAME"
fi

k3d cluster create --config "$K3D_CONFIG"
echo "✅ k3d cluster created"

# ---------------------------
# 2️⃣ Set kubeconfig
# ---------------------------
echo "✅ Setting kubeconfig for $CLUSTER_NAME..."
export KUBECONFIG=$(k3d kubeconfig get $CLUSTER_NAME)

# Optional: merge into default kubeconfig (uncomment if needed)
kubectl config view --raw > ~/.kube/config

kubectl cluster-info
echo "✅ kubeconfig set for $CLUSTER_NAME"

# ---------------------------
# 3️⃣ Create Namespaces
# ---------------------------
echo "✅ Creating namespaces..."
kubectl create namespace platform-system || true
kubectl create namespace kafka || true
kubectl create namespace data-platform || true

# ---------------------------
# 4️⃣ Add Helm Repositories
# ---------------------------
echo "✅ Adding Helm repositories..."
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add strimzi https://strimzi.io/charts/
helm repo add rancher-latest https://releases.rancher.com/server-charts/latest
helm repo update

# ---------------------------
# 5️⃣ Install NGINX Ingress
# ---------------------------
echo "✅ Installing NGINX Ingress..."
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
    -f platform/ingress/values.yaml \
    --namespace platform-system --create-namespace

# ---------------------------
# 6️⃣ Install Prometheus
# ---------------------------
echo "✅ Installing Prometheus..."
helm upgrade --install prometheus prometheus-community/prometheus \
    -f platform/observability/prometheus/values.yaml \
    --namespace platform-system

# ---------------------------
# 7️⃣ Install Grafana
# ---------------------------
echo "✅ Installing Grafana..."
helm upgrade --install grafana grafana/grafana \
    -f platform/observability/grafana/values.yaml \
    --namespace platform-system

# ---------------------------
# 8️⃣ Install Kafka Strimzi Operator
# ---------------------------
echo "✅ Installing Kafka Strimzi Operator..."
helm upgrade --install kafka-operator strimzi/strimzi-kafka-operator \
    -f platform/kafka-strimzi/values.yaml \
    --namespace kafka --create-namespace

# ---------------------------
# 9️⃣ Install Rancher
# ---------------------------
echo "✅ Installing Rancher..."
helm upgrade --install rancher rancher-latest/rancher \
    -f platform/rancher/values.yaml \
    --namespace platform-system

# ---------------------------
# 10️⃣ Output Information
# ---------------------------
echo "✅ Platform setup complete!"
echo "----------------------------------------"
echo "Grafana: http://localhost:3000 (Check NodePort in 'platform-system' namespace)"
echo "Prometheus: http://localhost:9090"
echo "Rancher: https://localhost:9443"
echo "Kafka NodePort: 9092 (Check in 'kafka' namespace)"
echo "----------------------------------------"
✅ Key Features of This Script