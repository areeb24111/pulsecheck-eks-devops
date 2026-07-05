# Demo Guide

Use this checklist to record the 3-minute showcase or capture README screenshots.

Save final screenshots in `docs/screenshots/` using these names:

| Evidence | File |
|---|---|
| GitHub Actions success | `github-actions-success.png` |
| Local pipeline success | `local-pipeline-pass.png` |
| Docker health response | `docker-health-response.png` |
| CloudFormation stacks | `eks-cloudformation-stacks.png` |
| EKS pods and service | `eks-kubectl-service.png` |
| Live health endpoint | `live-health-endpoint.png` |

## 1. Local Pipeline

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip
python -m pip install -r requirements-dev.txt
make ci
```

Capture the final `Local pipeline passed` line.

## 2. Local Container

```bash
docker build -t pulsecheck:local .
docker run --rm -p 8000:8000 pulsecheck:local
curl http://127.0.0.1:8000/health
```

Capture the JSON response showing `"status": "healthy"`.

## 3. AWS Infrastructure

```bash
export AWS_REGION=ap-south-1
./scripts/deploy_infra.sh
```

Capture the CloudFormation stacks in `CREATE_COMPLETE` or `UPDATE_COMPLETE`.

## 4. EKS Application Deployment

```bash
./scripts/deploy_app.sh
kubectl get pods -n pulsecheck
kubectl get svc -n pulsecheck
```

Capture two running pods and the LoadBalancer hostname.

## 5. Live Endpoint

```bash
curl http://a12e2ccfc5cc247989e1772f1335f334-1852857093.ap-south-1.elb.amazonaws.com/health
```

Capture the live JSON response.

## 6. GitHub Actions

Push to `main` with `ENABLE_AWS_DEPLOY=true` and `AWS_ROLE_TO_ASSUME` configured. Capture:

- `validate` job passing.
- `deploy-aws` job passing.
- Job summary showing the live URL.

## 7. Cleanup

```bash
./scripts/cleanup.sh
```

Capture stack deletion or mention that cleanup is scheduled after reviewer validation.
