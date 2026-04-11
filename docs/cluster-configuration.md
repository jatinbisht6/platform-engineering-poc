# Platform Engineering Lab - Cluster Configuration & Optimization Guide

## Overview
This document explains the k3d cluster configuration, optimizations applied, known issues, and troubleshooting procedures for the Platform Engineering Lab.

**Last Updated**: April 12, 2026
**Cluster**: platform-cluster (k3s v1.29.6)
**Configuration**: 1 server, 2 agents

---

## 1. Cluster Configuration (cluster-config.yaml)

### Current Setup
```yaml
servers: 1      # Single control plane node
agents: 2       # Two worker nodes
image: rancher/k3s:v1.29.6-k3s1

Memory Allocation:
- Server: 2GB
- Agent 1: 1GB  
- Agent 2: 1GB
- Total: 4GB
```

### Port Mappings
The cluster exposes the following ports through the load balancer:

| Service | Port | NodePort | Purpose |
|---------|------|----------|---------|
| HTTP Ingress | 8080 | 30080 | NGINX HTTP |
| HTTPS Ingress | 8443 | 30443 | NGINX HTTPS |
| Grafana | 3000 | 32044 | Monitoring Dashboard |
| Prometheus | 9090 | 32090 | Metrics Server |
| Rancher | 9443 | 30969 | Cluster Management |
| Kafka External | 9092 | 30992 | Event Streaming |

### Kubernetes API Access
- Host: 0.0.0.0
- Port: 6550 (local machine)
- Access: `kubectl cluster-info` or direct API calls

### Storage Configuration
- Type: local-path (default k3d provisioner)
- Path: `./volumes:/var/lib/rancher/k3s/storage@all`
- Provides automatic PV provisioning for stateful workloads

### API Server Optimizations (in cluster-config.yaml)
```yaml
extraArgs:
  - arg: "--disable=traefik"      # Use NGINX instead of default Traefik
  - arg: "--kube-apiserver-arg=--max-requests-inflight=100"      # API concurrency
  - arg: "--kube-apiserver-arg=--max-mutating-requests-inflight=50" # Mutation limits
```

---

## 2. Component Installation & Configuration

### Installed Helm Charts

#### NGINX Ingress Controller
- **Namespace**: platform-system
- **Memory**: 200m limit, 150m request
- **Storage**: None (StatelessSet)
- **Replicas**: 1
- **Metrics**: Enabled (port 10254)
- **Probes**: Basic HTTP probes with 60s startup delay

#### Prometheus Monitoring Stack
- **Namespace**: platform-system
- **Memory**: 512m limit (Prometheus server), 128m others
- **Storage**: 5Gi (Prometheus), 2Gi (Alertmanager)
- **Retention**: 30 days
- **Replicas**: HA replicas for node exporters
- **Scrape Frequency**: 30s (default)

#### Grafana
- **Namespace**: platform-system
- **Memory**: 512m limit (increased from 256m for stability)
- **Storage**: 2Gi persistent volume
- **Admin Password**: GrafanaDevPassword123!
- **Datasource**: Auto-configured Prometheus connection
- **Startup Time**: ~60 seconds with 5Gi+ storage

#### cert-manager
- **Namespace**: platform-system
- **Memory**: Default limits
- **Replicas**: 3 (manager, webhook, cainjector)
- **Purpose**: TLS certificate provisioning for Rancher

#### Kafka Strimzi Operator
- **Namespace**: kafka
- **Memory**: Default limits
- **Purpose**: Kafka cluster management on Kubernetes
- **Note**: Operator only, cluster created via CRD

#### Rancher
- **Namespace**: platform-system
- **Memory**: 1Gi limit (increased from 512m for stability)
- **Replicas**: 1
- **Bootstrap Password**: RancherDevPassword123!
- **Startup Time**: 3-5 minutes with database initialization
- **Dependencies**: cert-manager (must be running)

---

## 3. Known Issues & Solutions

### Issue 1: Grafana Pod Failing with Init:CrashLoopBackOff

**Symptoms**:
- Grafana pod stuck in Init:CrashLoopBackOff
- Error: "Permission denied" on `/var/lib/grafana/csv` or similar directories

**Root Cause**:
- PVC has files with different ownership from previous pod
- New pod's init container cannot change ownership

**Solutions**:

**Option A: Delete and Recreate PVC** (Recommended)
```bash
# Delete old pod and PVC
kubectl delete deployments/grafana -n platform-system
kubectl delete pvc grafana -n platform-system

# Wait 10 seconds
sleep 10

# Redeploy Grafana
helm upgrade --install grafana grafana/grafana \
    -f platform/observability/grafana/values.yaml \
    --namespace platform-system
```

