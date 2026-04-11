#!/bin/bash

#===============================================================================
# Platform Engineering Lab - Stop Script
#===============================================================================
# This script gracefully shuts down the Kubernetes platform by:
# 1. Draining nodes to evict pods gracefully
# 2. Uninstalling Helm releases one by one
# 3. Deleting namespaces with their resources
# 4. Stopping the k3d cluster
#
# Author: Platform Engineering Lab
# Created: April 12, 2026
#===============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CLUSTER_NAME="platform-cluster"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="${PROJECT_ROOT}/co-pilot-check-log/stop-${TIMESTAMP}.log"

#===============================================================================
# Functions
#===============================================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

print_separator() {
    echo "================================================================================" | tee -a "$LOG_FILE"
}

print_step() {
    print_separator
    echo -e "${BLUE}STEP: $1${NC}" | tee -a "$LOG_FILE"
    print_separator
}

check_prereqs() {
    log_info "Checking prerequisites..."
    
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl not found. Please install kubectl."
        exit 1
    fi
    
    if ! command -v helm &> /dev/null; then
        log_error "helm not found. Please install helm."
        exit 1
    fi
    
    if ! command -v docker &> /dev/null; then
        log_error "docker not found. Please install docker."
        exit 1
    fi
    
    if ! command -v k3d &> /dev/null; then
        log_warning "k3d not found. Will attempt to stop cluster anyway."
    fi
    
    log_success "All prerequisites met."
}

verify_cluster_connection() {
    log_info "Verifying connection to Kubernetes cluster..."
    
    if kubectl cluster-info &> /dev/null; then
        log_success "Connected to Kubernetes cluster."
    else
        log_error "Cannot connect to Kubernetes cluster. Cluster may already be down."
        return 1
    fi
}

wait_for_resource_deletion() {
    local resource_type=$1
    local namespace=$2
    local timeout=60
    local elapsed=0
    
    log_info "Waiting for $resource_type in namespace $namespace to be deleted (timeout: ${timeout}s)..."
    
    while [ $elapsed -lt $timeout ]; do
        if kubectl get "$resource_type" -n "$namespace" &> /dev/null; then
            count=$(kubectl get "$resource_type" -n "$namespace" 2>/dev/null | wc -l)
            if [ "$count" -le 1 ]; then
                log_success "$resource_type in namespace $namespace successfully deleted."
                return 0
            fi
            echo -n "."
            sleep 2
            elapsed=$((elapsed + 2))
        else
            log_success "$resource_type in namespace $namespace successfully deleted."
            return 0
        fi
    done
    
    log_warning "Timeout waiting for $resource_type deletion. Continuing..."
    return 0
}

#===============================================================================
# Phase 1: Drain Nodes
#===============================================================================

