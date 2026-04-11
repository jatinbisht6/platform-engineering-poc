#!/bin/bash

set -e

echo "🚀 Installing Data Platform Components..."

# ---------------------------
# 1️⃣ Deploy Kafka Cluster
# ---------------------------
echo "📦 Deploying Kafka cluster..."

kubectl apply -f platform/kafka-strimzi/kafka-cluster.yaml

echo "⏳ Waiting for Kafka cluster..."
kubectl wait kafka/kafka-cluster \
  --for=condition=Ready \
  --timeout=300s \
  -n kafka || true

# Mapping k3d load balancer port to Kafka's external listener
k3d cluster create --port "30092:30092@loadbalancer"


# ---------------------------
# 2️⃣ Deploy Kafka Connect
# ---------------------------
echo "🔌 Deploying Kafka Connect..."

kubectl apply -f platform/kafka-strimzi/kafka-connect.yaml

kubectl wait kafkaconnect/kafka-connect \
  --for=condition=Ready \
  --timeout=300s \
  -n kafka || true


# ---------------------------
# 3️⃣ Deploy Kafka Connectors
# ---------------------------
echo "🔗 Deploying Kafka Connectors..."

# kubectl apply -f applications/connectors/


# ---------------------------
# 4️⃣ Deploy Kafka Streams Apps
# ---------------------------
echo "🌊 Deploying Kafka Streams applications..."

# kubectl apply -f applications/kstreams/


# ---------------------------
# 5️⃣ Deploy Batch Processing (Airflow / Argo)
# ---------------------------
echo "📊 Deploying Batch Processing..."

# Example (choose one later)
# kubectl apply -f platform/airflow/
# kubectl apply -f platform/argo/


echo "✅ Data Platform setup complete!"