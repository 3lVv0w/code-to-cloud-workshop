#!/usr/bin/env bash
# ==============================================================================
# Script: check-env.sh
# Purpose: Pre-flight developer environment check for Event 30 workshop
# ==============================================================================

set -eo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}======================================================${NC}"
echo -e "${BLUE}  Code to PROEN Cloud, GitOps & Argo CD Workshop     ${NC}"
echo -e "${BLUE}  Pre-Flight Environment & CLI Tooling Audit         ${NC}"
echo -e "${BLUE}======================================================${NC}\n"

ERRORS=0

check_binary() {
  local cmd=$1
  local name=$2
  local install_tip=$3

  if command -v "$cmd" >/dev/null 2>&1; then
    local version
    if [ "$cmd" = "kubectl" ]; then
      version=$(kubectl version --client 2>&1 | head -n 1 || true)
    elif [ "$cmd" = "helm" ]; then
      version=$(helm version --short 2>&1 || true)
    elif [ "$cmd" = "argocd" ]; then
      version=$(argocd version --client --short 2>&1 || true)
    elif [ "$cmd" = "cosign" ]; then
      version=$(cosign version 2>&1 | head -n 1 || true)
    else
      version=$($cmd --version 2>&1 | head -n 1 || true)
    fi
    echo -e "  [${GREEN}FOUND${NC}] ${name}: ${version}"
  else
    echo -e "  [${RED}MISSING${NC}] ${name} is NOT installed!"
    echo -e "           ${YELLOW}Tip:${NC} ${install_tip}"
    ERRORS=$((ERRORS + 1))
  fi
}

echo "1. Checking Core Container & Orchestration Tools:"
check_binary "git" "Git Version Control" "Install via brew install git or apt-get install git"
check_binary "docker" "Docker Engine / CLI" "Install Docker Desktop, OrbStack, or Colima"
check_binary "kubectl" "Kubernetes CLI (kubectl)" "brew install kubectl or https://kubernetes.io/docs/tasks/tools/"
check_binary "helm" "Helm 3 Package Manager" "brew install helm or https://helm.sh/docs/intro/install/"

echo -e "\n2. Checking GitOps & Security Verification Tools:"
check_binary "argocd" "Argo CD CLI" "brew install argocd or https://argo-cd.readthedocs.io/en/stable/cli_installation/"
check_binary "cosign" "Cosign (Sigstore)" "brew install cosign or https://docs.sigstore.dev/cosign/system_config/installation/"

echo -e "\n3. Checking Optional Productivity Utilities:"
if command -v k9s >/dev/null 2>&1; then
  echo -e "  [${GREEN}FOUND${NC}] K9s Cluster Management Terminal: $(k9s version -s 2>/dev/null || echo 'Installed')"
else
  echo -e "  [${YELLOW}OPTIONAL${NC}] k9s is recommended for terminal cluster monitoring: brew install k9s"
fi

echo -e "\n------------------------------------------------------"
if [ "$ERRORS" -eq 0 ]; then
  echo -e "${GREEN}SUCCESS: All required CLI tools are present and configured!${NC}"
  echo -e "Proceed to: cd ../02-sample-app"
  exit 0
else
  echo -e "${RED}WARNING: ${ERRORS} required tool(s) missing.${NC}"
  echo -e "Please install the missing utilities prior to hands-on exercises."
  exit 1
fi
