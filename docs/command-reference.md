# Platform Engineering Lab - Command Reference

## Overview
This document serves as a comprehensive reference for all commands used during the Platform Engineering Lab setup. Commands are organized by category with descriptions, syntax, and context for easy reference and reproducibility.

**Last Updated**: April 25, 2026
**Platform**: Windows 10 / WSL2 / Docker Desktop / k3d
**Kubernetes**: v1.29.6+k3s1

---

## 1. k3d Cluster Management

### Create k3d Cluster
```bash
k3d cluster create --config infrastructure/k3d/cluster-config.yaml --api-port 6550
```
**Description**: Creates a new k3d cluster using the cluster configuration file.  
**Context**: Sets up lightweight Kubernetes cluster with specified nodes and port mappings.  
**Expected Output**: "Cluster 'platform-cluster' created successfully!".  
**Frequency**: Once, during initial platform setup.  
**Config File**: infrastructure/k3d/cluster-config.yaml (1 server, 2 agents, port mappings).  
**Note**: Removes existing cluster with same name first if running.

### Delete k3d Cluster
```bash
k3d cluster delete platform-cluster
```
**Description**: Removes the k3d cluster and all its volumes.  
**Context**: Cleanup between deployments or full platform reset.  
**Expected Output**: "Successfully deleted cluster platform-cluster!".  
**Frequency**: When resetting platform or updating cluster configuration.

### Get k3d Kubeconfig
```bash
k3d kubeconfig get platform-cluster > infrastructure/k3d/kube-config.yaml
```
**Description**: Extracts kubeconfig from the k3d cluster to a file.  
**Context**: Configures kubectl access to the cluster.  
**Expected Output**: YAML file with cluster credentials and API endpoint.  
**Frequency**: Once after cluster creation, or when resetting credentials.

### List k3d Clusters
```bash
k3d cluster list
```
**Description**: Shows all existing k3d clusters on the system.  
**Context**: Verifies which clusters are available.  
**Expected Output**: Cluster name, servers, agents, status.  
**Frequency**: Before creating a new cluster or troubleshooting.

---

## 2. Cluster Setup & Verification

### Docker Status Check
```bash
docker ps
```
**Description**: Lists all running Docker containers to verify k3d cluster is operational.  
**Context**: Used to confirm cluster nodes (server, agents, load balancer) are running.  
**Expected Output**: 5 containers (k3d cluster components).  
**Frequency**: Pre-installation, troubleshooting.

### Kubernetes Node Status
```bash
kubectl get nodes
```
**Description**: Displays all Kubernetes nodes in the cluster with their status.  
**Context**: Verifies all 3 nodes (1 server, 2 agents) are Ready.  
**Expected Output**: All nodes show STATUS=Ready.  
**Frequency**: Pre-installation, post-cluster creation.

### Kubernetes Cluster Information
```bash
kubectl cluster-info
```
**Description**: Shows cluster control plane and DNS service endpoints.  
**Context**: Confirms kubectl is properly configured and cluster is accessible.  
**Expected Output**: Control plane URL and service endpoints.  
**Frequency**: Pre-installation, configuration verification.

### System Memory Check
```bash
free -h
```
**Description**: Displays system memory usage in human-readable format.  
**Context**: Verifies sufficient memory for component installation.  
**Expected Output**: Available memory (should be >2GB for full platform).  
**Frequency**: Pre-installation, resource monitoring.  
**Note**: May not work on Windows; use `docker stats` instead.

### Docker Resource Usage
```bash
docker stats --no-stream
```
**Description**: Shows real-time resource usage for all Docker containers.  
**Context**: Monitors CPU, memory, and I/O usage of k3d cluster containers.  
**Expected Output**: Resource usage table for all containers.  
**Frequency**: Pre-installation, during deployment, troubleshooting.

---

## 2. Namespace Management

