# Platform Engineering Lab

## 🚀 Overview

Local platform engineering environment using:

- Docker — Container runtime  
- k3d Kubernetes — Lightweight Kubernetes (k3s) running in Docker  
- Prometheus — Metrics scraper & monitoring system  
- Grafana — Visualization & dashboarding tool  
- Rancher — Kubernetes cluster management platform  
- Strimzi Kafka — Event streaming platform (Kafka on Kubernetes)  
- Airflow / Argo — Workflow orchestration (batch & pipeline processing)  
- SQL Server — Relational database management system (RDBMS)  
- GitHub — Source code hosting & version control platform  
- GitHub Actions — CI/CD automation & workflow engine  

---

## 📅 Current Workflow (as of 11/04/2026)

---

## 🚀 Execution Steps (In Order)

---

## **Phase 0 — Foundation** ✅ Completed on 04/04/2026

1. Create Git repository structure ✅  
2. Configure local tooling (Docker, kubectl, Helm, k3d) ✅  
3. Create Kubernetes cluster (k3d) ✅  
4. Configure kubeconfig access ✅  
5. Create namespaces (`platform-system`, `kafka`, `data-platform`) ✅  
6. Create `start-platform.sh` ✅  

---

## **Phase 1 — Platform Core** ✅ Completed on 05/04/2026

1. Install NGINX Ingress Controller ✅  
2. Install cert-manager ✅  
3. Install Prometheus ✅  
4. Install Grafana ✅  
5. Install Rancher ✅  

---

## **Phase 2 — Database Versioning & Data Foundations** ✅ Completed on 11/042026

1. Create SQL Server versioning folder structure ✅  
2. Export database schema from local SQL Server ✅  
3. Commit schema + instance configuration ✅  
4. Create DB backup script (`backup-db.sh`) ✅  
5. Configure `.gitignore` for DB backups ✅  
6. Commit initial database version ✅  

---

## **Phase 3 — Data Platform Runtime** ⭐ *(CURRENT PHASE)*

1. Install Strimzi Operator  
2. Deploy Kafka cluster  
3. Deploy Kafka Connect cluster  
4. Deploy Kafka connectors (`applications/`)  
5. Deploy Kafka Streams applications  
6. Deploy batch processing tool (Airflow / Argo)  

---

## **Phase 4 — CI/CD Automation**

1. Create GitHub Actions workflows  
2. Automate Helm deployments  
3. Automate connector deployments  
4. Add validation checks  

---

## **Phase 5 — Observability Maturity**

1. Configure Prometheus scrapers  
2. Import Grafana dashboards  
3. Add Kafka monitoring dashboards  
4. Configure alerts  

---

## **Phase 6 — Platform Self-Service**

1. Standardize deployment templates  
2. Create reusable Helm values  
3. Define onboarding workflow  

---

## **Phase 7 — Production Hardening**

1. Platform backup strategies  
2. Resource limits & autoscaling  
3. Secret management improvements  
4. Security policies (RBAC, network policies)  

---

## 🔮 Future Steps (Post Production Hardening)

1. Deploy AI model on Kubernetes for analysis workloads  
2. Explore cost-effective external hosting beyond laptop  
3. Deploy MySQL instances inside Kubernetes  
4. Build Raspberry Pi home-lab server node  
5. Extend platform into hybrid / edge cluster  

---