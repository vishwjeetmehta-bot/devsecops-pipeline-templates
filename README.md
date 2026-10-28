# 🛡️ DevSecOps Pipeline Templates

> **Production-ready GitHub Actions & Azure DevOps YAML templates** embedding Checkov, Trivy, GitLeaks, SonarQube, and Infracost into every stage of your CI/CD release train.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](LICENSE)
[![GitHub Actions](https://img.shields.io/badge/GitHub_Actions-2088FF?style=for-the-badge&logo=github-actions&logoColor=white)](https://github.com/features/actions)
[![Azure DevOps](https://img.shields.io/badge/Azure_DevOps-0078D7?style=for-the-badge&logo=azure-devops&logoColor=white)](https://dev.azure.com)
[![Terraform](https://img.shields.io/badge/Terraform-844FBA?style=for-the-badge&logo=terraform&logoColor=white)](https://terraform.io)
[![Checkov](https://img.shields.io/badge/Checkov-Policy_as_Code-2C3E50?style=for-the-badge&logo=bridgecrew&logoColor=white)](https://checkov.io)
[![Trivy](https://img.shields.io/badge/Trivy-Vulnerability_Scan-1904DA?style=for-the-badge&logo=aqua&logoColor=white)](https://trivy.dev)

---

## 📖 Overview

This repository provides **enterprise-grade, reusable CI/CD pipeline templates** that implement a full **Shift-Left DevSecOps** strategy. Every template is designed to be dropped into your project immediately — no custom configuration required for standard setups.

### 🎯 What's Included

| Template | Platform | Purpose |
|----------|----------|---------|
| `terraform-full-devsecops.yml` | GitHub Actions | End-to-end IaC pipeline with security gates |
| `container-devsecops.yml` | GitHub Actions | Docker build, Trivy scan, ACR push |
| `app-devsecops.yml` | GitHub Actions | Application SAST, SCA, and deployment |
| `azure-terraform-pipeline.yml` | Azure DevOps | Multi-stage Terraform pipeline |
| `azure-container-pipeline.yml` | Azure DevOps | Container build and scan pipeline |
| `pre-commit-config.yaml` | Pre-commit | Local developer security hooks |

---

## 🔒 Security Gates Implemented

```
[ Commit / PR ]
      │
      ▼
┌─────────────────────────────────────────────────────────┐
│  GATE 1: Secret Detection (GitLeaks)                    │
│  → Block if hardcoded API keys, tokens, passwords found │
└──────────────────────────┬──────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────┐
│  GATE 2: IaC Security Scan (Checkov + tfsec)            │
│  → Block if HIGH/CRITICAL CIS violations found          │
└──────────────────────────┬──────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────┐
│  GATE 3: FinOps Cost Estimation (Infracost)             │
│  → Warn if monthly cost delta exceeds $500              │
└──────────────────────────┬──────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────┐
│  GATE 4: Code Quality SAST (SonarQube)                  │
│  → Block if Quality Gate fails (new vulnerabilities)    │
└──────────────────────────┬──────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────┐
│  GATE 5: Container Vulnerability Scan (Trivy)           │
│  → Block if fixable CRITICAL CVEs in image              │
└──────────────────────────┬──────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────┐
│  GATE 6: Policy Guardrail Deployment (Azure Policy)     │
│  → Deny resources violating MCSB/CIS policies           │
└─────────────────────────────────────────────────────────┘
```

---

## 🚀 Quick Start

### GitHub Actions — Terraform IaC Pipeline

1. Copy `.github/workflows/terraform-full-devsecops.yml` into your repository
2. Set the required secrets in your GitHub repository settings:

```bash
# Required GitHub Secrets
ARM_CLIENT_ID          # Azure Service Principal Client ID
ARM_CLIENT_SECRET      # Azure Service Principal Secret
ARM_SUBSCRIPTION_ID    # Target Azure Subscription ID
ARM_TENANT_ID          # Azure AD Tenant ID
SONAR_TOKEN            # SonarQube authentication token
SONAR_HOST_URL         # SonarQube server URL
INFRACOST_API_KEY      # Infracost API key (free tier available)
```

3. Push to a feature branch — all security gates will run automatically on PR creation.

### Azure DevOps Pipeline

1. Copy `azure-devops/azure-terraform-pipeline.yml` to your repo root
2. Create a Variable Group named `devsecops-secrets` in your Azure DevOps project
3. Add the equivalent variables as secret values
4. Import the pipeline via **Pipelines → New Pipeline → Azure Repos Git**

---

## 📁 Repository Structure

```
devsecops-pipeline-templates/
├── .github/
│   └── workflows/
│       ├── terraform-full-devsecops.yml    # Full IaC DevSecOps pipeline
│       ├── container-devsecops.yml         # Container build & scan pipeline
│       └── app-devsecops.yml               # Application SAST/SCA pipeline
├── azure-devops/
│   ├── azure-terraform-pipeline.yml        # Azure DevOps Terraform pipeline
│   ├── azure-container-pipeline.yml        # Azure DevOps container pipeline
│   └── templates/                          # Reusable stage templates
│       ├── security-scan-stage.yml
│       ├── terraform-plan-stage.yml
│       └── terraform-apply-stage.yml
├── pre-commit/
│   └── .pre-commit-config.yaml             # Local developer security hooks
├── scripts/
│   ├── trivy-scan.sh                       # Standalone Trivy scan script
│   ├── checkov-scan.sh                     # Standalone Checkov scan script
│   └── infracost-report.sh                 # Infracost delta report script
├── docs/
│   ├── SECURITY_GATES.md                   # Detailed gate configuration guide
│   ├── SECRETS_SETUP.md                    # Secrets & credentials setup guide
│   └── COMPLIANCE_MAPPING.md               # CIS/MCSB control mapping
└── README.md
```

---

## 🔧 Tool Configuration

### Checkov — IaC Policy Scanning
- **Frameworks:** Terraform, Bicep, ARM Templates, Kubernetes, Dockerfile
- **Benchmark:** CIS Azure Foundations v2.0
- **Soft-fail:** Disabled in `main` pipeline; enabled in feature branch PRs for review
- **Output:** SARIF format uploaded to GitHub Security tab

### Trivy — Container & Filesystem Scanning
- **Targets:** Docker images, filesystem directories, Git repositories
- **Severity Filter:** CRITICAL and HIGH only in blocking gates
- **Ignore File:** `.trivyignore` for documented false-positives
- **Output:** SARIF uploaded to GitHub Security tab + JUnit XML for PR annotations

### GitLeaks — Secret Detection
- **Pre-commit:** Blocks commits with detected secrets locally
- **CI Gate:** Scans full Git history on PRs to detect historic secret exposure
- **Allowlist:** `.gitleaks.toml` for known false-positives (e.g., example values in docs)

### Infracost — FinOps Cost Estimation
- **Trigger:** Every Terraform plan in PRs
- **Threshold Alert:** Comments on PR if monthly delta exceeds configurable threshold
- **Currency:** USD by default; configurable via `INFRACOST_CURRENCY` env var

---

## 📋 Compliance Coverage

| Framework | Coverage |
|-----------|---------|
| CIS Azure Foundations Benchmark v2.0 | Checkov IaC gates |
| OWASP Top 10 | SonarQube SAST rules |
| NIST SP 800-190 (Container Security) | Trivy image scanning |
| Microsoft Cloud Security Benchmark (MCSB) | Azure Policy enforcement |
| PCI-DSS Secret Controls | GitLeaks detection |

---

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/add-new-template`)
3. Commit with conventional commits (`feat: add ECS container template`)
4. Open a PR — all security gates must pass

---

## 📄 License

MIT License — see [LICENSE](LICENSE) for details.

---

<div align="center">
  <sub>Built with ❤️ by <b>Vishwjeet Kumar Mehta</b> • Senior DevOps & DevSecOps Consultant • <a href="https://linkedin.com/in/vishwjeetmehta">LinkedIn</a></sub>
</div>