### Create All Namespaces
```bash
kubectl apply -f infrastructure/namespaces.yaml
```
**Description**: Applies the namespace YAML file to create all required namespaces.  
**Context**: Creates platform-system, kafka, and data-platform namespaces.  
**Expected Output**: "namespace/platform-system created", etc.  
**Frequency**: Once, after cluster creation.  
**Alternative**: Individual `kubectl create namespace <name>` commands.

### List All Namespaces
```bash
kubectl get namespaces
```
**Description**: Displays all Kubernetes namespaces with their status.  
**Context**: Verifies namespaces were created successfully.  
**Expected Output**: 7 namespaces (4 system + 3 custom).  
**Frequency**: Post-namespace creation, verification.

---

## 3. Helm Repository Management

### Add NGINX Ingress Repository
```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
```
**Description**: Adds the NGINX Ingress Controller Helm repository.  
**Context**: Required for installing NGINX Ingress Controller.  
**Expected Output**: "ingress-nginx" has been added to your repositories.  
**Frequency**: Once, during Helm setup.

### Add Prometheus Community Repository
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
```
**Description**: Adds the Prometheus community Helm repository.  
**Context**: Required for installing Prometheus monitoring stack.  
**Expected Output**: "prometheus-community" has been added.  
**Frequency**: Once, during Helm setup.

### Add Grafana Repository
```bash
helm repo add grafana https://grafana.github.io/helm-charts
```
**Description**: Adds the Grafana Helm repository.  
**Context**: Required for installing Grafana visualization platform.  
**Expected Output**: "grafana" has been added.  
**Frequency**: Once, during Helm setup.

### Add Strimzi Repository
```bash
helm repo add strimzi https://strimzi.io/charts/
```
**Description**: Adds the Strimzi Kafka operator Helm repository.  
**Context**: Required for installing Kafka on Kubernetes.  
**Expected Output**: "strimzi" has been added.  
**Frequency**: Once, during Helm setup.

### Add Rancher Latest Repository
```bash
helm repo add rancher-latest https://releases.rancher.com/server-charts/latest
```
**Description**: Adds the Rancher latest Helm repository.  
**Context**: Required for installing Rancher cluster management platform.  
**Expected Output**: "rancher-latest" has been added.  
**Frequency**: Once, during Helm setup.

### Add Jetstack Repository
```bash
helm repo add jetstack https://charts.jetstack.io
```
**Description**: Adds the Jetstack Helm repository for cert-manager.  
**Context**: Required for installing cert-manager TLS certificate management.  
**Expected Output**: "jetstack" has been added.  
**Frequency**: Once, during Helm setup.

### Update All Helm Repositories
```bash
helm repo update
```
**Description**: Downloads the latest chart information from all added repositories.  
**Context**: Ensures we have the latest chart versions before installation.  
**Expected Output**: "Successfully got an update from..." for each repo.  
**Frequency**: Once, after adding all repositories.

### List All Helm Repositories
```bash
helm repo list
```
**Description**: Displays all configured Helm repositories.  
**Context**: Verifies all repositories are properly configured.  
**Expected Output**: Table of repository names and URLs.  
**Frequency**: Post-repository setup, verification.

---

## 4. Component Installation

### Install NGINX Ingress Controller
```bash
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
    -f platform/ingress/values.yaml \
    --namespace platform-system
```
**Description**: Installs or upgrades NGINX Ingress Controller with custom values.  
**Context**: Sets up HTTP/HTTPS routing for the cluster.  
**Expected Output**: "NAME: ingress-nginx", "STATUS: deployed".  
**Frequency**: Once, during Phase 1.4.  
**Values File**: platform/ingress/values.yaml (NodePorts 30080/30443).

### Install Prometheus
```bash
helm upgrade --install prometheus prometheus-community/prometheus \
    -f platform/observability/prometheus/values.yaml \
    --namespace platform-system
