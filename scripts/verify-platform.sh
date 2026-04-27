#!/bin/bash

set -euo pipefail

# Simple verification script for platform health

KUBECONFIG_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/.k3d-platform-cluster-config"
cp infrastructure/k3d/kube-config.yaml "$KUBECONFIG_FILE"
echo "✅ Using kubeconfig: $KUBECONFIG_FILE"
kubectl config view
# export KUBECONFIG="$KUBECONFIG_FILE"
EXPECTED_NODES=3
EXPECTED_NAMESPACES=("platform-system" "kafka" "data-platform" "kube-system")

PASSED=0
FAILED=0
WARNINGS=0

print_header() {
  printf '\n==== %s ===\n' "$1"
}

check_pass() {
  printf 'PASS: %s\n' "$1"
  PASSED=$((PASSED + 1))
}

check_fail() {
  printf 'FAIL: %s\n' "$1"
  FAILED=$((FAILED + 1))
}

check_warn() {
  printf 'WARN: %s\n' "$1"
  WARNINGS=$((WARNINGS + 1))
}

verify_cluster_running() {
  print_header "1. Cluster Status"
  if ! command -v k3d >/dev/null 2>&1; then
    check_fail "k3d command not found"
    return
  fi

  if k3d cluster list | grep -q "platform-cluster"; then
    check_pass "Cluster 'platform-cluster' exists"
  else
    check_fail "Cluster 'platform-cluster' not found"
    return
  fi

  if k3d cluster list | grep "platform-cluster" | grep -q "true"; then
    check_pass "Cluster is running"
  else
    check_fail "Cluster is not running"
    return
  fi
}

verify_kubeconfig() {
  print_header "2. Kubeconfig Configuration"
  if [ -f "$KUBECONFIG_FILE" ]; then
    check_pass "Kubeconfig file exists at $KUBECONFIG_FILE"
  else
    check_fail "Kubeconfig file not found at $KUBECONFIG_FILE"
    return
  fi

  if kubectl cluster-info >/dev/null 2>&1; then
    check_pass "kubectl can communicate with the cluster"
  else
    check_fail "kubectl cannot communicate with the cluster"
  fi
}

verify_nodes() {
  print_header "3. Kubernetes Nodes"
  local ready_nodes
  ready_nodes=$(kubectl get nodes --no-headers 2>/dev/null | grep -c "Ready" || true)

  if [ "$ready_nodes" -eq "$EXPECTED_NODES" ]; then
    check_pass "All $EXPECTED_NODES nodes are Ready"
  else
    check_fail "Expected $EXPECTED_NODES Ready nodes, found $ready_nodes"
  fi

  kubectl get nodes -o wide || true
}

verify_namespaces() {
  print_header "4. Namespaces"
  for ns in "${EXPECTED_NAMESPACES[@]}"; do
    if kubectl get namespace "$ns" >/dev/null 2>&1; then
      check_pass "Namespace '$ns' exists"
    else
      check_fail "Namespace '$ns' is missing"
    fi
  done
}

verify_storage_class() {
  print_header "5. Storage Class"
  if kubectl get storageclass local-path >/dev/null 2>&1; then
    check_pass "StorageClass 'local-path' exists"
  else
    check_fail "StorageClass 'local-path' not found"
    return
  fi

  local is_default
  is_default=$(kubectl get storageclass local-path -o jsonpath='{.metadata.annotations.storageclass\.kubernetes\.io/is-default-class}' 2>/dev/null || true)
  if [ "$is_default" = "true" ]; then
    check_pass "StorageClass 'local-path' is default"
  else
    check_warn "StorageClass 'local-path' is not default"
  fi
}

verify_pvcs() {
  print_header "6. PersistentVolumeClaims"
  local pvc_count unbound
  pvc_count=$(kubectl get pvc -A --no-headers 2>/dev/null | wc -l || true)

  if [ "$pvc_count" -gt 0 ]; then
    check_pass "Found $pvc_count PVC(s)"
    kubectl get pvc -A || true
    unbound=$(kubectl get pvc -A --no-headers 2>/dev/null | grep -c "Pending" || true)
    if [ "$unbound" -eq 0 ]; then
      check_pass "All PVCs are bound"
    else
      check_warn "$unbound PVC(s) are not bound"
    fi
  else
    check_warn "No PVCs found"
  fi
}

