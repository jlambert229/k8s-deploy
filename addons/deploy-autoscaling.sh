#!/usr/bin/env bash
# Deploy autoscaling components to Talos Kubernetes cluster

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $*"
}

warn() {
    echo -e "${YELLOW}[$(date +'%H:%M:%S')] WARNING:${NC} $*"
}

error() {
    echo -e "${RED}[$(date +'%H:%M:%S')] ERROR:${NC} $*" >&2
}

check_kubeconfig() {
    if ! kubectl cluster-info &>/dev/null; then
        error "Cannot connect to cluster. Set KUBECONFIG or run:"
        echo "  export KUBECONFIG=~/.kube/talos.kubeconfig"
        exit 1
    fi
}

deploy_metrics_server() {
    log "Deploying Metrics Server..."
    kubectl apply -f "${SCRIPT_DIR}/metrics-server/metrics-server.yaml"

    log "Waiting for Metrics Server to be ready (max 120s)..."
    if kubectl wait --for=condition=ready pod -l k8s-app=metrics-server -n kube-system --timeout=120s; then
        log "✓ Metrics Server is ready"
    else
        error "Metrics Server failed to become ready"
        return 1
    fi

    # Wait a bit for metrics to be available
    sleep 10

    log "Testing metrics availability..."
    if kubectl top nodes &>/dev/null; then
        log "✓ Metrics are available"
        kubectl top nodes
    else
        warn "Metrics not yet available, may need a few more seconds"
    fi
}

deploy_vpa() {
    log "Deploying Vertical Pod Autoscaler..."
    kubectl apply -f "${SCRIPT_DIR}/vpa/vpa.yaml"

    log "Waiting for VPA components to be ready (max 120s)..."
    if kubectl wait --for=condition=ready pod -l app=vpa-admission-controller -n vpa-system --timeout=120s && \
       kubectl wait --for=condition=ready pod -l app=vpa-recommender -n vpa-system --timeout=120s && \
       kubectl wait --for=condition=ready pod -l app=vpa-updater -n vpa-system --timeout=120s; then
        log "✓ VPA is ready"
    else
        error "VPA failed to become ready"
        return 1
    fi
}

deploy_examples() {
    read -p "Deploy example HPA/VPA workloads? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log "Deploying HPA example..."
        kubectl apply -f "${SCRIPT_DIR}/examples/hpa-example.yaml"

        log "Deploying VPA example..."
        kubectl apply -f "${SCRIPT_DIR}/examples/vpa-example.yaml"

        log "✓ Examples deployed"
        echo
        echo "Monitor with:"
        echo "  kubectl get hpa nginx-demo --watch"
        echo "  kubectl describe vpa app-with-vpa"
    fi
}

show_summary() {
    echo
    log "═══════════════════════════════════════════════════════════"
    log "Autoscaling deployment complete!"
    log "═══════════════════════════════════════════════════════════"
    echo
    echo "Verify installation:"
    echo "  kubectl top nodes"
    echo "  kubectl top pods -A"
    echo "  kubectl get vpa -A"
    echo "  kubectl get hpa -A"
    echo
    echo "Next steps:"
    echo "  1. Test HPA: kubectl apply -f addons/examples/hpa-example.yaml"
    echo "  2. Test VPA: kubectl apply -f addons/examples/vpa-example.yaml"
    echo "  3. Enable node autoscaling: see AUTOSCALING.md"
    echo
    echo "Documentation: ${SCRIPT_DIR}/../AUTOSCALING.md"
}

main() {
    log "Starting autoscaling deployment..."

    check_kubeconfig

    # Deploy core components
    deploy_metrics_server || { error "Failed to deploy Metrics Server"; exit 1; }
    echo
    deploy_vpa || { error "Failed to deploy VPA"; exit 1; }
    echo

    # Optional examples
    deploy_examples

    # Summary
    show_summary
}

main "$@"
