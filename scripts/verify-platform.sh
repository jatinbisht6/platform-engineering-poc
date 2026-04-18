#!/bin/bash

# =========================================
# verify-platform.sh
# Comprehensive platform health check
# Validates cluster, storage, networking, and components
# =========================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
KUBECONFIG_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/.k3d-platform-cluster-config"
export KUBECONFIG="$KUBECONFIG_FILE"
EXPECTED_NODES=3
EXPECTED_NAMESPACES=("platform-system" "kafka" "data-platform" "kube-system")

# Counters
PASSED=0
FAILED=0
WARNINGS=0

# Helper functions
print_header() {
    echo -e "\n${BLUE}=====================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}=====================================${NC}\n"
}

check_pass() {
    echo -e "${GREEN}✅ PASS${NC}: $1"
    ((PASSED++))
}

check_fail() {
    echo -e "${RED}❌ FAIL${NC}: $1"
    ((FAILED++))
}

check_warn() {
    echo -e "${YELLOW}⚠️  WARN${NC}: $1"
    ((WARNINGS++))
}

# Main verification functions

verify_cluster_running() {
    print_header "1. Cluster Status"
    
    if ! command -v k3d &> /dev/null; then
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
    
    if kubectl cluster-info &> /dev/null; then
        check_pass "kubectl can communicate with cluster"
    else
        check_fail "kubectl cannot communicate with cluster"
        return
    fi
}

verify_nodes() {
    print_header "3. Kubernetes Nodes"
    
    READY_NODES=$(kubectl get nodes --no-headers | grep -c "Ready")
    
    if [ "$READY_NODES" -eq "$EXPECTED_NODES" ]; then
        check_pass "All $EXPECTED_NODES nodes are Ready"
        kubectl get nodes -o wide
    else
        check_fail "Expected $EXPECTED_NODES nodes Ready, found $READY_NODES"
        kubectl get nodes -o wide
    fi
}

verify_namespaces() {
    print_header "4. Kubernetes Namespaces"
    
    for ns in "${EXPECTED_NAMESPACES[@]}"; do
        if kubectl get namespace "$ns" &> /dev/null; then
            check_pass "Namespace '$ns' exists"
        else
            check_fail "Namespace '$ns' not found"
        fi
    done
}

verify_storage_class() {
    print_header "5. Storage Class"
    
    if kubectl get storageclass local-path &> /dev/null; then
        check_pass "StorageClass 'local-path' exists"
    else
        check_fail "StorageClass 'local-path' not found"
        return
    fi
    
    IS_DEFAULT=$(kubectl get storageclass local-path -o jsonpath='{.metadata.annotations.storageclass\.kubernetes\.io/is-default-class}')
    if [ "$IS_DEFAULT" == "true" ]; then
        check_pass "StorageClass 'local-path' is set as default"
    else
        check_warn "StorageClass 'local-path' is not set as default"
    fi
}

verify_pvcs() {
    print_header "6. Persistent Volume Claims"
    
    PVC_COUNT=$(kubectl get pvc -A --no-headers 2>/dev/null | wc -l)
    
    if [ "$PVC_COUNT" -gt 0 ]; then
        check_pass "Found $PVC_COUNT PVC(s) across cluster"
        kubectl get pvc -A
        
        # Check for unbound PVCs
        UNBOUND=$(kubectl get pvc -A --no-headers | grep -c "Pending" || true)
        if [ "$UNBOUND" -eq 0 ]; then
            check_pass "All PVCs are bound"
        else
            check_warn "$UNBOUND PVC(s) still pending"
        fi
    else
        check_warn "No PVCs found (may be expected for initial deployment)"
    fi
}