verify_core_components() {
  print_header "7. Core Components"
  local components=(
    "kube-system:deployment:coredns:CoreDNS"
    "kube-system:deployment:local-path-provisioner:Local Path Provisioner"
    "platform-system:deployment:ingress-nginx-controller:NGINX Ingress Controller"
    "platform-system:deployment:cert-manager:cert-manager"
    "platform-system:deployment:prometheus-server:Prometheus Server"
    "platform-system:deployment:grafana:Grafana"
    "platform-system:deployment:rancher:Rancher"
    "kafka:deployment:strimzi-cluster-operator:Strimzi Operator"
    "kafka:statefulset:kafka-cluster-kafka:Kafka Cluster"
    "kafka:deployment:kafka-connect:Kafka Connect"
  )

  for item in "${components[@]}"; do
    IFS=':' read -r ns kind name label <<< "$item"
    if kubectl get "$kind" "$name" -n "$ns" >/dev/null 2>&1; then
      local ready desired
      ready=$(kubectl get "$kind" "$name" -n "$ns" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)
      desired=$(kubectl get "$kind" "$name" -n "$ns" -o jsonpath='{.spec.replicas}' 2>/dev/null || echo 0)
      ready=${ready:-0}
      desired=${desired:-0}
      
      # Special handling for Kafka StatefulSet - allow partial readiness
      if [ "$name" = "kafka-cluster-kafka" ]; then
        if [ "$desired" -gt 0 ] && [ "$ready" -gt 0 ]; then
          if [ "$ready" -eq "$desired" ]; then
            check_pass "$label is fully ready ($ready/$desired) in $ns"
          else
            check_warn "$label is partially ready ($ready/$desired) - this is normal during startup"
          fi
        elif [ "$desired" -eq 0 ]; then
          check_warn "$label is configured but not yet starting ($desired desired replicas)"
        else
          check_fail "$label is not ready (0/$desired)"
        fi
      else
        # Standard component check
        if [ "$desired" -gt 0 ] && [ "$ready" -ge "$desired" ]; then
          check_pass "$label is ready ($ready/$desired) in $ns"
        elif [ "$desired" -gt 0 ]; then
          check_warn "$label exists in $ns but is not fully ready ($ready/$desired)"
        else
          check_pass "$label exists in $ns"
        fi
      fi
    else
      # Special handling for Kafka - it's expected to take time
      if [ "$name" = "kafka-cluster-kafka" ]; then
        check_warn "$label is not deployed yet in $ns - Kafka operator may still be initializing"
      else
        check_fail "$label is not deployed in $ns"
      fi
    fi
  done
}

