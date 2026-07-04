#!/usr/bin/env bash
set -Eeuo pipefail

AWS_REGION="${AWS_REGION:-ap-south-1}"
PROJECT_NAME="${PROJECT_NAME:-pulsecheck}"
GITHUB_ORG="${GITHUB_ORG:-}"
GITHUB_REPO="${GITHUB_REPO:-}"
GITHUB_BRANCH="${GITHUB_BRANCH:-main}"
OIDC_STACK_NAME="${OIDC_STACK_NAME:-${PROJECT_NAME}-github-oidc}"
CREATE_GITHUB_OIDC_PROVIDER="${CREATE_GITHUB_OIDC_PROVIDER:-true}"
EXISTING_GITHUB_OIDC_PROVIDER_ARN="${EXISTING_GITHUB_OIDC_PROVIDER_ARN:-}"

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 1
  }
}

require_cmd aws

if [ -z "${GITHUB_ORG}" ] || [ -z "${GITHUB_REPO}" ]; then
  echo "Set GITHUB_ORG and GITHUB_REPO before running this script." >&2
  exit 1
fi

if [ "${CREATE_GITHUB_OIDC_PROVIDER}" = "false" ] && [ -z "${EXISTING_GITHUB_OIDC_PROVIDER_ARN}" ]; then
  echo "Set EXISTING_GITHUB_OIDC_PROVIDER_ARN when CREATE_GITHUB_OIDC_PROVIDER=false." >&2
  exit 1
fi

aws cloudformation deploy \
  --region "${AWS_REGION}" \
  --stack-name "${OIDC_STACK_NAME}" \
  --template-file cloudformation/03-github-oidc-deploy-role.yaml \
  --capabilities CAPABILITY_IAM \
  --no-fail-on-empty-changeset \
  --parameter-overrides \
    ProjectName="${PROJECT_NAME}" \
    GitHubOrg="${GITHUB_ORG}" \
    GitHubRepo="${GITHUB_REPO}" \
    GitHubBranch="${GITHUB_BRANCH}" \
    CreateGitHubOIDCProvider="${CREATE_GITHUB_OIDC_PROVIDER}" \
    ExistingGitHubOIDCProviderArn="${EXISTING_GITHUB_OIDC_PROVIDER_ARN}"

aws cloudformation describe-stacks \
  --region "${AWS_REGION}" \
  --stack-name "${OIDC_STACK_NAME}" \
  --query "Stacks[0].Outputs" \
  --output table
