# Platform Engineering Lab - Deployment Log

**Deployment Date**: April 18-19, 2026  
**Environment**: Windows 10 / WSL2 / Docker Desktop / k3d  
**Kubernetes Version**: v1.29.6+k3s1  

---

## Phase 0 & 1: Foundation & Platform Core ✅

### Completed Successfully
- ✅ Git repository initialized
- ✅ Docker and k3d installed and configured
- ✅ Kubeconfig properly configured
- ✅ Namespaces created: `platform-system`, `kafka`, `data-platform`
- ✅ k3d cluster created with 1 server + 2 agents

---

## Phase 2: Database Versioning ✅

- ✅ SQL Server versioning folder structure created
- ✅ Database schema exported
- ✅ Backup scripts implemented (`backup-db.sh`)
- ✅ `.gitignore` configured for backups

---

## Phase 3: Data Platform Runtime - CURRENT ⚠️

### Part 3.1: Cluster Configuration Fixes

| Issue | Resolution | Status |
|-------|-----------|--------|
| Duplicate `volumes` keys in cluster-config.yaml | Merged into single `volumes` section | ✅ Fixed |
| Invalid `nodes` section | Removed (not supported in Simple config) | ✅ Fixed |
| YAML structure errors | Properly formatted k3s extraArgs | ✅ Fixed |
| D: drive volume mount | Added `D:\data:/data` mapping | ✅ Configured |

### Part 3.2: Storage Configuration

| Component | Issue | Resolution | Status |
|-----------|-------|-----------|--------|
| Local Path Provisioner | Helm chart not found | Applied kubectl manifest directly | ✅ Working |
| Storage ConfigMap | Default path not set | Configured to use `/data` | ✅ Working |
| StorageClass | Not set as default | Patched local-path as default | ✅ Working |

### Part 3.3: Component Deployment Status

#### ✅ Successfully Deployed
```
NAMESPACE       COMPONENT                    VERSION    STATUS
kube-system     coredns                      -          Running
kube-system     local-path-provisioner       -          Running
kube-system     metrics-server               -          Running
platform-system cert-manager                v1.14.5    Running
platform-system cert-manager-cainjector     v1.14.5    Running
platform-system cert-manager-webhook        v1.14.5    Running
platform-system ingress-nginx-controller    1.15.1     Running
platform-system prometheus-server           v3.11.2    Running (2/2 pods ready)
platform-system prometheus-alertmanager     -          Running
platform-system prometheus-node-exporter    -          Running (3/3 nodes)
platform-system prometheus-kube-state       -          Running
platform-system prometheus-pushgateway      -          Running
```

#### ⏳ Not Yet Deployed
- Grafana (pending: deployment timeout during initial script run)
- Rancher (pending: script interruption)
- Kafka Strimzi Operator
- Kafka Cluster
- Kafka Connect
- Airflow/Argo

### Part 3.4: Persistent Storage Status

| Component | Storage | Size | Status |
|-----------|---------|------|--------|
| Prometheus | local-path PVC | 5Gi | ✅ Bound |
| Grafana | local-path PVC | 2Gi | ⏳ Pending |

**D: Drive Mount Verification**:
- ✅ Volume `D:\data:/data` mapped to all nodes
- ✅ Host `/data` directory exists on D: drive
- ✅ k3s storage path configured correctly

---

## Errors Encountered & Resolutions

### Error 1: Duplicate YAML Keys
```
Error: Failed to read config file: yaml: unmarshal errors:
  line 65: mapping key "volumes" already defined at line 56
```
**Resolution**: Merged duplicate `volumes` sections into one. ✅

### Error 2: Invalid YAML Schema
```
Error: Schema Validation failed: Additional property nodes is not allowed
```
**Resolution**: Removed invalid `nodes` section; used `servers`/`agents` instead. ✅

### Error 3: Non-existent Helm Chart
```
Error: chart "local-path-provisioner" not found in rancher-stable index
```
**Resolution**: Used k3s built-in provisioner with kubectl configuration. ✅