phase_drain_nodes() {
    print_step "Phase 1: Draining Kubernetes Nodes"
    
    log_info "Getting list of nodes..."
    nodes=$(kubectl get nodes -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
    
    if [ -z "$nodes" ]; then
        log_warning "No nodes found. Skipping drain phase."
        return 0
    fi
    
    for node in $nodes; do
        log_info "Draining node: $node"
        
        if kubectl drain "$node" \
            --ignore-daemonsets \
            --delete-emptydir-data \
            --timeout=60s \
            2>&1 | tee -a "$LOG_FILE"; then
            log_success "Node $node drained successfully."
        else
            log_warning "Failed to drain node $node. Continuing..."
        fi
    done
}

#===============================================================================
# Phase 2: Uninstall Helm Releases
#===============================================================================

phase_uninstall_helm() {
    print_step "Phase 2: Uninstalling Helm Releases"
    
    # Define uninstall order (reverse of install order for dependencies)
    local releases=(
        "rancher:platform-system"
        "kafka-operator:kafka"
        "cert-manager:platform-system"
        "grafana:platform-system"
        "prometheus:platform-system"
        "ingress-nginx:platform-system"
    )
    
    for release_info in "${releases[@]}"; do
        IFS=':' read -r release_name namespace <<< "$release_info"
        
        log_info "Checking if Helm release '$release_name' exists in namespace '$namespace'..."
        
        if helm list -n "$namespace" 2>/dev/null | grep -q "^$release_name"; then
            log_info "Uninstalling Helm release: $release_name from namespace $namespace"
            
            if helm uninstall "$release_name" -n "$namespace" --wait 2>&1 | tee -a "$LOG_FILE"; then
                log_success "Release $release_name uninstalled successfully."
                wait_for_resource_deletion "pods" "$namespace"
            else
                log_warning "Failed to uninstall release $release_name. Continuing..."
            fi
        else
            log_info "Release $release_name not found. Skipping..."
        fi
        
        sleep 3
    done
}

#===============================================================================
# Phase 3: Delete Persistent Volume Claims
#===============================================================================

phase_delete_pvcs() {
    print_step "Phase 3: Deleting Persistent Volume Claims"
    
    local namespaces=("platform-system" "kafka")
    
    for namespace in "${namespaces[@]}"; do
        log_info "Checking for PVCs in namespace: $namespace"
        
        if kubectl get namespace "$namespace" &> /dev/null; then
            pvc_count=$(kubectl get pvc -n "$namespace" 2>/dev/null | wc -l)
            
            if [ "$pvc_count" -gt 1 ]; then
                log_info "Found PVCs in namespace $namespace. Deleting..."
                
                if kubectl delete pvc --all -n "$namespace" --timeout=30s 2>&1 | tee -a "$LOG_FILE"; then
                    log_success "PVCs in namespace $namespace deleted."
                    wait_for_resource_deletion "pvc" "$namespace"
                else
                    log_warning "Failed to delete PVCs in namespace $namespace."
                fi
            else
                log_info "No PVCs found in namespace $namespace."
            fi
        fi
        
        sleep 2
    done
}

#===============================================================================
# Phase 4: Delete Custom Namespaces
#===============================================================================

phase_delete_namespaces() {
    print_step "Phase 4: Deleting Custom Namespaces"
    
    local namespaces=("kafka" "data-platform" "platform-system")
    
    for namespace in "${namespaces[@]}"; do
        log_info "Checking if namespace exists: $namespace"
        
        if kubectl get namespace "$namespace" &> /dev/null; then
            log_info "Deleting namespace: $namespace"
            
            if kubectl delete namespace "$namespace" --timeout=120s 2>&1 | tee -a "$LOG_FILE"; then
                log_success "Namespace $namespace deleted."
                wait_for_resource_deletion "namespace" "" # ns deletion check
            else
                log_warning "Failed to delete namespace $namespace. Forcing deletion..."
                kubectl delete namespace "$namespace" --grace-period=0 --force 2>&1 | tee -a "$LOG_FILE" || true
            fi
        else
            log_info "Namespace $namespace not found."
        fi
        
        sleep 2
    done
}

#===============================================================================
# Phase 5: Stop k3d Cluster
#===============================================================================

phase_stop_cluster() {
    print_step "Phase 5: Stopping k3d Cluster"
    
    log_info "Checking cluster status..."
    
    if docker ps | grep -q "k3d-$CLUSTER_NAME"; then
        log_info "Cluster containers found. Stopping cluster..."
        
        if k3d cluster stop "$CLUSTER_NAME" 2>&1 | tee -a "$LOG_FILE"; then
            log_success "Cluster $CLUSTER_NAME stopped successfully."
            sleep 5
        else
            log_warning "Failed to stop cluster. Attempting force stop..."
            docker stop $(docker ps -q -f "label=k3d.cluster=$CLUSTER_NAME") 2>&1 || true
        fi
    else
        log_warning "Cluster containers not found. Cluster may already be stopped."
    fi
    
    log_info "Verifying cluster is stopped..."
    if docker ps | grep -q "k3d-$CLUSTER_NAME"; then
        log_warning "Cluster containers still running."
    else
        log_success "Cluster containers stopped."
    fi
}

#===============================================================================
# Phase 6: Cleanup (Optional)
#===============================================================================

phase_cleanup_optional() {
    print_step "Phase 6: Optional Cleanup"
    
    log_info "Do you want to delete k3d cluster completely? (y/n)"
    read -r response
    
    if [[ "$response" =~ ^[Yy]$ ]]; then
        log_info "Deleting k3d cluster: $CLUSTER_NAME"
        
        if k3d cluster delete "$CLUSTER_NAME" 2>&1 | tee -a "$LOG_FILE"; then
            log_success "Cluster $CLUSTER_NAME deleted completely."
        else
            log_error "Failed to delete cluster. You can manually run: k3d cluster delete $CLUSTER_NAME"
        fi
    else
        log_info "Cluster definition preserved. Run 'k3d cluster delete $CLUSTER_NAME' to delete later."
    fi
    
    log_info "Do you want to clean up volumes? (y/n)"
    read -r response
    
    if [[ "$response" =~ ^[Yy]$ ]]; then
        log_info "Cleaning up volumes directory..."
        
        if [ -d "${PROJECT_ROOT}/volumes" ]; then
            rm -rf "${PROJECT_ROOT}/volumes"/*
            log_success "Volumes cleaned."
        fi
    else
        log_info "Volumes preserved for data recovery."
    fi
}

#===============================================================================
# Error Handling
#===============================================================================

cleanup_on_error() {
    log_error "An error occurred. Checking cluster status..."
    kubectl cluster-info || log_warning "Cluster not accessible."
}

trap cleanup_on_error ERR

#===============================================================================
# Main Execution
#===============================================================================

main() {
    print_separator
    echo -e "${BLUE}                    PLATFORM ENGINEERING LAB - SHUTDOWN${NC}" | tee -a "$LOG_FILE"
    print_separator
    
    log_info "Shutdown started at $(date)"
    log_info "Log file: $LOG_FILE"
    
    check_prereqs
    
    if ! verify_cluster_connection; then
        log_warning "Cluster not accessible. Attempting to stop k3d cluster anyway..."
        phase_stop_cluster
        log_info "Shutdown completed."
        return 0
    fi
    
    log_info "=== STOPPING KUBERNETES PLATFORM ==="
    log_info "This will:"
    log_info "1. Drain all nodes"
    log_info "2. Uninstall all Helm releases"
    log_info "3. Delete persistent volumes"
    log_info "4. Delete namespaces"
    log_info "5. Stop the k3d cluster"
    log_info ""
    log_info "Press Enter to continue or Ctrl+C to cancel..."
    read -r
    
    # Execute phases
    phase_drain_nodes || true
    phase_uninstall_helm || true
    phase_delete_pvcs || true
    phase_delete_namespaces || true
    phase_stop_cluster
    
    # Ask for cleanup
    phase_cleanup_optional || true
    
    print_separator
    log_success "Platform shutdown completed successfully!"
    log_info "Final status:"
    docker ps -f "label=k3d.cluster=$CLUSTER_NAME" | wc -l
    log_info "Shutdown completed at $(date)"
    print_separator
}

#===============================================================================
# Script Entry Point
#===============================================================================

if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main "$@"
fi
