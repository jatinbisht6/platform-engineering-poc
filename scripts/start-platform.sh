#!/bin/bash

# =========================================
# start-platform.sh
# Bootstraps the local single-platform environment
# =========================================

set -euo pipefail

CLUSTER_NAME="platform-cluster"
K3D_CONFIG="infrastructure/k3d/cluster-config.yaml"
KUBECONFIG_FILE="infrastructure/k3d/kube-config.yaml"
# export KUBECONFIG="$KUBECONFIG_FILE"

function ensure_command() {
    local cmd="$1"
    if ! command -v "$cmd" &> /dev/null; then
        echo "❌ Required command '$cmd' is not installed. Please install it and retry."
        exit 1
    fi
}

function add_helm_repo() {
    local name="$1"
    local url="$2"
    if ! helm repo list | awk '{print $1}' | grep -q "^${name}$"; then
        helm repo add "$name" "$url"
    fi
}

function wait_for_deployment() {
    local name="$1"
    local namespace="$2"
    local timeout="120s"
    if [ "$#" -ge 3 ] && [ -n "$3" ]; then
        if [[ "$3" =~ ^[0-9]+$ ]]; then
            timeout="${3}s"
        else
            timeout="$3"
        fi
    fi

    echo "⏳ Waiting for deployment/$name in namespace $namespace..."
    kubectl wait --for=condition=available --timeout="$timeout" deployment/$name -n "$namespace"
}

# ---------------------------
# 1️⃣ Cluster Creation
# ---------------------------

echo "✅ Creating k3d cluster..."
if k3d cluster list | grep -q "$CLUSTER_NAME"; then
    echo "⚠️ Cluster $CLUSTER_NAME already exists, deleting it first..."
    k3d cluster delete "$CLUSTER_NAME"
fi

k3d cluster create --config "$K3D_CONFIG" --api-port 6550
echo "✅ k3d cluster created"

# ---------------------------
# 2️⃣ Configure kubeconfig
# ---------------------------

echo "✅ Writing kubeconfig for $CLUSTER_NAME to $KUBECONFIG_FILE..."
k3d kubeconfig get "$CLUSTER_NAME" > "$KUBECONFIG_FILE"

# Fix kubeconfig to use localhost instead of host.docker.internal (for Windows/WSL2 compatibility)
if command -v sed &> /dev/null; then
    sed -i 's/host\.docker\.internal/127.0.0.1/g' "$KUBECONFIG_FILE"
fi

cp infrastructure/k3d/kube-config.yaml ~/.kube/config
echo "✅ Using kubeconfig: $KUBECONFIG_FILE"
kubectl config view

# Wait for API server to be ready
echo "⏳ Waiting for API server to be ready..."
for i in {1..60}; do
    if kubectl cluster-info &>/dev/null; then
        echo "✅ API server is ready"
        break
    fi
    echo "⏳ Attempt $i/60: Waiting for API server..."
    sleep 2
done

echo "✅ kubeconfig configured"

# ---------------------------
# 3️⃣ Create Namespaces
# ---------------------------

echo "✅ Creating namespaces..."
if [ -f "infrastructure/namespaces.yaml" ]; then
    kubectl apply -f infrastructure/namespaces.yaml
else
    kubectl create namespace platform-system || true
    kubectl create namespace kafka || true
    kubectl create namespace data-platform || true
fi

# ---------------------------
# 4️⃣ Add Helm Repositories
# ---------------------------

echo "✅ Adding Helm repositories..."
ensure_command helm
add_helm_repo ingress-nginx https://kubernetes.github.io/ingress-nginx
add_helm_repo prometheus-community https://prometheus-community.github.io/helm-charts
add_helm_repo grafana https://grafana.github.io/helm-charts
add_helm_repo strimzi https://strimzi.io/charts/
add_helm_repo rancher-latest https://releases.rancher.com/server-charts/latest
add_helm_repo rancher-stable https://releases.rancher.com/server-charts/stable
add_helm_repo jetstack https://charts.jetstack.io
helm repo update

# ---------------------------
# 4.5️⃣ Configure Local Path Provisioner
# ---------------------------

echo "✅ Configuring Local Path Provisioner..."
kubectl patch configmap local-path-config -n kube-system --type merge -p '{"data":{"config.json":"{\"nodePathMap\":[{\"node\":\"DEFAULT_PATH_FOR_NON_LISTED_NODES\",\"paths\":[\"/data\"]}]}"}}'
kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

# ---------------------------
# 5️⃣ Install NGINX Ingress
# ---------------------------

echo "✅ Installing NGINX Ingress..."
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
    -f platform/ingress/values.yaml \
    --namespace platform-system \
    --create-namespace
wait_for_deployment ingress-nginx-controller platform-system

# ---------------------------
# 6️⃣ Install cert-manager
# ---------------------------

echo "✅ Installing cert-manager..."
helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace platform-system \
  --create-namespace \
  --version v1.14.5 \
  --set installCRDs=true \
  --set global.leaderElection.namespace=platform-system
wait_for_deployment cert-manager platform-system
wait_for_deployment cert-manager-cainjector platform-system
wait_for_deployment cert-manager-webhook platform-system

# ---------------------------
# 7️⃣ Install Prometheus
# ---------------------------

# echo "✅ Installing Prometheus..."
# helm upgrade --install prometheus prometheus-community/prometheus \
#     -f platform/observability/prometheus/values.yaml \
#     --namespace platform-system \
#     --create-namespace
# wait_for_deployment prometheus-server platform-system 300

# ---------------------------
# 8️⃣ Install Grafana
# ---------------------------

# echo "✅ Installing Grafana..."
# helm upgrade --install grafana grafana/grafana \
#     -f platform/observability/grafana/values.yaml \
#     --namespace platform-system \
#     --create-namespace
# wait_for_deployment grafana platform-system 1200

# ---------------------------
# 9️⃣ Install Kafka Strimzi Operator
# ---------------------------

echo "✅ Installing Kafka Strimzi Operator..."
helm upgrade --install kafka-operator strimzi/strimzi-kafka-operator \
    -f platform/kafka-strimzi/values.yaml \
    --namespace kafka \
    --create-namespace
wait_for_deployment strimzi-cluster-operator kafka 1200

# ---------------------------
# 🔟 Install Rancher
# ---------------------------

# echo "✅ Installing Rancher..."
# helm upgrade --install rancher rancher-latest/rancher \
#     -f platform/rancher/values.yaml \
#     --namespace platform-system \
#     --create-namespace
# wait_for_deployment rancher platform-system 1200

# ---------------------------
# 1️⃣1️⃣ Output Information
# ---------------------------

# ---------------------------
# 1️⃣1️⃣ Output Information
# ---------------------------

echo "✅ Platform setup complete!"
echo "----------------------------------------"
echo "Grafana: http://localhost:3000"
echo "Prometheus: http://localhost:9090"
echo "Rancher: https://localhost:9443"
echo "Kafka External: localhost:9092"
echo "----------------------------------------"
echo "Note: Use 'kubectl get pods -n platform-system' to verify component readiness."

# ---------------------------
# 1️⃣2️⃣ Install Data Platform
# ---------------------------

echo ""
echo "🚀 Starting Data Platform installation..."
bash ./scripts/install-data-platform.sh
echo "✅ Complete platform setup finished!"