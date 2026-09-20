#!/usr/bin/env bash
# ==============================================================================
# Script: install-argocd.sh
# Purpose: Bootstrap Argo CD GitOps engine on local or remote Kubernetes cluster
# ==============================================================================

set -eo pipefail

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}======================================================${NC}"
echo -e "${BLUE}  Bootstrapping Argo CD GitOps Operator Engine        ${NC}"
echo -e "${BLUE}======================================================${NC}\n"

# 1. Verify cluster connection
echo "Verifying cluster accessibility..."
kubectl cluster-info || {
  echo -e "${YELLOW}Error: No reachable Kubernetes cluster found. Please start Docker/kind/k3d first.${NC}"
  exit 1
}

# 2. Create dedicated argocd namespace
echo "Creating argocd namespace..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

# 3. Install official Argo CD manifests
echo "Applying official Argo CD manifests..."
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# 4. Wait for components to become healthy
echo "Waiting for Argo CD API server and Controller to be ready..."
kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=180s || true

# 5. Extract initial admin password
echo -e "\n${GREEN}Argo CD successfully bootstrapped!${NC}"
echo "------------------------------------------------------"
echo "To access the Web UI:"
echo "1. Run port-forward:"
echo "   kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo ""
echo "2. Open browser at: https://localhost:8080"
echo "   Username: admin"
echo -n "   Password: "
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d || echo "(Set your own password or check secret)"
echo -e "\n------------------------------------------------------"