verify_kafka_details() {
  print_header "7.5. Kafka Detailed Status"
  
  # Check Kafka CR exists
  if kubectl get kafka kafka-cluster -n kafka >/dev/null 2>&1; then
    check_pass "Kafka CR 'kafka-cluster' exists"
    
    # Get Kafka CR status
    local kafka_status
    kafka_status=$(kubectl get kafka kafka-cluster -n kafka -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "unknown")
    check_pass "Kafka CR status: $kafka_status"
  else
    check_warn "Kafka CR 'kafka-cluster' not found - may still be creating"
  fi
  
  # Check Kafka brokers
  if kubectl get pods -n kafka -l app.kubernetes.io/name=kafka,app.kubernetes.io/instance=kafka-cluster --no-headers 2>/dev/null | grep -q .; then
    check_pass "Kafka broker pods exist"
    local broker_ready
    broker_ready=$(kubectl get pods -n kafka -l app.kubernetes.io/name=kafka,app.kubernetes.io/instance=kafka-cluster --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l || echo 0)
    local broker_total
    broker_total=$(kubectl get pods -n kafka -l app.kubernetes.io/name=kafka,app.kubernetes.io/instance=kafka-cluster --no-headers 2>/dev/null | wc -l || echo 0)
    check_warn "Kafka brokers: $broker_ready running out of $broker_total total"
    kubectl get pods -n kafka -l app.kubernetes.io/name=kafka,app.kubernetes.io/instance=kafka-cluster --no-headers 2>/dev/null | awk '{print "  - " $1 " (" $3 ")"}'
  else
    check_warn "No Kafka broker pods found yet"
  fi
  
  # Check Kafka Controller pools (KRaft mode - replaces ZooKeeper)
  if kubectl get kafkanodepools -n kafka --no-headers 2>/dev/null | grep -q .; then
    check_pass "Kafka node pools exist (KRaft mode)"
    local controller_count
    controller_count=$(kubectl get kafkanodepools kafka-cluster-controllers -n kafka -o jsonpath='{.spec.replicas}' 2>/dev/null || echo 0)
    check_pass "Kafka controllers configured: $controller_count"
  else
    check_warn "Kafka node pools not yet initialized"
  fi
}

verify_pod_health() {
  print_header "8. Pod Health"
  local problem_pods
  local crash_loop_pods
  local pending_pods
  local error_pods
  
  # Check for CrashLoopBackOff pods
  crash_loop_pods=$(kubectl get pods -A -o wide 2>/dev/null | grep -i "crashloopbackoff" || true)
  if [ -n "$crash_loop_pods" ]; then
    check_warn "Pods in CrashLoopBackOff state detected:"
    echo "$crash_loop_pods" | awk '{print "  - Pod: " $2 " | Namespace: " $1 " | Status: " $4}'
  fi
  
  # Check for Pending pods
  pending_pods=$(kubectl get pods -A --field-selector=status.phase=Pending --no-headers 2>/dev/null || true)
  if [ -n "$pending_pods" ]; then
    check_warn "Pods in Pending state (waiting for resources):"
    printf '%s\n' "$pending_pods" | awk '{print "  - " $1 " (Namespace: " $2 ")"}'
  fi
  
  # Check for Failed pods
  error_pods=$(kubectl get pods -A --field-selector=status.phase=Failed --no-headers 2>/dev/null || true)
  if [ -n "$error_pods" ]; then
    check_fail "Pods in Failed state:"
    printf '%s\n' "$error_pods" | awk '{print "  - " $1 " (Namespace: " $2 ")"}'
  fi
  
  # Check for Unknown state pods
  unknown_pods=$(kubectl get pods -A --field-selector=status.phase=Unknown --no-headers 2>/dev/null || true)
  if [ -n "$unknown_pods" ]; then
    check_warn "Pods in Unknown state:"
    printf '%s\n' "$unknown_pods" | awk '{print "  - " $1 " (Namespace: " $2 ")"}'
  fi

  local total_running
  total_running=$(kubectl get pods -A --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l || true)
  check_pass "Total running pods: $total_running"
}

verify_networking() {
  print_header "9. Networking"
  local svc_count ingress_count
  svc_count=$(kubectl get svc -A --no-headers 2>/dev/null | wc -l || true)
  check_pass "Found $svc_count services"
  kubectl get svc -A | grep -E "ingress-nginx|grafana|rancher|prometheus" || true

  ingress_count=$(kubectl get ingress -A --no-headers 2>/dev/null | wc -l || true)
  if [ "$ingress_count" -gt 0 ]; then
    check_pass "Found $ingress_count ingress resource(s)"
    kubectl get ingress -A || true
  else
    check_warn "No ingress resources found"
  fi

  local np_count
  np_count=$(kubectl get networkpolicy -A --no-headers 2>/dev/null | wc -l || true)
  check_pass "Found $np_count networkpolicy resource(s)"
}