**Option B: Clean PVC Manually**
```bash
# Get the PV associated with PVC
PV_NAME=$(kubectl get pvc grafana -n platform-system -o jsonpath='{.spec.volumeName}')

# Delete pod to unmount volume
kubectl delete pods -l app=grafana -n platform-system --force

# Access via Docker and clean (advanced)
docker exec k3d-platform-cluster-agent-0 rm -rf /var/lib/rancher/k3s/storage/$PV_NAME/*

# Restart deployment
kubectl rollout restart deployment/grafana -n platform-system
```

**Prevention**:
- Always delete old PVCs when changing pod specifications
- Use `--set persistence.enabled=false` for development if persistent data not needed

---

### Issue 2: Rancher Pod OOM Killed or Startup Probe Failures

**Symptoms**:
- Rancher pod restart loop with exit code 137 (OOM)
- Startup probe failures
- Pod never reaches Ready state

**Root Cause**:
- Insufficient memory during Rancher initialization
- Long database initialization (2-5 minutes)
- Probe timeouts during startup

**Solutions**:

**Option A: Increase Memory Limits** (Already Applied)
```yaml
# Current values in platform/rancher/values.yaml
resources:
  limits:
    cpu: 1000m
    memory: 1Gi
  requests:
    cpu: 500m
    memory: 512Mi
```

**Option B: Wait for Startup**
```bash
# Monitor Rancher pod startup
kubectl logs -f deployment/rancher -n platform-system

# Wait 5-10 minutes for database initialization
# Check readiness
kubectl get pods -n platform-system | grep rancher
```

**Option C: Disable Rancher Temporarily** (For reducing resource usage)
```bash
# Scale down Rancher
kubectl scale deployment rancher --replicas=0 -n platform-system

# Later, scale back up
kubectl scale deployment rancher --replicas=1 -n platform-system
```

**Prevention**:
- Allocate 1Gi minimum memory for Rancher
- Adjust startup probe timeouts: `initialDelaySeconds: 120`
- Monitor Docker resource usage during deployment: `docker stats`

---

### Issue 3: PVC Stuck in Pending State

**Symptoms**:
- PVC shows STATUS: Pending
- Pod won't start because volume not available

**Root Cause**:
- Storage class misconfiguration
- Local-path provisioner issues
- Insufficient disk space

**Diagnosis**:
```bash
# Check PVC status
kubectl describe pvc <pvc-name> -n <namespace>

# Check storage class
kubectl get storageclass

# Check available storage
kubectl get pv

# Check local-path provisioner
kubectl get pods -n kube-system | grep local-path

# Check events for errors
kubectl get events -n platform-system --sort-by='.lastTimestamp'
```

**Solutions**:
```bash
# Restart local-path provisioner
kubectl rollout restart deployment/local-path-provisioner -n kube-system

# Wait for provisioner to restart
sleep 30

# Delete stuck PVC
kubectl delete pvc <pvc-name> -n <namespace>

# Pod will auto-recreate PVC
```

---

## 4. Performance Optimization Tips

### For Low Resource Systems (2-4GB RAM)

1. **Disable Grafana Persistence**
   ```bash
   helm upgrade grafana grafana/grafana \
       --set persistence.enabled=false \
       --namespace platform-system
   ```

2. **Reduce Prometheus Retention**
   ```yaml
   # In prometheus values.yaml
   server:
     retention: "7d"  # Instead of 30d
   ```

3. **Scale Down Replicas**
   ```bash
   # Scale node exporters
   kubectl scale daemonset prometheus-node-exporter --replicas=1 -n platform-system
   ```

4. **Disable Rancher** (if not needed)
   ```bash
   helm uninstall rancher -n platform-system
   ```

### For High Resource Systems (8GB+ RAM)

1. **Increase Replicas**
   ```yaml
   # In values.yaml
   replicas: 2  # For high availability
   ```

2. **Increase Storage**
   ```yaml
   persistence:
     size: 20Gi  # Longer retention
   ```

3. **Deploy Additional Components**
   ```bash
   # Add more data platform components
   kubectl apply -f data-platform/
   ```

---

## 5. Troubleshooting Checklist

### Pre-Installation Checks
```bash
# Verify cluster exists
k3d cluster list

# Check nodes are ready
kubectl get nodes

# Check cluster resources
docker stats --no-stream

# Check available memory
free -h  # Linux/WSL2
Get-ComputerInfo | Select-Object CSName, SystemSkuNumber, WindowsVersion  # Windows
```