verify_core_components() {
    print_header "7. Core Components Status"
    
    # Check required core deployments
    CORE_COMPONENTS=(
        "kube-system:coredns"
        "kube-system:local-path-provisioner"
        "platform-system:ingress-nginx-controller"
        "platform-system:cert-manager"
        "platform-system:prometheus-server"
    )
    
    for component in "${CORE_COMPONENTS[@]}"; do
        NS=$(echo "$component" | cut -d: -f1)
        COMP=$(echo "$component" | cut -d: -f2)
        
        READY=$(kubectl get pods -n "$NS" -l app.kubernetes.io/name="$COMP" --no-headers 2>/dev/null | wc -l || echo 0)
        
        if [ "$READY" -gt 0 ]; then
            check_pass "$COMP in $NS is deployed"
        else
            check_fail "$COMP in $NS is NOT deployed"
        fi
    done
}

verify_pod_health() {
    print_header "8. Pod Health Check"
    
    # Check for CrashLoopBackOff or Error pods
    PROBLEM_PODS=$(kubectl get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded --no-headers 2>/dev/null || echo "")
    
    if [ -z "$PROBLEM_PODS" ]; then
        check_pass "No pods in error/crash state"
    else
        check_warn "Found pods with issues:"
        echo "$PROBLEM_PODS" | while read -r line; do
            echo "  $line"
        done
    fi
    
    # Check total running pods
    TOTAL_RUNNING=$(kubectl get pods -A --field-selector=status.phase=Running --no-headers | wc -l)
    check_pass "Total pods running: $TOTAL_RUNNING"
}

verify_networking() {
    print_header "9. Network Configuration"
    
    # Check Services
    SERVICES=$(kubectl get svc -A --no-headers 2>/dev/null | wc -l)
    check_pass "Found $SERVICES services across cluster"
    
    # Check Ingress
    if kubectl get ingress -A &> /dev/null; then
        INGRESS_COUNT=$(kubectl get ingress -A --no-headers 2>/dev/null | wc -l)
        if [ "$INGRESS_COUNT" -gt 0 ]; then
            check_pass "Found $INGRESS_COUNT ingress resource(s)"
        fi
    fi
    
    # Check Network Policies
    if kubectl get networkpolicy -A &> /dev/null; then
        NP_COUNT=$(kubectl get networkpolicy -A --no-headers 2>/dev/null | wc -l || echo 0)
        check_pass "Network policies configured: $NP_COUNT"
    fi
}

verify_helm_releases() {
    print_header "10. Helm Releases"
    
    if ! command -v helm &> /dev/null; then
        check_warn "Helm command not found"
        return
    fi
    
    RELEASES=$(helm list -A 2>/dev/null | tail -n +2 | wc -l)
    
    if [ "$RELEASES" -gt 0 ]; then
        check_pass "Found $RELEASES Helm release(s)"
        helm list -A
    else
        check_warn "No Helm releases found"
    fi
}

verify_api_access() {
    print_header "11. API Server Access"
    
    API_URL=$(kubectl config view -o jsonpath='{.clusters[0].cluster.server}')
    
    if [ -n "$API_URL" ]; then
        check_pass "API Server URL: $API_URL"
    else
        check_fail "Could not determine API Server URL"
        return
    fi
    
    if kubectl api-resources &> /dev/null; then
        check_pass "API Server is responsive"
    else
        check_fail "API Server is not responsive"
    fi
}

verify_local_path() {
    print_header "12. Local Path Provisioner Configuration"
    
    if kubectl get configmap local-path-config -n kube-system &> /dev/null; then
        check_pass "Local Path ConfigMap exists"
        
        CONFIG=$(kubectl get configmap local-path-config -n kube-system -o jsonpath='{.data.config\.json}')
        if echo "$CONFIG" | grep -q '"/data"'; then
            check_pass "Local Path configured to use '/data'"
        else
            check_warn "Local Path may not be configured for '/data' mount"
        fi
    else
        check_fail "Local Path ConfigMap not found"
    fi
}

