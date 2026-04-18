#!/bin/bash

set -e

# Set kubeconfig
export KUBECONFIG="${KUBECONFIG:-./scripts/.k3d-platform-cluster-config}"

echo "🚀 Deploying Remaining Platform Components..."
echo ""

# ---------------------------
# 1️⃣ Deploy Grafana
# ---------------------------
echo "📊 Installing Grafana..."

helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

helm upgrade --install grafana grafana/grafana \
  --namespace platform-system \
  --values platform/observability/grafana/values.yaml \
  --wait \
  --timeout 5m

echo "✅ Grafana deployed"
echo "   Access at: http://localhost:3000"
echo "   Default credentials: admin / GrafanaDevPassword123!"
echo ""

# ---------------------------
# 2️⃣ Deploy Rancher
# ---------------------------
echo "🐋 Installing Rancher..."

helm repo add rancher-latest https://releases.rancher.com/server-charts/latest
helm repo update

# Create rancher namespace if not exists
kubectl create namespace cattle-system --dry-run=client -o yaml | kubectl apply -f -

# Install cert-manager for Rancher (if not already installed)
helm upgrade --install rancher rancher-latest/rancher \
  --namespace cattle-system \
  --set hostname=localhost:9443 \
  --set tls=self-signed \
  --set bootstrapPassword=RancherAdminPassword123 \
  --wait \
  --timeout 5m

echo "✅ Rancher deployed"
echo "   Access at: https://localhost:9443"
echo "   Default credentials: admin / RancherAdminPassword123"
echo ""

# ---------------------------
# 3️⃣ Deploy Kafka Strimzi Operator
# ---------------------------
echo "🔌 Installing Kafka Strimzi Operator..."

# Add Strimzi Helm repo
helm repo add strimzi https://strimzi.io/charts
helm repo update

# Create kafka namespace
kubectl create namespace kafka --dry-run=client -o yaml | kubectl apply -f -

# Install Strimzi operator
helm upgrade --install strimzi-operator strimzi/strimzi-kafka-operator \
  --namespace kafka \
  --wait \
  --timeout 5m

echo "✅ Strimzi Operator deployed"
echo ""

# ---------------------------
# 4️⃣ Deploy Kafka Cluster
# ---------------------------
echo "📦 Deploying Kafka Cluster..."

kubectl apply -f platform/kafka-strimzi/kafka-cluster.yaml

# Wait for Kafka cluster to be ready
echo "⏳ Waiting for Kafka cluster to be ready (this may take a few minutes)..."
kubectl wait kafka/kafka-cluster \
  --for=condition=Ready \
  --timeout=300s \
  -n kafka || echo "⚠️  Kafka cluster creation in progress, continue monitoring..."

echo "✅ Kafka cluster deployment initiated"
echo ""

# ---------------------------
# 5️⃣ Deploy Kafka Connect
# ---------------------------
echo "🔗 Deploying Kafka Connect..."

kubectl apply -f platform/kafka-strimzi/kafka-connect.yaml

echo "✅ Kafka Connect deployment initiated"
echo ""

# ---------------------------
# Summary
# ---------------------------
echo "═══════════════════════════════════════════════════════"
echo "✅ All remaining components deployed!"
echo "═══════════════════════════════════════════════════════"
echo ""
echo "📊 Grafana:"
echo "   URL: http://localhost:3000"
echo "   User: admin | Pass: GrafanaDevPassword123!"
echo ""
echo "🐋 Rancher:"
echo "   URL: https://localhost:9443"
echo "   User: admin | Pass: RancherAdminPassword123"
echo ""
echo "📦 Kafka:"
echo "   Bootstrap Server: kafka-cluster-kafka-bootstrap.kafka.svc.cluster.local:9092"
echo "   External: localhost:9092"
echo ""
echo "Verify deployment:"
echo "   bash scripts/verify-platform.sh"
echo ""
