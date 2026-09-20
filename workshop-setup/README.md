# Code to PROEN Cloud, GitOps & Argo CD Workshop: Hands-on Lab Setup

Welcome to the hands-on lab environment for **Event #30: Code to PROEN Cloud, GitOps & Argo CD Workshop**.

This directory contains production-ready, runnable code, container specifications, Kubernetes manifests, and automation scripts corresponding to every module taught in the masterclass.

**Full Cross-Platform Support:** All commands, automation scripts, and lab exercises have been verified to run seamlessly on **Windows (PowerShell 5.1 / 7+ & WSL2)**, **macOS (zsh/bash)**, and **Linux (bash)**.

---

## Directory Organization

```
workshop-setup/
├── README.md                           # Master Lab Guide & Multi-OS Instructions
├── 01-prerequisites/
│   ├── check-env.sh                    # Automated audit for macOS / Linux (bash)
│   └── check-env.ps1                   # Automated audit for Windows (PowerShell)
├── 02-sample-app/                      # 12-Factor Microservice (Node.js & TypeScript)
│   ├── Dockerfile                      # Hardened Multi-Stage Distroless container
│   ├── docker-compose.yaml             # Local stack (App + PostgreSQL + Redis)
│   ├── package.json
│   ├── tsconfig.json
│   └── src/
│       └── index.ts                    # Triple health probes, graceful shutdown & row locks
├── 03-supply-chain/
│   ├── secure-build-and-sign.sh        # Supply chain build & sign for macOS / Linux
│   └── secure-build-and-sign.ps1       # Supply chain build & sign for Windows (PowerShell)
├── 04-gitops-manifests/                # Declarative Kubernetes & Kustomize specifications
│   ├── base/                           # Deployment, Service, ConfigMap
│   ├── overlays/
│   │   ├── staging/                    # Replicas=1, lower resource requests
│   │   └── production/                 # Replicas=3, HA resource limits
│   └── sync-waves/                     # Ordered rollout: DB Migration (Wave 0) -> App (Wave 1)
├── 05-argocd/                          # GitOps Controller Configuration
│   ├── install-argocd.sh               # Argo CD bootstrap for macOS / Linux
│   ├── install-argocd.ps1              # Argo CD bootstrap for Windows (PowerShell)
│   ├── application.yaml                # Declarative Application CRD with self-healing
│   └── applicationset.yaml             # Multi-environment generator
└── 06-chaos-and-verification/
    ├── simulate-drift.sh               # Drift injection & self-healing test (macOS / Linux)
    ├── simulate-drift.ps1              # Drift injection & self-healing test (Windows PowerShell)
    ├── test-concurrency-locks.sh       # Concurrency stress test (macOS / Linux curl fork)
    └── test-concurrency-locks.ps1      # Concurrency stress test (Windows PowerShell async threads)
```

---

## Quickstart: Running the Complete Lab (Cross-Platform)

### Step 1: Pre-Flight Environment Verification

Audit your workstation for Git, Docker, kubectl, Helm, and signing tools.

#### macOS & Linux:
```bash
cd 01-prerequisites
chmod +x check-env.sh
./check-env.sh
```

#### Windows (PowerShell):
```powershell
cd 01-prerequisites
.\check-env.ps1
```
*(Windows Package Manager tip: `winget install Git.Git Docker.DockerDesktop Kubernetes.kubectl Helm.Helm`)*

---

### Step 2: Run the 12-Factor Sample App Locally

Start the local stack (Express API + PostgreSQL 16 + Redis 7) using Docker Compose.

#### macOS & Linux:
```bash
cd ../02-sample-app
docker compose up -d --build

# Verify healthy probes
curl -i http://localhost:3000/healthz/startup
curl -i http://localhost:3000/healthz/readiness
curl -i http://localhost:3000/healthz

# Test single ticket reservation
curl -X POST http://localhost:3000/orders \
  -H "Content-Type: application/json" \
  -d '{"tierId": 1, "userId": "usr_dev_1"}'

# Execute high-concurrency reservation stress test (30 parallel requests)
cd ../06-chaos-and-verification
chmod +x test-concurrency-locks.sh
./test-concurrency-locks.sh
```

#### Windows (PowerShell):
```powershell
cd ..\02-sample-app
docker compose up -d --build

# Verify healthy probes
Invoke-RestMethod -Uri http://localhost:3000/healthz/startup
Invoke-RestMethod -Uri http://localhost:3000/healthz/readiness
Invoke-RestMethod -Uri http://localhost:3000/healthz

# Test single ticket reservation
Invoke-RestMethod -Uri http://localhost:3000/orders -Method Post `
  -ContentType "application/json" `
  -Body '{"tierId": 1, "userId": "usr_dev_win_1"}'

# Execute high-concurrency reservation stress test (30 parallel requests)
cd ..\06-chaos-and-verification
.\test-concurrency-locks.ps1
```

---

### Step 3: Run Supply Chain Security & SBOM Generation

Build the multi-stage Distroless image, produce a CycloneDX SBOM, scan for CVEs, and simulate Cosign signing.

#### macOS & Linux:
```bash
cd ../03-supply-chain
chmod +x secure-build-and-sign.sh
./secure-build-and-sign.sh
```

#### Windows (PowerShell):
```powershell
cd ..\03-supply-chain
.\secure-build-and-sign.ps1
```

---

### Step 4: Validate Kubernetes Manifests & Bootstrap Argo CD

Dry-run Kustomize base and environment overlays, then bootstrap Argo CD.

#### All Platforms (kubectl / Kustomize):
```bash
# Validate base specifications
kubectl kustomize ../04-gitops-manifests/base

# Validate environment overlays (Staging & Production)
kubectl kustomize ../04-gitops-manifests/overlays/staging
kubectl kustomize ../04-gitops-manifests/overlays/production
```

#### Bootstrap Argo CD on Cluster:
**macOS / Linux:**
```bash
cd ../05-argocd
chmod +x install-argocd.sh
./install-argocd.sh
```

**Windows (PowerShell):**
```powershell
cd ..\05-argocd
.\install-argocd.ps1
```

**Apply GitOps Application (All Platforms):**
```bash
kubectl apply -f application.yaml
```

---

### Step 5: Test Automated Self-Healing & Drift Detection

Inject configuration drift (`kubectl scale deployment --replicas=1`) and observe Argo CD automatically reconciling back to desired state (`replicas=3`).

#### macOS & Linux:
```bash
cd ../06-chaos-and-verification
chmod +x simulate-drift.sh
./simulate-drift.sh
```

#### Windows (PowerShell):
```powershell
cd ..\06-chaos-and-verification
.\simulate-drift.ps1
```

---

## Operating System Notes

- **Windows WSL2 Users:** If you prefer running in Ubuntu on WSL2, all macOS/Linux bash scripts (`.sh`) run natively inside WSL2 without any modifications. Ensure Docker Desktop has "Use the WSL 2 based engine" enabled.
- **PowerShell Execution Policy:** If PowerShell blocks script execution on Windows, run once:
  ```powershell
  Set-ExecutionPolicy -Scope Process -ExecutionPolicy RemoteSigned
  ```
- **Postgres Local Port Isolation:** The local compose file binds PostgreSQL to host port `5433` (internal `5432`) and Redis to `6380` (internal `6379`) to avoid conflicts with any pre-existing databases on port 5432.