```
**Description**: Installs or upgrades Prometheus monitoring with custom values.  
**Context**: Sets up metrics collection and monitoring.  
**Expected Output**: "NAME: prometheus", "STATUS: deployed".  
**Frequency**: Once, during Phase 1.5.  
**Values File**: platform/observability/prometheus/values.yaml (5Gi storage, 30d retention).

### Install Grafana
```bash
helm upgrade --install grafana grafana/grafana \
    -f platform/observability/grafana/values.yaml \
    --namespace platform-system
```
**Description**: Installs or upgrades Grafana with custom values.  
**Context**: Sets up visualization and dashboards.  
**Expected Output**: "NAME: grafana", "STATUS: deployed".  
**Frequency**: Once, during Phase 1.6.  
**Values File**: platform/observability/grafana/values.yaml (2Gi storage, Prometheus datasource).

### Install cert-manager
```bash
helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace platform-system \
  --version v1.14.5 \
  --set installCRDs=true \
  --set global.leaderElection.namespace=platform-system
```
**Description**: Installs cert-manager for TLS certificate management.  
**Context**: Required for secure HTTPS connections (prerequisite for Rancher).  
**Expected Output**: "NAME: cert-manager", "STATUS: deployed".  
**Frequency**: Once, during Phase 1.7.  
**Note**: Includes CRD installation and specific namespace configuration.

### Install Kafka Strimzi Operator
```bash
helm upgrade --install kafka-operator strimzi/strimzi-kafka-operator \
    -f platform/kafka-strimzi/values.yaml \
    --namespace kafka
```
**Description**: Installs Strimzi Kafka operator with custom values.  
**Context**: Sets up Kafka cluster management on Kubernetes.  
**Expected Output**: "NAME: kafka-operator", "STATUS: deployed".  
**Frequency**: Once, during Phase 1.8.  
**Values File**: platform/kafka-strimzi/values.yaml (2 replicas, persistent storage).

### Install Rancher
```bash
helm upgrade --install rancher rancher-latest/rancher \
    -f platform/rancher/values.yaml \
    --namespace platform-system
```
**Description**: Installs Rancher cluster management platform with custom values.  
**Context**: Provides Kubernetes cluster management UI.  
**Expected Output**: "NAME: rancher", "STATUS: deployed".  
**Frequency**: Once, during Phase 1.9.  
**Values File**: platform/rancher/values.yaml (localhost hostname, bootstrap password).

### Install Rancher
```bash
helm upgrade --install rancher rancher-latest/rancher \
    -f platform/rancher/values.yaml \
    --namespace platform-system