### Error 4: 404 on GitHub YAML URL
```
Error: unable to read URL ".../v0.0.24/deploy/local-path-storage.yaml"
  server reported 404 Not Found
```
**Resolution**: Removed external URL dependency; used ConfigMap patching. ✅

### Error 5: Prometheus Deployment Timeout
```
Error: timed out waiting for condition on deployments/prometheus-server (120s timeout)
```
**Status**: Resolved - Pod now running successfully (2/2 ready). ✅

---

## Performance Metrics

| Metric | Value |
|--------|-------|
| Cluster Creation Time | ~60 seconds |
| Component Installation Time | ~3-4 minutes |
| Average Pod Startup Time | 10-30 seconds |
| Total Cluster Memory Usage | ~2.5GB |
| Storage Available (D: drive) | Full capacity |

---

## Access Information

| Service | URL | Port | Status |
|---------|-----|------|--------|
| Prometheus | http://localhost:9090 | 9090 → 32090 | ✅ Running |
| Grafana | http://localhost:3000 | 3000 → 32044 | ⏳ Deploying |
| Rancher | https://localhost:9443 | 9443 → 30969 | ⏳ Deploying |
| Ingress HTTP | http://localhost:8080 | 8080 → 30080 | ✅ Running |
| Ingress HTTPS | https://localhost:8443 | 8443 → 30443 | ✅ Running |
| Kafka | localhost:9092 | 9092 → 30992 | ⏳ Not deployed |
| Kubernetes API | https://127.0.0.1:6550 | 6550 | ✅ Running |

---

## Next Steps

### Immediate Actions
1. ✅ Complete core cluster deployment (current state)
2. ⏳ Deploy remaining UI components (Grafana, Rancher)
3. ⏳ Deploy Kafka and connectors
4. ⏳ Deploy workflow orchestration (Airflow/Argo)

### Verification Commands
```bash
# Set kubeconfig
export KUBECONFIG="$PWD/.k3d-platform-cluster-config"

# Check cluster health
kubectl get nodes
kubectl get pods -A
kubectl get pvc -A
kubectl get storageclass

# Check D: drive data persistence
docker exec k3d-platform-cluster-server-0 ls -la /data/

# View component logs
kubectl logs -n platform-system -l app=prometheus-server
kubectl logs -n platform-system -l app.kubernetes.io/name=ingress-nginx
```

### Complete Deployment
```bash
# Install remaining UI components
helm upgrade --install grafana grafana/grafana \
  -f platform/observability/grafana/values.yaml \
  --namespace platform-system

helm upgrade --install rancher rancher-latest/rancher \
  -f platform/rancher/values.yaml \
  --namespace platform-system

# Install data platform components
./scripts/install-data-platform.sh
```

---

## Configuration Files Modified

1. **infrastructure/k3d/cluster-config.yaml**
   - Fixed duplicate volumes sections
   - Removed invalid nodes configuration
   - Added D: drive volume mount

2. **scripts/start-platform.sh**
   - Updated Helm repos (removed invalid local-path repo)
   - Changed provisioner installation method (kubectl vs Helm)
   - Added ConfigMap patch for storage path

3. **platform/local-path/values.yaml** (created)
   - Configured storage class settings
   - Set node path to `/data`

4. **docs/cluster-config-correction.md** (updated)
   - Documented all configuration corrections
   - Added troubleshooting guide

---

## Notes for Future Deployments

- **Windows Paths**: Use `D:\\data` (double backslash) in k3d configs
- **Volume Mounts**: Ensure host directory exists before cluster creation (`mkdir -p D:\data`)
- **Storage Class**: Always set default StorageClass after provisioner deployment
- **Persistence**: Data in `/data` path survives cluster restarts
- **DNS**: Use `host.docker.internal` for host access from containers

---

**Last Updated**: April 19, 2026 - 00:15 UTC  
**Status**: Core platform operational, deployment 70% complete