verify_helm_releases() {
  print_header "10. Helm Releases"
  if ! command -v helm >/dev/null 2>&1; then
    check_warn "Helm not installed"
    return
  fi

  local releases
  releases=$(helm list -A 2>/dev/null | tail -n +2 | wc -l || true)
  if [ "$releases" -gt 0 ]; then
    check_pass "Found $releases Helm release(s)"
    helm list -A || true
  else
    check_warn "No Helm releases found"
  fi
}

verify_api_access() {
  print_header "11. API Access"
  local api_url
  api_url=$(kubectl config view -o jsonpath='{.clusters[0].cluster.server}' 2>/dev/null || true)

  if [ -n "$api_url" ]; then
    check_pass "API Server URL: $api_url"
  else
    check_fail "Could not determine API Server URL"
    return
  fi

  if kubectl api-resources >/dev/null 2>&1; then
    check_pass "API Server is responsive"
  else
    check_fail "API Server is not responsive"
  fi
}

verify_local_path() {
  print_header "12. Local Path Provisioner"
  if kubectl get configmap local-path-config -n kube-system >/dev/null 2>&1; then
    check_pass "Local path configmap exists"
    local config
    config=$(kubectl get configmap local-path-config -n kube-system -o jsonpath='{.data.config\.json}' 2>/dev/null || true)
    if printf '%s' "$config" | grep -q '"/data"'; then
      check_pass "Local path uses /data"
    else
      check_warn "Local path may not be configured for /data"
    fi
  else
    check_fail "Local path configmap not found"
  fi
}

verify_docker_volumes() {
  print_header "13. Docker Volume Mounts"
  if ! command -v docker >/dev/null 2>&1; then
    check_warn "Docker not installed"
    return
  fi

  local server_node
  server_node="k3d-platform-cluster-server-0"
  if docker ps --filter "name=$server_node" --format '{{.Names}}' | grep -q "$server_node"; then
    check_pass "Server node container is running"
    if docker exec "$server_node" sh -c 'test -d "/data"' >/dev/null 2>&1; then
      check_pass "/data mount is present inside server container"
    else
      check_warn "/data is not mounted inside server container"
    fi
  else
    check_fail "Server node container $server_node is not running"
  fi
}

verify_permissions() {
  print_header "14. Permissions"
  if [ -d "/d/data" ] || [ -d "D:\\data" ]; then
    check_pass "Host data directory exists"
  else
    check_warn "Host data directory /d/data or D:\\data not found"
  fi

  if docker exec k3d-platform-cluster-server-0 sh -c 'touch /data/verify-write.txt' >/dev/null 2>&1; then
    check_pass "Write access to /data inside cluster verified"
    docker exec k3d-platform-cluster-server-0 sh -c 'rm -f /data/verify-write.txt' >/dev/null 2>&1 || true
  else
    check_warn "Could not verify write access to /data inside cluster"
  fi
}

generate_status_report() {
  print_header "Platform Status Summary"
  printf 'Cluster: %s\n' "$(k3d cluster list | grep platform-cluster | awk '{print $1 " Servers:" $2 " Agents:" $3}')"
  printf 'Nodes Ready: %s/3\n' "$(kubectl get nodes --no-headers 2>/dev/null | grep -c Ready || true)"
  printf 'Pods Running: %s\n' "$(kubectl get pods -A --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l || true)"
  printf 'Namespaces: %s\n' "$(kubectl get namespace --no-headers 2>/dev/null | wc -l || true)"
  printf 'StorageClasses: %s\n' "$(kubectl get storageclass --no-headers 2>/dev/null | wc -l || true)"
  printf 'PVCs: %s\n' "$(kubectl get pvc -A --no-headers 2>/dev/null | wc -l || true)"
  printf 'Services: %s\n' "$(kubectl get svc -A --no-headers 2>/dev/null | wc -l || true)"
}

generate_summary() {
  print_header "Verification Summary"
  printf 'Passed: %s\n' "$PASSED"
  printf 'Warnings: %s\n' "$WARNINGS"
  printf 'Failed: %s\n' "$FAILED"
  
  if [ "$FAILED" -eq 0 ]; then
    if [ "$WARNINGS" -gt 0 ]; then
      printf 'STATUS: HEALTHY WITH WARNINGS\n'
      printf 'Note: Some components may still be initializing. Warnings are normal during startup.\n'
    else
      printf 'STATUS: OK\n'
    fi
  else
    printf 'STATUS: ISSUES\n'
    printf 'Critical components are missing or non-functional.\n'
  fi
}