```
**Description**: Installs Rancher cluster management platform with custom values.  
**Context**: Provides Kubernetes cluster management UI.  
**Expected Output**: "NAME: rancher", "STATUS: deployed".  
**Frequency**: Once, during Phase 1.9.  
**Values File**: platform/rancher/values.yaml (localhost hostname, bootstrap password).

### Configure Local Path Provisioner
```bash
kubectl patch configmap local-path-config -n kube-system --type merge -p '{"data":{"config.json":"{\"nodePathMap\":[{\"node\":\"DEFAULT_PATH_FOR_NON_LISTED_NODES\",\"paths\":[\"/data\"]}]}"}}'
```
**Description**: Configures the local-path storage provisioner to use /data directory.  
**Context**: Sets up persistent storage for stateful components.  
**Expected Output**: "configmap/local-path-config patched".  
**Frequency**: Once, after cluster creation, before component installation.

### Set Default Storage Class
```bash
kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```
**Description**: Marks local-path as the default storage class.  
**Context**: Enables components to automatically use local-path for PVCs without explicit class.  
**Expected Output**: "storageclass.storage.k8s.io/local-path patched".  
**Frequency**: Once, during platform setup.

### Deploy Kafka Cluster
```bash
kubectl apply -f platform/kafka-strimzi/kafka-cluster.yaml
```
**Description**: Deploys Kafka cluster using Strimzi operator.  
**Context**: Creates a Kafka cluster for event streaming.  
**Expected Output**: "kafka.kafka.strimzi.io/kafka-cluster created".  
**Frequency**: Once, during Phase 3 (Data Platform).  
**Config File**: platform/kafka-strimzi/kafka-cluster.yaml (KRaft mode - no ZooKeeper required).

### Deploy Kafka Connect
```bash
kubectl apply -f platform/kafka-strimzi/kafka-connect.yaml
```
**Description**: Deploys Kafka Connect cluster for data integration.  
**Context**: Sets up connectors for external data sources/sinks.  
**Expected Output**: "kafkaconnect.kafka.strimzi.io/kafka-connect created".  
**Frequency**: Once, during Phase 3 (Data Platform).  
**Config File**: platform/kafka-strimzi/kafka-connect.yaml (2 replicas).

### Wait for Deployment with Custom Timeout
```bash
kubectl wait --for=condition=available deployment/<deployment-name> -n <namespace> --timeout=1200s
```
**Description**: Waits for a deployment to be available with customizable timeout.  
**Context**: Ensures component startup completion before proceeding.  
**Expected Output**: "deployment.apps/<name> condition met".  
**Frequency**: During component installation.  
**Examples**:
- Grafana (1200s): `kubectl wait --for=condition=available deployment/grafana -n platform-system --timeout=1200s`
- Rancher (1200s): `kubectl wait --for=condition=available deployment/rancher -n platform-system --timeout=1200s`
- Strimzi (1200s): `kubectl wait --for=condition=available deployment/strimzi-cluster-operator -n kafka --timeout=1200s`

### Wait for Kafka Resource
```bash
kubectl wait kafka/<kafka-name> --for=condition=Ready --timeout=600s -n kafka
```
**Description**: Waits for Kafka cluster custom resource to be ready.  
**Context**: Ensures Kafka cluster is fully initialized before deploying connectors.  
**Expected Output**: "kafka.kafka.strimzi.io/<name> condition met".  
**Frequency**: After deploying Kafka cluster.

---

## 5. Status Monitoring

### Get Platform-System Pods
```bash
kubectl get pods -n platform-system
```
**Description**: Lists all pods in the platform-system namespace.  
**Context**: Monitors component deployment status.  
**Expected Output**: Pod names, READY status, RESTARTS, AGE.  
**Frequency**: During deployment, troubleshooting.

### Get Kafka Namespace Pods
```bash
kubectl get pods -n kafka
```
**Description**: Lists all pods in the kafka namespace.  
**Context**: Monitors Kafka operator and cluster status.  
**Expected Output**: Pod names, READY status, RESTARTS, AGE.  
**Frequency**: During Kafka deployment, troubleshooting.

### Get Kafka Cluster Resources
```bash
kubectl get kafka -n kafka
```
**Description**: Lists all Kafka cluster resources.  
**Context**: Verifies Kafka cluster creation and status.  
**Expected Output**: Kafka cluster name, READY status, AGE.  
**Frequency**: After Kafka cluster deployment.

### Get Kafka Connect Resources
```bash
kubectl get kafkaconnect -n kafka
```
**Description**: Lists all Kafka Connect cluster resources.  
**Context**: Verifies Kafka Connect deployment and status.  
**Expected Output**: Kafka Connect cluster name, READY status, AGE.  
**Frequency**: After Kafka Connect deployment.

### Kafka Cluster Verification

#### Describe Kafka Cluster
```bash
kubectl describe kafka kafka-cluster -n kafka
```
**Description**: Shows detailed information about the Kafka cluster resource.  
**Context**: Troubleshooting Kafka cluster issues, viewing conditions and events.  
**Expected Output**: Kafka cluster specification, status, and event history.  
**Frequency**: When troubleshooting Kafka deployment.

#### Check Kafka Broker Logs
```bash
kubectl logs -n kafka kafka-cluster-kafka-0
```
**Description**: Displays logs from the first Kafka broker pod.  
**Context**: Debugging broker startup issues or runtime errors.  
**Expected Output**: Kafka broker startup and runtime logs.  
**Frequency**: When Kafka pods fail to start or show errors.  
**Note**: Brokers are numbered: kafka-cluster-kafka-0, kafka-cluster-kafka-1, kafka-cluster-kafka-2, etc.

#### Port Forward to Kafka Bootstrap Server
```bash
kubectl port-forward -n kafka svc/kafka-cluster-kafka-bootstrap 9092:9092
```
**Description**: Creates a local port forward to the Kafka bootstrap server.  
**Context**: Enables local testing and debugging of Kafka cluster connectivity.  
**Expected Output**: "Forwarding from 127.0.0.1:9092 -> 9092...".  
**Frequency**: When testing Kafka connectivity from local machine.  
**Note**: Keep terminal open while port forwarding is active.

#### Test Kafka Connectivity (kafkacat)
```bash
kafkacat -b localhost:9092 -L
```
**Description**: Lists all topics and brokers in the Kafka cluster (requires kafkacat installed).  
**Context**: Verifies Kafka cluster is fully operational and accessible.  
**Expected Output**: Topic list, partition information, broker details.  
**Frequency**: After Kafka cluster deployment to verify connectivity.  
**Prerequisites**: Install kafkacat (`brew install kafkacat` on macOS, or use Docker image).  
**Alternative**: Use `kafka-topics.sh` from within a Kafka pod if kafkacat unavailable.

#### List Kafka Topics via kubectl
```bash
kubectl exec -it -n kafka kafka-cluster-kafka-0 -- bin/kafka-topics.sh --list --bootstrap-server localhost:9092
```
**Description**: Lists all topics in the Kafka cluster using kafka-topics.sh.  
**Context**: Verifies Kafka cluster topics when kafkacat is unavailable.  
**Expected Output**: List of topic names.  
**Frequency**: After Kafka cluster deployment.

#### Check Kafka Broker Status
```bash
kubectl get pods -n kafka -l app.kubernetes.io/name=kafka,app.kubernetes.io/instance=kafka-cluster
```
**Description**: Lists all Kafka broker pods with detailed status.  
**Context**: Verifies all broker pods are running and ready.  
**Expected Output**: All kafka-cluster-kafka pods in Running state.  
**Frequency**: During Kafka deployment, troubleshooting.

#### Check Kafka Node Pools (KRaft)
```bash
kubectl get kafkanodepools -n kafka
```
**Description**: Lists Kafka node pools for KRaft mode (replaces ZooKeeper).  
**Context**: Verifies Kafka controller and broker node pools are configured.  
**Expected Output**: kafka-cluster-brokers and kafka-cluster-controllers node pools.  
**Frequency**: After Kafka cluster deployment to verify KRaft setup.

#### Check Kafka Controller Pods (KRaft)
```bash
kubectl get pods -n kafka -l kafka.strimzi.io/controller=true
```
**Description**: Lists Kafka controller pods running KRaft consensus.  
**Context**: Verifies Kafka controllers are running (KRaft replaces ZooKeeper).  
**Expected Output**: All controller pods in Running state.  
**Frequency**: After Kafka cluster deployment, troubleshooting.

### Get Data-Platform Pods
```bash
kubectl get pods -n data-platform
```
**Description**: Lists all pods in the data-platform namespace.  
**Context**: Monitors data platform component status.  
**Expected Output**: Pod names, READY status, RESTARTS, AGE.  
**Frequency**: After data platform deployment.

### Get All Resources in Platform-System
```bash
kubectl get all -n platform-system
```
**Description**: Lists all Kubernetes resources in platform-system namespace.  
**Context**: Comprehensive view of deployments, services, pods.  
**Expected Output**: Complete resource inventory.  
**Frequency**: Post-deployment verification.

### Get All Resources in Kafka
```bash
kubectl get all -n kafka
```
**Description**: Lists all Kubernetes resources in kafka namespace.  
**Context**: Comprehensive view of Kafka operator and cluster resources.  
**Expected Output**: Complete resource inventory.  
**Frequency**: Post-Kafka deployment verification.

### List All Helm Releases
```bash
helm list -A
```
**Description**: Shows all Helm releases across all namespaces.  
**Context**: Verifies component installation status.  
**Expected Output**: Release name, namespace, revision, status, chart.  
**Frequency**: Post-installation verification.

### Get Platform-System Deployments
```bash
kubectl get deployments -n platform-system
```
**Description**: Lists deployment resources in platform-system namespace.  
**Context**: Checks deployment health and replica status.  
**Expected Output**: Deployment name, READY, UP-TO-DATE, AVAILABLE, AGE.  
**Frequency**: Deployment monitoring.

### Get Platform-System Services
```bash
kubectl get svc -n platform-system
```
**Description**: Lists service resources in platform-system namespace.  
**Context**: Verifies service endpoints and port mappings.  
**Expected Output**: Service name, TYPE, CLUSTER-IP, EXTERNAL-IP, PORT(S), AGE.  
**Frequency**: Service verification.

### Wait for NGINX Pods Ready
```bash
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=ingress-nginx -n platform-system --timeout=120s
```
**Description**: Waits for NGINX pods to reach ready state.  
**Context**: Ensures NGINX is fully operational before proceeding.  
**Expected Output**: "pod/ingress-nginx-controller-... condition met".  
**Frequency**: Post-NGINX installation.

---

## 6. Troubleshooting & Advanced Commands

### Get Pod Logs
```bash
kubectl logs <pod-name> -n <namespace>
```
**Description**: Displays logs from a specific pod.  
**Context**: Debugging pod startup issues or runtime errors.  
**Expected Output**: Application logs from the pod.  
**Frequency**: When pods fail to start or show errors.

### Describe Pod
```bash
kubectl describe pod <pod-name> -n <namespace>
```
**Description**: Shows detailed information about a pod including events and status.  
**Context**: Troubleshooting pod scheduling or resource issues.  
**Expected Output**: Complete pod specification and event history.  
**Frequency**: When pods are in Pending or CrashLoopBackOff state.

### Check Persistent Volume Claims
```bash
kubectl get pvc -n <namespace>
```
**Description**: Lists persistent volume claims in a namespace.  
**Context**: Verifies storage provisioning for stateful components.  

---

## 7. Session Commands Used

### Run platform startup script
```bash
bash scripts/start-platform.sh
```
**Description**: Creates or recreates the k3d cluster and installs core platform components using the startup script.
**Context**: Used to apply the corrected k3d config and install platform Helm charts.

### Verify platform health
```bash
bash scripts/verify-platform.sh
```
**Description**: Executes the platform health verification script.
**Context**: Used to confirm cluster readiness, namespace creation, storage binding, and Helm releases.

### Wait for Prometheus deployment
```bash
kubectl --kubeconfig=scripts/.k3d-platform-cluster-config wait --for=condition=available deployment/prometheus-server -n platform-system --timeout=300s
```
**Description**: Waits for Prometheus server deployment availability before proceeding.
**Context**: Used during troubleshooting when Prometheus needed extra startup time.

### Inspect k3d container mounts
```bash
docker inspect k3d-platform-cluster-server-0 --format '{{json .Mounts}}'
```
**Description**: Shows Docker mount configuration for the k3d server container.
**Context**: Used to verify the /data host bind mount is present inside the cluster container.

### Execute path-safe command inside k3d server container
```bash
docker exec k3d-platform-cluster-server-0 sh -c 'test -d "/data"'
```
**Description**: Runs a shell command inside the k3d server container without Git Bash path translation.
**Context**: Used to verify /data is mounted and available in the container.

### Run data platform installation script
```bash
bash scripts/install-data-platform.sh
```
**Description**: Executes the data platform installation script for Kafka cluster and Kafka Connect.
**Context**: Deploys Kafka cluster, Kafka Connect, and related data platform components.
**Frequency**: Once, after core platform is running, or when resetting data platform.
**Note**: Automatically waits for resources to be ready; skips if already deployed.

### Copy kubeconfig to default location
```bash
cp infrastructure/k3d/kube-config.yaml ~/.kube/config
```
**Description**: Copies the cluster kubeconfig to the default kubectl config location.
**Context**: Allows kubectl to automatically find the cluster config without environment variables.
**Frequency**: Once, during initial setup or after config updates.
**Windows Path**: `~\.kube\config` resolves to `%USERPROFILE%\.kube\config`

### Fix kubeconfig for local access
```bash
sed -i 's/host\.docker\.internal/127.0.0.1/g' infrastructure/k3d/kube-config.yaml
```
**Description**: Replaces host.docker.internal with 127.0.0.1 for Windows/WSL2 compatibility.
**Context**: Ensures kubectl can resolve API server address from Windows host.
**Frequency**: Once, after generating kubeconfig.
**Note**: Git Bash sed uses `-i` flag; WSL2 native sed may require `-i ''`.

**Expected Output**: PVC name, STATUS, VOLUME, CAPACITY, ACCESS MODES.  
**Frequency**: When components with persistent storage fail to start.

### Check Persistent Volumes
```bash
kubectl get pv
```
**Description**: Lists all persistent volumes in the cluster.  
**Context**: Verifies storage availability and binding.  
**Expected Output**: PV name, CAPACITY, ACCESS MODES, RECLAIM POLICY, STATUS.  
**Frequency**: Storage troubleshooting.

### Watch Pod Changes
```bash
kubectl get pods -A -w
```
**Description**: Continuously watches pod status changes across all namespaces.  
**Context**: Real-time monitoring during deployment.  
**Expected Output**: Live updates of pod status changes.  
**Frequency**: During large deployments.

### Check Certificate Status
```bash
kubectl get certificate -n platform-system
```
**Description**: Lists TLS certificates managed by cert-manager.  
**Context**: Verifies certificate provisioning for secure services.  
**Expected Output**: Certificate name, READY, SECRET, AGE.  
**Frequency**: Post-cert-manager installation, TLS troubleshooting.

### Get Pod Name by Label
```bash
kubectl get pods -l <label-selector> -n <namespace> -o jsonpath='{.items[0].metadata.name}'
```
**Description**: Extracts the name of the first pod matching a label selector.  
**Context**: Getting specific pod names for log inspection or debugging.  
**Expected Output**: Pod name string.  
**Frequency**: When targeting specific pods for operations.

### Docker Resource Monitoring
```bash
docker stats --no-stream
```
**Description**: Shows current resource usage for all Docker containers.  
**Context**: Monitoring CPU, memory, and I/O usage of k3d cluster containers.  
**Expected Output**: Resource usage table for all containers.  
**Frequency**: Resource troubleshooting, performance monitoring.

---

## 7. Access Points & Credentials

### Component URLs (When Ready)
- **Prometheus**: http://localhost:9090
- **Grafana**: http://localhost:3000 (admin / GrafanaDevPassword123!)
- **Rancher**: https://localhost:9443 (bootstrap: RancherDevPassword123!)
- **HTTP Ingress**: http://localhost:8080
- **HTTPS Ingress**: https://localhost:8443
- **Kafka External**: localhost:9092

### Default Credentials
- **Grafana**: admin / GrafanaDevPassword123!
- **Rancher**: bootstrap / RancherDevPassword123!
- **Prometheus**: No authentication (internal use)
- **Kafka**: Plain text (no authentication for dev)

---

## 8. Command Categories Summary

| Category | Commands | Purpose |
|----------|----------|---------|
| **Setup** | docker ps, kubectl get nodes, cluster-info | Verify cluster readiness |
| **Resources** | free -h, docker stats | Monitor system resources |
| **Namespaces** | kubectl apply -f, get namespaces | Manage namespaces |
| **Helm** | repo add/update/list | Configure chart repositories |
| **Install** | helm upgrade --install | Deploy platform components |
| **Monitor** | kubectl get pods/svc/deployments | Check deployment status |
| **Debug** | kubectl logs/describe | Troubleshoot issues |
| **Storage** | kubectl get pvc/pv | Verify persistent storage |

---

## 9. Quick Reference

### Pre-Installation Checklist
```bash
docker ps
kubectl get nodes
kubectl cluster-info
docker stats --no-stream
```

### Post-Installation Verification
```bash
kubectl get pods -n platform-system
kubectl get pods -n kafka
helm list -A
kubectl get svc -n platform-system
```

### Troubleshooting Pod Issues
```bash
kubectl describe pod <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace>
kubectl get events -n <namespace>
```

### Resource Monitoring
```bash
docker stats --no-stream
kubectl get pvc -n platform-system
kubectl top pods -n platform-system
```

---

**Note**: This document will be updated as new commands are used during the platform setup process. All commands are executed in the project root directory (`d:\Repos\platform-engineering-lab`).

---

## 10. Platform Lifecycle Scripts

### Start Platform Script
```bash
./scripts/start-platform.sh
```
**Purpose**: Automated platform startup with all components  
**Includes**: Cluster creation, namespace setup, Helm installations  
**Time**: ~15-30 minutes for full deployment

### Stop Platform Script
```bash
./scripts/stop-platform.sh
```
**Purpose**: Graceful platform shutdown with cleanup  
**Phases**: Drain nodes → Uninstall releases → Delete PVCs → Delete namespaces → Stop cluster  
**Interactive**: Asks for optional cleanup confirmations  
**Output**: Timestamped logs in co-pilot-check-log/stop-*.log

---

## 11. Helm Release Troubleshooting

### Upgrade Helm Release with New Values
```bash
helm upgrade <release-name> <chart-repo>/<chart-name> \
    -f path/to/values.yaml \
    --namespace <namespace>
