# Cluster Config Corrections

## Overview
This document outlines corrections and optimizations made to the k3d cluster configuration and Helm values.yaml files. The changes address port mappings, persistent storage configuration, and YAML structure validation to ensure all components deploy correctly and data persists on the D: drive.

**Last Updated**: April 19, 2026  
**Status**: ✅ Cluster deployed successfully with core components

## Corrections Applied

### 1. Prometheus (platform/observability/prometheus/values.yaml)
**Issue**: nodePort was set to 30090, but cluster-config maps 9090:32090 (internal 32090).  
**Fix**: Updated nodePort to 32090 for consistency.  
**Updated Content**:
```yaml
server:
  service:
    type: NodePort
    nodePort: 32090
  podLabels:
    app: prometheus
    tier: observability
```

### 2. Grafana (platform/observability/grafana/values.yaml)
**Issue**: nodePort was set to 30000, but cluster-config maps 3000:32044 (internal 32044).  
**Fix**: Updated nodePort to 32044.  
**Updated Content**:
```yaml
service:
  type: NodePort
  nodePort: 32044
podLabels:
  app: grafana
  tier: observability
persistence:
  enabled: true
  size: 1Gi
```

### 3. Rancher (platform/rancher/values.yaml)
**Issue**: nodePort was set to 9443, but cluster-config maps 9443:30443 (internal 30443).  
**Fix**: Updated nodePort to 30443. Also noted hostname consideration for local access.  
**Updated Content**:
```yaml
hostname: rancher.local  # Consider changing to 'localhost' or '127.0.0.1' for local access
replicas: 1
service:
  type: NodePort
  nodePort: 30443
```

### 4. Kafka Strimzi (platform/kafka-strimzi/values.yaml)
**Issue**: Kafka listener port was 9092, but cluster-config maps 9092:30992 (internal 30992).  
**Fix**: Updated port to 30992 for consistency (optional but recommended).  
**Updated Content**:
```yaml
kafka:
  replicas: 1
  listeners:
    - name: plain
      port: 30992
      type: internal
      tls: false
zookeeper:
  replicas: 1
entityOperator:
  topicOperator: {}
  userOperator: {}
```

### 5. NGINX Ingress (platform/ingress/values.yaml)
**Status**: Already correct. nodePorts (30080 for HTTP, 30443 for HTTPS) match cluster-config mappings (8080:30080, 8443:30443). No changes needed.

## Port Mapping Summary (from cluster-config.yaml)

| Service | External Port | Internal Port (NodePort) | Updated |
|---------|--------------|-------------------------|----------|
| HTTP Ingress | 8080 | 30080 | ✅ Already correct |
| HTTPS Ingress | 8443 | 30443 | ✅ Already correct |
| Kafka External | 9092 | 30992 | ⚠️ Updated (was 9092) |
| Grafana | 3000 | 32044 | ⚠️ Updated (was 30000) |
| Prometheus | 9090 | 32090 | ⚠️ Updated (was 30090) |
| Rancher UI | 9443 | 30443 | ⚠️ Updated (was 9443) |

## Benefits of These Corrections
- Eliminates port conflicts between external access and internal services.
- Ensures services are accessible via the expected URLs (e.g., Prometheus at http://localhost:9090).
- Persistent data on D: drive survives cluster restarts (via volume mount).
- Improves reliability in local development environments.
- Maintains consistency between cluster configuration and Helm deployments.

---

## 6. Cluster Configuration (infrastructure/k3d/cluster-config.yaml) - CRITICAL FIX

### Issues Identified and Fixed

**Issue 1: Duplicate `volumes` keys**
- YAML had two separate `volumes:` sections causing parsing errors
- Error: `line 65: mapping key "volumes" already defined at line 56`

**Issue 2: Mixed YAML structure**
- Kubernetes API arguments were mixed within nodeFilters list
- Invalid YAML hierarchy prevented cluster creation

**Issue 3: Invalid `nodes` section**
- k3d Simple config doesn't support custom `nodes` configuration
- Error: `Additional property nodes is not allowed`

### Corrections Applied

**Fixed cluster-config.yaml**:
```yaml
options:
  k3s:
    extraArgs:
      - arg: "--disable=traefik"
        nodeFilters:
          - server:*
      - arg: "--kube-apiserver-arg=--max-requests-inflight=100"
        nodeFilters:
          - server:*
      - arg: "--kube-apiserver-arg=--max-mutating-requests-inflight=50"
        nodeFilters:
          - server:*

volumes:
  - volume: "D:\\data:/data"              # Maps Windows D: drive to container /data
    nodeFilters:
      - all                                # Apply to all nodes
  - volume: ./volumes:/var/lib/rancher/k3s/storage@all

kubeAPI:
  host: "0.0.0.0"
  hostPort: "6550"
```

### Result
- ✅ YAML now validates correctly
- ✅ Cluster creates successfully with `k3d cluster create --config infrastructure/k3d/cluster-config.yaml`
- ✅ Host D: drive is mounted into all k3d nodes at `/data`
- ✅ Enables persistent storage for Kubernetes PVCs

---

## 7. Local Path Provisioner Configuration

### Issue Encountered
- Helm chart `local-path-provisioner` not found in available repositories
- Manual YAML URL returned 404 errors
- Storage class was not configured to use the D: drive mount

### Solution Implemented
- Use k3s built-in Local Path Provisioner (already deployed in k3d)
- Configure via ConfigMap patch to use `/data` path
- Set as default StorageClass for automatic PVC binding

**Configuration Commands**:
```bash
# Configure provisioner to use /data path
kubectl patch configmap local-path-config -n kube-system \
  --type merge \
  -p '{"data":{"config.json":"{\"nodePathMap\":[{\"node\":\"DEFAULT_PATH_FOR_NON_LISTED_NODES\",\"paths\":[\"/data\"]}]}"}}'

# Set local-path as default StorageClass
kubectl patch storageclass local-path \
  -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

### Result
- ✅ PVCs automatically bind to `local-path` StorageClass
- ✅ Data persists in `D:\data` on Windows host
- ✅ Survives pod restarts and cluster stops

---

## Current Deployment Status (April 19, 2026)

### ✅ Successfully Deployed
- **Cluster**: platform-cluster (1 server + 2 agents)
- **NGINX Ingress Controller**: Listening on ports 8080/8443
- **cert-manager**: Certificate management ready
- **Prometheus**: Metrics collection running
  - UI: http://localhost:9090
  - PVC: prometheus-server (5Gi) ← Using local-path storage
- **Local Path Provisioner**: Configured for `/data` mount

### ⏳ Pending Deployment
- **Grafana**: Visualization dashboard
- **Rancher**: Cluster management UI
- **Kafka Strimzi Operator**: Event streaming platform
- **Kafka Cluster**: Distributed broker deployment
- **Kafka Connect**: Connector runtime
- **Airflow/Argo**: Workflow orchestration

### 📋 Deployment Commands
Run these to complete the platform setup:
```bash
# Verify cluster health
kubectl get nodes
kubectl get pvc -A
kubectl get storageclass

# Check D:\data directory
ls -la /data  # (from within cluster)

# Continue installation
./scripts/install-data-platform.sh
```

---