### Post-Installation Checks
```bash
# All pods should be Running or Completed
kubectl get pods -A

# All services should be active
kubectl get svc -n platform-system

# All PVCs should be Bound
kubectl get pvc -n platform-system

# All Helm releases deployed successfully
helm list -A

# No pending events
kubectl get events -n platform-system
```

### Component-Specific Checks

**Grafana**:
```bash
# Check logs for errors
kubectl logs -f deployment/grafana -n platform-system

# Verify datasource connectivity
kubectl exec -it deployment/grafana -n platform-system -- curl http://prometheus-server:80
```

**Prometheus**:
```bash
# Check scrape targets
curl http://localhost:9090/api/v1/targets

# Verify data collection
curl http://localhost:9090/api/v1/query?query=up
```

**Rancher**:
```bash
# Check initialization status
kubectl logs -f deployment/rancher -n platform-system

# Check bootstrap secret
kubectl get secret bootstrap-secret -n platform-system -o yaml
```

---

## 6. Platform Startup & Shutdown

### Startup
```bash
# Start cluster
k3d cluster create -c infrastructure/k3d/cluster-config.yaml

# Deploy platform
./scripts/start-platform.sh
```

### Shutdown (Graceful)
```bash
# Shutdown with resource cleanup
./scripts/stop-platform.sh

# Manual complete deletion
k3d cluster delete platform-cluster
```

### Full Reset
```bash
# Delete cluster completely
k3d cluster delete platform-cluster

# Remove volumes
rm -rf volumes/*

# Recreate cluster
k3d cluster create -c infrastructure/k3d/cluster-config.yaml
```

---

## 7. Resource Requirements Summary

### Minimum Requirements
- **CPU**: 2 cores
- **RAM**: 4GB
- **Storage**: 20GB free space
- **Docker**: Latest stable version
- **Network**: Port 6550, 8080-8443, 9090-9443 available

### Recommended Requirements
- **CPU**: 4 cores
- **RAM**: 8GB (16GB for comfortable operation)
- **Storage**: 50GB free space
- **Network**: Unrestricted local network access

### Current Deployment Resource Usage
```
Server Node:    2GB allocated (can use 36-73% CPU during initialization)
Agent Node 1:   1GB allocated (10-13% CPU usage typical)
Agent Node 2:   1GB allocated (5-10% CPU usage typical)
```

---

## 8. Configuration Files Reference

| File | Purpose | Key Settings |
|------|---------|--------------|
| `infrastructure/k3d/cluster-config.yaml` | k3d cluster definition | Nodes, ports, storage, memory |
| `platform/ingress/values.yaml` | NGINX controller | NodePort 30080/30443, metrics |
| `platform/observability/prometheus/values.yaml` | Prometheus | 5Gi storage, 30d retention |
| `platform/observability/grafana/values.yaml` | Grafana | 2Gi storage, admin password |
| `platform/rancher/values.yaml` | Rancher | 1Gi memory, bootstrap password |
| `platform/kafka-strimzi/values.yaml` | Kafka operator | 2 replicas, HA config |

---

## 9. Accessing Components

### Local Access (After Deployment)
```
Prometheus:  http://localhost:9090
Grafana:     http://localhost:3000     (admin / GrafanaDevPassword123!)
Rancher:     https://localhost:9443    (bootstrap / RancherDevPassword123!)
```

### Pod-to-Pod Communication (Internal)
```
Prometheus:  http://prometheus-server:80
Grafana:     http://grafana:80
Rancher:     http://rancher:80
Kafka:       broker-0.kafka-headless:9092
```

---

## 10. Monitoring Platform Health

### Quick Health Check Script
```bash
#!/bin/bash
echo "=== Platform Health Check ==="
echo "Cluster Status:"
kubectl get nodes

echo "Component Status:"
kubectl get all -n platform-system

echo "PVC Status:"
kubectl get pvc -n platform-system

echo "Docker Stats:"
docker stats --no-stream

echo "Helm Releases:"
helm list -A
```

---

**Next Steps**:
1. Monitor pod readiness: `kubectl get pods -A -w`
2. Test component access at provided URLs
3. Review logs for any errors: `kubectl logs -f <pod> -n <namespace>`
4. Adjust resource limits based on performance needs
5. Configure additional monitoring dashboards in Grafana

For issues not covered here, check the status logs in `co-pilot-check-log/` directory.