```
**Description**: Updates an existing Helm release with new configuration values.  
**Context**: Used when values.yaml changes need to be applied to running components.  
**Expected Output**: "Release <name> has been upgraded."  
**Common Uses**: Resource limit changes, probe timeout adjustments, config updates.

### Rollback Helm Release
```bash
helm rollback <release-name> [revision] -n <namespace>
```
**Description**: Reverts a Helm release to a previous version.  
**Context**: Recovering from failed upgrades or configuration mistakes.  
**Expected Output**: "Release <name> has been rolled back to revision X."  
**Parameters**: Omit revision to rollback to previous version.

### Force Delete Persistent Volume Claim
```bash
kubectl delete pvc <pvc-name> -n <namespace> --ignore-not-found=true
```
**Description**: Removes a PVC, potentially freeing stuck persistent volumes.  
**Context**: Resolving permission issues or freeing storage for redeployment.  
**Expected Output**: "persistentvolumeclaim <name> deleted" or "not found warning".  
**Caution**: Data in PVC will be lost permanently.

### Force Delete Pods
```bash
kubectl delete pods -l <label-selector> -n <namespace> --grace-period=0 --force
```
**Description**: Immediately terminates pods without waiting for graceful shutdown.  
**Context**: Forcing pod restart when stuck or unresponsive.  
**Expected Output**: "pod <name> force deleted".  
**Warning**: May cause data loss if workload wasn't prepared for immediate termination.

---

**Last Commands Used During Session**:
- `kubectl get pods -A --sort-by=.metadata.namespace` (comprehensive pod status)
- `kubectl get svc -n platform-system` (service verification)
- `helm upgrade grafana grafana/grafana -f platform/observability/grafana/values.yaml` (Grafana upgrade)
- `helm upgrade rancher rancher-latest/rancher -f platform/rancher/values.yaml` (Rancher upgrade)
- `helm rollback rancher -n platform-system` (recovery from stuck upgrade)
- `kubectl delete pvc grafana -n platform-system` (cleanup for fresh start)
- `kubectl delete pods -l app=grafana -n platform-system --grace-period=0 --force` (force pod restart)
- Status checks with `kubectl get pods/deployments/pvc` (validation)

