# Module 00: Registration, Orientation & Workshop Environment Setup

**Session Reference:** 08:30 – 09:00 ICT  
**Topic:** ลงทะเบียน กล่าวเปิดการอบรม และแนะนำภาพรวมหลักสูตร (Registration, Opening Remarks & Course Overview)  
**Host & Organization:** Thai Programmer Association (สมาคมโปรแกรมเมอร์ไทย)  
**Venue:** ClassRoom 3, True Digital Park, Bangkok, Thailand  
**Lead Instructors:** คุณสฤษรัตน์ จิรทุลพรชัย (CTO, Jumpbox), คุณกฤษฎา วิเวก (กรรมการ สมาคมฯ), คุณชาลี คัมภีรภาพ (Solution Architect, VMware by Broadcom)

---

## 1. Executive Welcome & Purpose of the Workshop

Welcome to the **Code to PROEN Cloud, GitOps & Argo CD Workshop**. This intensive, day-long hands-on masterclass is designed to equip enterprise software developers, systems architects, and DevOps practitioners with the architectural paradigms and operational muscle memory required to build, secure, and operate modern cloud-native systems.

Throughout today's curriculum, you will transition from fundamental source code principles (12-Factor App) to advanced distributed systems design, supply chain cryptography, enterprise platform abstractions, and production GitOps automation on PROEN Cloud infrastructure.

---

## 2. On-Site Logistics & ClassRoom 3 Parameters

- **Location:** ClassRoom 3, True Digital Park (111 Sukhumvit Rd, Khwaeng Bang Chak, Phra Khanong, Bangkok).
- **Public Transit:** Direct skywalk connection from **BTS Punnawithi (Exit 6)** into True Digital Park.
- **Parking Information:** Parking available in the building basement (First 3 hours complimentary).
- **Wi-Fi Connectivity:**
  - **SSID:** `TDPK_Event_5G` / `PROEN_Workshop_HighSpeed`
  - **Captive Portal:** Check badge credential card provided at registration desk.
  - **Bandwidth:** Dedicated 1 Gbps symmetric fiber connection.

---

## 3. Workstation Readiness & Multi-OS Pre-Flight Verification

Participants may use a personal laptop running **Windows (PowerShell 5.1 / 7+ or WSL2)**, **macOS**, or **Linux**. All workshop scripts, sample apps, and GitOps tools provide native multi-OS compatibility.

### macOS & Linux (Terminal):
Run the pre-flight verification script in bash/zsh:
```bash
cd workshop-setup/01-prerequisites
chmod +x check-env.sh
./check-env.sh
```

### Windows (PowerShell):
Open Windows Terminal or PowerShell and run:
```powershell
cd workshop-setup\01-prerequisites
.\check-env.ps1
```
*(Tip: To quickly install missing tools on Windows via Winget: `winget install Git.Git Docker.DockerDesktop Kubernetes.kubectl Helm.Helm`)*

### Windows (WSL2 / Ubuntu):
If you prefer running inside WSL2, all Linux `.sh` scripts run natively without modification.

---

## 4. Code of Conduct & Interactive Q&A Protocol

- **Hands-on Support:** Teaching assistants (TAs) are stationed across ClassRoom 3. If your lab environment encounters an error, raise your technical flag or notify a staff member.
- **Collaborative Spirit:** High-scale distributed engineering thrives on shared learning. Discuss architecture patterns freely with your table peers.
- **Digital Materials Access:** All slide decks, code repositories, manifests, and architecture diagrams are continuously synced to:
  `https://github.com/3lVv0w/code-to-cloud-workshop.git`
