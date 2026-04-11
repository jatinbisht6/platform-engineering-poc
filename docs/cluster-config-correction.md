# Cluster Config Corrections

## Overview
This document outlines corrections and optimizations for the Helm values.yaml files to ensure they align with the k3d cluster configuration in `infrastructure/k3d/cluster-config.yaml`. The cluster config defines port mappings (external:internal), but some values.yaml files had mismatched nodePorts, which could cause conflicts or inaccessibility.

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
- Improves reliability in local development environments.
- Maintains consistency between cluster configuration and Helm deployments.

## How to Apply
1. Apply the corrections to each values.yaml file (see implementation below).
2. If components are already deployed, re-run the Helm installs (e.g., `helm upgrade --install prometheus ...`).
3. Verify pod health: `kubectl get pods -n <namespace>`
4. Test access after updates (see verification steps below).

## Access Points After Deployment
- **Grafana**: http://localhost:3000 (default: admin/admin)
- **Prometheus**: http://localhost:9090
- **Rancher**: https://localhost:9443
- **HTTP Ingress**: http://localhost:8080
- **HTTPS Ingress**: https://localhost:8443
- **Kafka**: localhost:9092 (for external clients)

## Date
April 11, 2026

## Reference
- Cluster Config: [infrastructure/k3d/cluster-config.yaml](../infrastructure/k3d/cluster-config.yaml)
