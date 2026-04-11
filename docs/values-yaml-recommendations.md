# Component Values.yaml Recommendations

## Overview
After reviewing all values.yaml files in the platform, this document provides detailed recommendations for enhancing configurations for better reliability, observability, and resource management.

---

## 1. NGINX Ingress Controller ✅ APPROVED
**File**: `platform/ingress/values.yaml`

### Current Status
```yaml
controller:
  service:
    type: NodePort
    nodePorts:
      http: 30080
      https: 30443
  ingressClassResource:
    name: nginx
    enabled: true
    default: true
```

### Assessment
- ✅ Port mappings correct (align with cluster-config.yaml)
- ✅ Set as default ingress class
- ✅ Minimal configuration appropriate for dev environment

### Recommended Enhancements (Optional)
```yaml
controller:
  service:
    type: NodePort
    nodePorts:
      http: 30080
      https: 30443
  
  # Add resource limits for stability
  resources:
    limits:
      cpu: 200m
      memory: 256Mi
    requests:
      cpu: 100m
      memory: 128Mi
  
  # Enable metrics for monitoring
  metrics:
    enabled: true
    service:
      port: 10254
  
  ingressClassResource:
    name: nginx
    enabled: true
    default: true
  
  # Add logging
  config:
    log-format-upstream: '$proxy_protocol_addr - $remote_user [$time_local] "$request" $status $body_bytes_sent "$http_referer" "$http_user_agent"'
```

### Status
🟡 **OPTIONAL ENHANCEMENT** - Current config is functional but could benefit from resource limits and metrics

---

## 2. Prometheus ⚠️ NEEDS ENHANCEMENT
**File**: `platform/observability/prometheus/values.yaml`

### Current Status
```yaml
server:
  service:
    type: NodePort
    nodePort: 32090
  podLabels:
    app: prometheus
    tier: observability
```

### Issues Identified
- ❌ No persistent storage (data lost on pod restart)
- ❌ No resource limits (can consume unbounded CPU/memory)
- ❌ No retention policy configured
- ❌ No scrape job configurations
- ❌ No ingress configuration

### Recommended Enhancements
```yaml
server:
  service:
    type: NodePort
    nodePort: 32090
  
  # Add persistent storage for metrics history
  persistentVolume:
    enabled: true
    size: 5Gi
    storageClassName: local-path
  
  # Add resource limits
  resources:
    limits:
      cpu: 500m
      memory: 512Mi
    requests:
      cpu: 250m
      memory: 256Mi
  
  # Set retention policy (keep 30 days of metrics)
  retention: "30d"
  
  # Configure scrape jobs
  serverFiles:
    prometheus.yml:
      global:
        scrape_interval: 15s
        scrape_timeout: 10s
      scrape_configs:
        - job_name: 'kubernetes-apiservers'
          kubernetes_sd_configs:
            - role: endpoints
          scheme: https
          tls_config:
            ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
        
        - job_name: 'kubernetes-nodes'
          kubernetes_sd_configs:
            - role: node
          scheme: https
          tls_config:
            ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
        
        - job_name: 'prometheus'
          static_configs:
            - targets: ['localhost:9090']
  
  podLabels:
    app: prometheus
    tier: observability
```

### Status
🔴 **REQUIRES ENHANCEMENT** - Critical gaps in persistence and resource management

---

## 3. Grafana ⚠️ NEEDS ENHANCEMENT
**File**: `platform/observability/grafana/values.yaml`

### Current Status
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

### Issues Identified
- ❌ No admin password configuration (default: admin/admin is insecure)
- ❌ No datasources configured (manual setup required)
- ❌ No resource limits
- ❌ No Prometheus datasource configuration
- ❌ Storage size may be insufficient (1Gi is minimal)

### Recommended Enhancements
```yaml
service:
  type: NodePort
  nodePort: 32044

# Set admin credentials
adminPassword: "GrafanaDevPassword123!"  # Change in production

# Configure persistent storage
persistence:
  enabled: true
  size: 2Gi
  storageClassName: local-path

# Add resource limits
resources:
  limits:
    cpu: 300m
    memory: 256Mi
  requests:
    cpu: 150m
    memory: 128Mi

# Configure Prometheus datasource automatically
datasources:
  datasources.yaml:
    apiVersion: 1
    datasources:
      - name: Prometheus
        type: prometheus
        url: http://prometheus-server:32090
        access: proxy
        isDefault: true

# Add pod labels
podLabels:
  app: grafana
  tier: observability

# Enable ingress for better access
ingress:
  enabled: true
  ingressClassName: nginx
  path: /grafana
  hosts:
    - localhost
```

### Status
🔴 **REQUIRES ENHANCEMENT** - Missing security, datasource, and resource configurations

---

## 4. Rancher ⚠️ NEEDS ENHANCEMENT
**File**: `platform/rancher/values.yaml`

### Current Status
```yaml
hostname: rancher.local
replicas: 1
service:
  type: NodePort
  nodePort: 30443
```