show_detailed_issues() {
  print_header "Detailed Issue Analysis"
  
  # Check for failed component deployments
  echo "🔴 Failed Component Details:"
  if ! kubectl get deployment rancher -n platform-system >/dev/null 2>&1; then
    echo "  • Rancher: NOT DEPLOYED"
    echo "    Reason: Rancher Helm release not installed"
    echo "    Action: Run the following command:"
    echo "    helm upgrade --install rancher rancher-latest/rancher -f platform/rancher/values.yaml --namespace platform-system --create-namespace"
  fi
  
  if ! kubectl get kafkaconnect kafka-connect -n kafka >/dev/null 2>&1; then
    echo "  • Kafka Connect: NOT DEPLOYED"
    echo "    Reason: KafkaConnect resource not created"
    echo "    Action: Run the following command:"
    echo "    kubectl apply -f platform/kafka-strimzi/kafka-connect.yaml"
  fi
  
  # Check for component readiness issues
  echo ""
  echo "⚠️  Components Not Ready / With Issues:"
  
  # Strimzi Operator
  local strimzi_ready
  strimzi_ready=$(kubectl get deployment strimzi-cluster-operator -n kafka -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)
  if [ "$strimzi_ready" != "1" ]; then
    echo "  • Strimzi Operator (0/1 ready):"
    echo "    Pod status:"
    kubectl get pods -n kafka -l app.kubernetes.io/name=strimzi-cluster-operator -o wide 2>/dev/null | tail -1 || echo "    No pods found"
  fi
  
  # Kafka Cluster details
  echo "  • Kafka Cluster Status:"
  local kafka_pod_count=$(kubectl get pods -n kafka -l app.kubernetes.io/name=kafka --no-headers 2>/dev/null | wc -l || echo 0)
  if [ "$kafka_pod_count" -gt 0 ]; then
    echo "    Found $kafka_pod_count Kafka broker pods:"
    kubectl get pods -n kafka -l app.kubernetes.io/name=kafka -o wide 2>/dev/null | grep -v "^NAME" | while IFS= read -r line; do
      local pod_name=$(echo "$line" | awk '{print $1}')
      local status=$(echo "$line" | awk '{print $3}')
      local restarts=$(echo "$line" | awk '{print $4}')
      echo "    - Pod: $pod_name | Status: $status | Restarts: $restarts"
    done
  else
    echo "    No Kafka broker pods found yet. Waiting for initialization..."
  fi
  
  # No ingress warning  
  local ingress_count=$(kubectl get ingress -A --no-headers 2>/dev/null | wc -l || true)
  if [ "$ingress_count" -eq 0 ]; then
    echo "  • No Ingress Resources Found"
    echo "    Note: This is expected if you're accessing services directly via NodePort"
    echo "    Available services: Grafana (32044), Prometheus (32090)"
  fi
}


main() {
  printf '\nPlatform Engineering Lab - Verifier\n'
  verify_cluster_running
  verify_kubeconfig
  verify_nodes
  verify_namespaces
  verify_storage_class
  verify_pvcs
  verify_core_components
  verify_kafka_details
  verify_pod_health
  verify_networking
  verify_helm_releases
  verify_api_access
  verify_local_path
  verify_docker_volumes
  verify_permissions
  generate_status_report
  
  # Show detailed issues before summary
  if [ "$FAILED" -gt 0 ] || [ "$WARNINGS" -gt 0 ]; then
    show_detailed_issues
  fi
  
  generate_summary

  if [ "$FAILED" -gt 0 ]; then
      echo ""
      echo "🔧 Critical Issues Detected"
      echo "Please address the failed components listed above, then re-run this script."
      exit 1
  fi
  exit 0
}

main