verify_docker_volumes() {
    print_header "13. Docker Volume Mounts"
    
    if ! command -v docker &> /dev/null; then
        check_warn "Docker command not found"
        return
    fi
    
    # Check if D drive is mounted in containers
    SERVER_NODE="k3d-platform-cluster-server-0"
    
    if docker ps --filter "name=$SERVER_NODE" --format "{{.Names}}" | grep -q "$SERVER_NODE"; then
        check_pass "Server node container is running"
        
        # Try to access /data path
        if docker exec "$SERVER_NODE" test -d "/data" 2>/dev/null; then
            check_pass "Volume mount '/data' is accessible in containers"
        else
            check_warn "Volume mount '/data' not found in containers"
        fi
    else
        check_fail "Server node container is not running"
    fi
}

verify_permissions() {
    print_header "14. File Permissions & Directory Structure"
    
    # Check D:\data directory
    if [ -d "/d/data" ]; then
        check_pass "D:\\data directory exists"
    elif [ -d "D:\\data" ]; then
        check_pass "D:\\data directory exists"
    else
        check_warn "D:\\data directory not found on host"
    fi
    
    # Check if we can write to the data directory
    if docker exec k3d-platform-cluster-server-0 touch /data/test-write.txt 2>/dev/null; then
        check_pass "Write access to /data verified"
        docker exec k3d-platform-cluster-server-0 rm /data/test-write.txt
    else
        check_warn "Could not verify write access to /data"
    fi
}

generate_summary() {
    print_header "VERIFICATION SUMMARY"
    
    TOTAL=$((PASSED + FAILED + WARNINGS))
    
    echo -e "${GREEN}✅ Passed: $PASSED${NC}"
    echo -e "${RED}❌ Failed: $FAILED${NC}"
    echo -e "${YELLOW}⚠️  Warnings: $WARNINGS${NC}"
    echo -e "📊 Total checks: $TOTAL\n"
    
    if [ "$FAILED" -eq 0 ]; then
        echo -e "${GREEN}🎉 All critical checks passed!${NC}\n"
        return 0
    else
        echo -e "${RED}⚠️  Some checks failed. Review above for details.${NC}\n"
        return 1
    fi
}

generate_status_report() {
    print_header "PLATFORM STATUS REPORT"
    
    echo "Cluster: $(k3d cluster list | grep platform-cluster | awk '{print $1, "Servers:", $2, "Agents:", $3}')"
    echo "Nodes Ready: $(kubectl get nodes --no-headers | grep -c "Ready")/3"
    echo "Pods Running: $(kubectl get pods -A --field-selector=status.phase=Running --no-headers | wc -l)"
    echo "Namespaces: $(kubectl get namespaces --no-headers | wc -l)"
    echo "Storage Classes: $(kubectl get storageclass --no-headers | wc -l)"
    echo "PVCs: $(kubectl get pvc -A --no-headers 2>/dev/null | wc -l)"
    echo "Services: $(kubectl get svc -A --no-headers | wc -l)"
    
    echo -e "\n${BLUE}Connected Services:${NC}"
    kubectl get svc -A --no-headers | grep -E "ingress-nginx|prometheus|grafana|rancher" || echo "  (See Helm releases for details)"
    
    echo -e "\n${BLUE}Available Access Points:${NC}"
    echo "  Prometheus: http://localhost:9090"
    echo "  Grafana: http://localhost:3000 (if deployed)"
    echo "  Rancher: https://localhost:9443 (if deployed)"
    echo "  Ingress HTTP: http://localhost:8080"
    echo "  Ingress HTTPS: https://localhost:8443"
}

# Main execution
main() {
    echo -e "${BLUE}"
    cat << "EOF"
  ╔═══════════════════════════════════════════╗
  ║   Platform Engineering Lab - Verifier    ║
  ║        Comprehensive Health Check         ║
  ╚═══════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    
    verify_cluster_running
    verify_kubeconfig
    verify_nodes
    verify_namespaces
    verify_storage_class
    verify_pvcs
    verify_core_components
    verify_pod_health
    verify_networking
    verify_helm_releases
    verify_api_access
    verify_local_path
    verify_docker_volumes
    verify_permissions
    
    generate_status_report
    generate_summary
}

main