### Issues Identified
- ⚠️ Hostname `rancher.local` requires `/etc/hosts` entry for local access
- ❌ No TLS certificate configuration
- ❌ No bootstrap password set
- ❌ No resource limits
- ❌ No ingress configuration

### Recommended Enhancements
```yaml
# For local dev, use localhost instead of rancher.local
hostname: localhost

replicas: 1

service:
  type: NodePort
  nodePort: 30443

# Set bootstrap password
bootstrapPassword: "RancherDevPassword123!"  # Change in production

# Configure TLS
ingress:
  enabled: true
  ingressClassName: nginx
  tls:
    enabled: true
    issuer:
      name: letsencrypt-staging
      kind: ClusterIssuer

# Add resource limits
resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 250m
    memory: 256Mi

# Security settings
apiAuditors: true
auditLog:
  enabled: true
```

### Status
🔴 **REQUIRES ENHANCEMENT** - Missing TLS, security, and resource configurations

---

## 5. Kafka Strimzi ⚠️ NEEDS ENHANCEMENT
**File**: `platform/kafka-strimzi/values.yaml`

### Current Status
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

### Issues Identified
- ⚠️ Single replica for Kafka (not HA, loses data on failure)
- ⚠️ Single replica for Zookeeper (not HA, single point of failure)
- ❌ No storage configuration specified
- ❌ No resource limits
- ❌ No external access configured
- ❌ No entity operator configuration

### Recommended Enhancements
```yaml
# Kafka cluster configuration
kafka:
  # Increase replicas for better HA (3 is ideal for dev)
  replicas: 3
  
  # Configure storage
  storage:
    type: persistent-claim
    size: 5Gi
    class: local-path
  
  # Configure listeners for different access patterns
  listeners:
    - name: plain
      port: 9092
      type: internal
      tls: false
    
    - name: external
      port: 30992
      type: nodeport
      tls: false
      configuration:
        brokerCertChainAndKey:
          secretName: kafka-brokers-certs
  
  # Add resource limits
  resources:
    limits:
      cpu: 500m
      memory: 512Mi
    requests:
      cpu: 250m
      memory: 256Mi
  
  # JVM settings
  jvmOptions:
    "-Xms": "256m"
    "-Xmx": "512m"
  
  # Logging configuration
  logging:
    type: inline
    loggers:
      kafka.root.logger.level: "INFO"

# ZooKeeper configuration
zookeeper:
  replicas: 3
  
  storage:
    type: persistent-claim
    size: 2Gi
    class: local-path
  
  resources:
    limits:
      cpu: 250m
      memory: 256Mi
    requests:
      cpu: 125m
      memory: 128Mi

# Entity Operator (for topic and user management)
entityOperator:
  topicOperator:
    logging:
      type: inline
      loggers:
        rootLogger.level: "INFO"
    resources:
      limits:
        cpu: 200m
        memory: 128Mi
      requests:
        cpu: 100m
        memory: 64Mi
  
  userOperator:
    logging:
      type: inline
      loggers:
        rootLogger.level: "INFO"
    resources:
      limits:
        cpu: 200m
        memory: 128Mi
      requests:
        cpu: 100m
        memory: 64Mi
```

**Note**: For dev environment, you can use 1-2 replicas to save resources:
```yaml
kafka:
  replicas: 2  # Minimum for dev HA
zookeeper:
  replicas: 2  # Minimum for dev HA
```

### Status
🔴 **REQUIRES ENHANCEMENT** - Critical gaps in HA, storage, and resource management

---

## Summary Table

| Component | Status | Priority | Issues |
|-----------|--------|----------|--------|
| NGINX Ingress | ✅ Approved | Optional | Add resource limits & metrics |
| Prometheus | ⚠️ Incomplete | High | Add persistence, resource limits |
| Grafana | ⚠️ Incomplete | High | Add datasources, credentials, limits |
| Rancher | ⚠️ Incomplete | High | Add TLS, bootstrap password, limits |
| Kafka Strimzi | ⚠️ Incomplete | High | Add HA replicas, storage, limits |

---

## Implementation Plan

### Phase 1 (Current)
- ✅ NGINX Ingress deployed

### Phase 2 (Next)
- [ ] Prometheus with persistence and scrape configs
- [ ] Grafana with datasources and admin credentials
- [ ] cert-manager (prerequisite for secure services)

### Phase 3
- [ ] Rancher with TLS and security
- [ ] Kafka Strimzi with HA replicas and storage

---

## Notes
- **Resource Limits**: Prevent one component from consuming all system resources
- **Persistence**: Ensures data survives pod restarts
- **HA Replicas**: Kafka/Zookeeper should have odd number (typically 3)
- **Storage Classes**: Uses `local-path` (k3d default). For prod, use proper storage classes.
- **Passwords/Credentials**: These recommendations are for DEV only. Never commit real credentials to git.

---

**Date**: April 11, 2026  
**Updated**: After NGINX Ingress deployment
