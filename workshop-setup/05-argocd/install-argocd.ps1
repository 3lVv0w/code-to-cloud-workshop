<#
==============================================================================
Script: install-argocd.ps1
Purpose: Bootstrap Argo CD GitOps engine on local or remote Kubernetes cluster (Windows)
==============================================================================
#>

[CmdletBinding()]
param()

Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "  Bootstrapping Argo CD GitOps Operator Engine (Windows)" -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host ""

# 1. Verify cluster connection
Write-Host "Verifying cluster accessibility..."
try {
    kubectl cluster-info 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Cluster unreachable"
    }
} catch {
    Write-Host "[!] No reachable Kubernetes cluster found. Please start Docker Desktop Kubernetes, kind, or minikube first." -ForegroundColor Yellow
    exit 1
}

# 2. Create dedicated argocd namespace
Write-Host "Creating argocd namespace..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

# 3. Install official Argo CD manifests
Write-Host "Applying official Argo CD manifests..."
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# 4. Wait for components to become healthy
Write-Host "Waiting for Argo CD API server and Controller to be ready..."
try {
    kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=180s
} catch {
    Write-Host "[WARN] Timeout waiting for rollout, checking current status..." -ForegroundColor Yellow
}

# 5. Extract initial admin password
Write-Host "`n[OK] Argo CD successfully bootstrapped!" -ForegroundColor Green
Write-Host "------------------------------------------------------"
Write-Host "To access the Web UI:"
Write-Host "1. Run port-forward in a separate PowerShell terminal:"
Write-Host "   kubectl port-forward svc/argocd-server -n argocd 8080:443" -ForegroundColor Cyan
Write-Host ""
Write-Host "2. Open browser at: https://localhost:8080"
Write-Host "   Username: admin"

$encodedPass = kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>$null
if ($encodedPass) {
    $decodedBytes = [System.Convert]::FromBase64String($encodedPass)
    $password = [System.Text.Encoding]::UTF8.GetString($decodedBytes)
    Write-Host "   Password: $password" -ForegroundColor Green
} else {
    Write-Host "   Password: (Set your own password or check secret)" -ForegroundColor Gray
}
Write-Host "------------------------------------------------------"
