# Assignment Mapping

This file maps the PulseCheck implementation directly to the screening assignment.

## Phase 1: Application Development and Containerization

| Requirement | Evidence |
|---|---|
| Lightweight Python application | `app/main.py` implements a FastAPI service. |
| Basic system or external API health check | `/health` checks app uptime, disk space, memory availability, and optional `HEALTHCHECK_URL`. |
| JSON health response | `/health` returns service name, status, timestamp, and structured check details. |
| Containerized app | `Dockerfile` builds a repeatable image on Python 3.12 slim. |
| Runs identically across machines | Runtime dependencies are declared in `requirements.txt`; Docker starts uvicorn on port `8000`. |

## Phase 2: CI/CD Automation

| Requirement | Evidence |
|---|---|
| Pipeline triggers on push | `.github/workflows/ci-cd.yml` runs on push, pull request, and manual dispatch. |
| Run syntax or unit tests | `make ci` runs `compileall`, Ruff, and Pytest. |
| Build container image | Local and GitHub pipelines run `docker build`. |
| Simulate deployment | `scripts/local_pipeline.sh` renders Kubernetes manifests and performs a client-side dry run when available. |
| Real deployment path | The `deploy-aws` job deploys to EKS when `ENABLE_AWS_DEPLOY=true`. |

## Phase 3: Infrastructure as Code

| Requirement | Evidence |
|---|---|
| AWS CloudFormation templates | `cloudformation/01-ecr.yaml`, `02-network.yaml`, `03-github-oidc-deploy-role.yaml`, and `04-eks-cluster-nodegroup.yaml`. |
| Compute resource | `04-eks-cluster-nodegroup.yaml` provisions an EKS cluster and managed node group. |
| Container registry | `01-ecr.yaml` provisions Amazon ECR with scan-on-push and lifecycle cleanup. |
| Networking | `02-network.yaml` provisions a VPC, public/private subnets, routes, and Kubernetes subnet tags. |
| Secure CI/CD auth | `03-github-oidc-deploy-role.yaml` creates a GitHub OIDC role to avoid storing long-lived AWS keys in GitHub. |

## Option A Showcase

| Requirement | Evidence |
|---|---|
| GitHub repository | Repository contains all application, CI/CD, Kubernetes, CloudFormation, and helper scripts. |
| Pipeline builds and deploys | GitHub Actions validate job always runs; deploy job runs on `main` when enabled. |
| CloudFormation provisions AWS compute | EKS infrastructure is deployed through CloudFormation. |
| Live endpoint | `k8s/service.yaml` creates an internet-facing LoadBalancer service. |
| Local pipeline proof | Run `make ci` and capture the output for the README/video. |
| Local container proof | Run `docker run --rm -p 8000:8000 pulsecheck:local` and curl `/health`. |
| Cleanup plan | `scripts/cleanup.sh` deletes the service, namespace, EKS, network, and ECR stacks. |
