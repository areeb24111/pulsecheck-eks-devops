# Screenshot Checklist

Add the final submission screenshots in this directory.

Expected files:

| File | What it should show |
|---|---|
| `github-actions-success.png` | GitHub Actions run with validate and deploy jobs passing. |
| `local-pipeline-pass.png` | `make ci` ending with `Local pipeline passed`. |
| `docker-health-response.png` | Local Docker container responding at `/health`. |
| `eks-cloudformation-stacks.png` | PulseCheck CloudFormation stacks in complete state. |
| `eks-kubectl-service.png` | `kubectl get pods` and `kubectl get svc` for namespace `pulsecheck`. |
| `live-health-endpoint.png` | Browser or terminal response from the live `/health` endpoint. |

The project `.gitignore` allows these screenshots to be committed.
