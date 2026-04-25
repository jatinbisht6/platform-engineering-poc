#!/bin/bash

set -euo pipefail

NAMESPACE="kafka"

echo "🚀 Installing Data Platform Components..."

# ---------------------------
# Utility Functions
# ---------------------------

resource_exists() {
  kubectl get "$1" "$2" -n "$NAMESPACE" &>/dev/null
}

wait_for_kafka() {
  kubectl wait kafka/"$1" \
    --for=condition=Ready \
    --timeout=300s \
    -n "$NAMESPACE"
}

wait_for_deployment() {
  kubectl wait deployment/"$1" \
    --for=condition=Available \
    --timeout=300s \
    -n "$NAMESPACE"
}

# ---------------------------
# 1️⃣ Kafka Cluster
# ---------------------------

echo "📦 Checking Kafka cluster..."

if resource_exists kafka kafka-cluster; then
  echo "🔍 Kafka cluster exists. Checking status..."

  if wait_for_kafka kafka-cluster; then
    echo "✅ Kafka cluster already running. Skipping deployment."
  else
    echo "⚠️ Kafka exists but not ready. Re-applying..."
    kubectl apply -f platform/kafka-strimzi/kafka-cluster.yaml
  fi

else
  echo "🚀 Deploying Kafka cluster..."
  kubectl apply -f platform/kafka-strimzi/kafka-cluster.yaml

  echo "⏳ Waiting for Kafka cluster..."
  wait_for_kafka kafka-cluster || echo "⚠️ Kafka still initializing..."
fi

# ---------------------------
# 2️⃣ Kafka Connect
# ---------------------------

echo "🔌 Checking Kafka Connect..."

if resource_exists deployment kafka-connect; then
  echo "🔍 Kafka Connect exists. Checking status..."

  if wait_for_deployment kafka-connect; then
    echo "✅ Kafka Connect already running. Skipping deployment."
  else
    echo "⚠️ Kafka Connect exists but not ready. Re-applying..."
    kubectl apply -f platform/kafka-strimzi/kafka-connect.yaml
  fi

else
  echo "🚀 Deploying Kafka Connect..."
  kubectl apply -f platform/kafka-strimzi/kafka-connect.yaml

  echo "⏳ Waiting for Kafka Connect..."
  wait_for_deployment kafka-connect || echo "⚠️ Kafka Connect still initializing..."
fi

# ---------------------------
# 3️⃣ Kafka Connectors
# ---------------------------

echo "🔗 Deploying Kafka Connectors (if needed)..."
# Add similar logic later

# ---------------------------
# 4️⃣ Kafka Streams Apps
# ---------------------------

echo "🌊 Deploying Kafka Streams applications (if needed)..."
# Add similar logic later

# ---------------------------
# 5️⃣ Batch Processing
# ---------------------------

echo "📊 Deploying Batch Processing (if needed)..."
# Add similar logic later

echo "✅ Data Platform setup complete!"