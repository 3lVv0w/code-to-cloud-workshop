<#
==============================================================================
Script: check-env.ps1
Purpose: Pre-flight environment & CLI tooling audit for Windows PowerShell
==============================================================================
#>

[CmdletBinding()]
param()

$Host.UI.RawUI.ForegroundColor = "Cyan"
Write-Host "======================================================"
Write-Host "  Code to PROEN Cloud, GitOps & Argo CD Workshop     "
Write-Host "  Pre-Flight Environment & CLI Tooling Audit (Windows)"
Write-Host "======================================================"
$Host.UI.RawUI.ForegroundColor = "White"
Write-Host ""

$MissingCount = 0

function Test-Tool {
    param(
        [string]$Name,
        [string]$Command,
        [string]$VersionCmd,
        [string]$InstallTip,
        [bool]$Required = $true
    )

    $cmd = Get-Command $Command -ErrorAction SilentlyContinue
    if ($cmd) {
        $ver = ""
        try {
            $rawOutput = (Invoke-Expression $VersionCmd 2>$null)
            if ($rawOutput) {
                $ver = ($rawOutput | Select-Object -First 1).ToString().Trim()
            } else {
                $ver = "Detected"
            }
        } catch {
            $ver = "Detected"
        }
        Write-Host "  [FOUND] $Name: $ver" -ForegroundColor Green
    } else {
        if ($Required) {
            $script:MissingCount++
            Write-Host "  [MISSING] $Name is NOT installed!" -ForegroundColor Yellow
            Write-Host "           Install Tip: $InstallTip" -ForegroundColor Gray
        } else {
            Write-Host "  [OPTIONAL] $Name: Not installed." -ForegroundColor DarkGray
            Write-Host "           Install Tip: $InstallTip" -ForegroundColor DarkGray
        }
    }
}

Write-Host "1. Checking Core Container & Orchestration Tools:" -ForegroundColor Cyan
Test-Tool -Name "Git Version Control" -Command "git" -VersionCmd "git --version" -InstallTip "winget install --id Git.Git -e --source winget" -Required $true
Test-Tool -Name "Docker Desktop" -Command "docker" -VersionCmd "docker --version" -InstallTip "winget install Docker.DockerDesktop or https://docs.docker.com/desktop/setup/install/windows-install/" -Required $true
Test-Tool -Name "Kubernetes CLI (kubectl)" -Command "kubectl" -VersionCmd "kubectl version --client" -InstallTip "winget install Kubernetes.kubectl" -Required $true
Test-Tool -Name "Helm 3 Package Manager" -Command "helm" -VersionCmd "helm version --short" -InstallTip "winget install Helm.Helm" -Required $true

Write-Host "`n2. Checking GitOps & Security Verification Tools:" -ForegroundColor Cyan
Test-Tool -Name "Argo CD CLI" -Command "argocd" -VersionCmd "argocd version --client --short" -InstallTip "winget install Argo.ArgoCD or choco install argocd-cli" -Required $true
Test-Tool -Name "Cosign (Sigstore)" -Command "cosign" -VersionCmd "cosign version" -InstallTip "winget install Sigstore.Cosign or choco install cosign" -Required $true

Write-Host "`n3. Checking Optional Productivity Utilities:" -ForegroundColor Cyan
Test-Tool -Name "k9s Terminal Monitor" -Command "k9s" -VersionCmd "k9s version -s" -InstallTip "winget install derailed.k9s or choco install k9s" -Required $false

Write-Host "`n------------------------------------------------------"
if ($MissingCount -eq 0) {
    Write-Host "[OK] Workstation is fully prepared for the masterclass!" -ForegroundColor Green
} else {
    Write-Host "[WARN] $MissingCount required tool(s) missing." -ForegroundColor Yellow
    Write-Host "Please install the missing tools using winget / choco / official installers prior to lab exercises." -ForegroundColor Gray
}
