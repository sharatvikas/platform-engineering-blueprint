# GitHub Actions → AWS OIDC bootstrap

Keyless, short-lived AWS access for GitHub Actions. This Terraform config creates:

- **One account-global GitHub OIDC identity provider**
  (`token.actions.githubusercontent.com`, audience `sts.amazonaws.com`).
- **Least-privilege IAM roles, one per repo/purpose**, each with a trust policy
  scoped to a specific GitHub repository. Workflows assume these roles via
  `aws-actions/configure-aws-credentials` — **no long-lived access keys**.
- **An optional Terraform remote-state backend** (versioned + encrypted S3
  bucket with a TLS-only policy, plus a DynamoDB lock table).

Account ID is resolved with `data.aws_caller_identity` — nothing is hardcoded.

## What gets created

| Role (name prefix `gha-oidc-`) | Repo | Purpose | Permissions |
|---|---|---|---|
| `gha-oidc-guardian-plan` | `terraform-ai-guardian` | plan / validate / drift | AWS-managed `ReadOnlyAccess` + Terraform state R/W (state bucket + lock table). No infra mutation. |
| `gha-oidc-guardian-org-reader` | `terraform-ai-guardian` | multi-account scanning | `organizations:Describe*/List*`, `sts:AssumeRole` into member-account role, `config:*` read, `securityhub:*` read. |
| `gha-oidc-platform-drift` | `platform-engineering-blueprint` | drift detection | `ReadOnlyAccess` + Terraform state R/W. No apply/provision. |
| `gha-oidc-finops-reader` | `aws-finops-intelligence` | cost/usage read | Cost Explorer (`ce:Get*/Describe*/List*`), CloudWatch metrics read, Compute Optimizer `Get*`, `ec2:Describe*`, `rds:Describe*`, `s3:List*`, `pricing:*`. No write. |

## Secret → role/value mapping

Run `terraform output` after apply; each output's description is the literal
command to run. Summary:

| GitHub secret | Repo | Fed by output / value |
|---|---|---|
| `AWS_PLAN_ROLE_ARN` | `terraform-ai-guardian` | `gha-oidc-guardian-plan` ARN |
| `TF_AWS_ROLE_ARN` | `terraform-ai-guardian` | **same role** as above |
| `AWS_DRIFT_ROLE_ARN` | `terraform-ai-guardian` | **same role** as above |
| `AWS_ORG_READER_ROLE_ARN` | `terraform-ai-guardian` | `gha-oidc-guardian-org-reader` ARN |
| `TF_STATE_BUCKET` | `terraform-ai-guardian` (+ any repo sharing the backend) | state bucket name |
| `AWS_TERRAFORM_ROLE_ARN` | `platform-engineering-blueprint` | `gha-oidc-platform-drift` ARN |
| `AWS_ROLE_ARN` | `aws-finops-intelligence` | `gha-oidc-finops-reader` ARN |

> **Why three secrets point at one guardian role:** `AWS_PLAN_ROLE_ARN`,
> `TF_AWS_ROLE_ARN`, and `AWS_DRIFT_ROLE_ARN` all need the identical permission
> set (read-only everywhere + Terraform state access). Collapsing them into one
> role keeps the trust surface minimal and the mapping auditable. Split them
> later if plan and drift need to diverge.

## Apply

You need AWS credentials for the target account with permission to create IAM
resources (and S3/DynamoDB if creating the backend).

```bash
cd bootstrap/github-oidc
cp terraform.tfvars.example terraform.tfvars   # edit as needed

terraform init
terraform plan
terraform apply
```

> First run uses **local state** (this config can create the very backend other
> roots use — chicken-and-egg). It is small and rarely changes; local state is
> fine, or migrate it into the new backend afterwards.

## Wire up the secrets

After `terraform apply`, push each ARN/name into the right repo's Actions
secrets (requires the `gh` CLI, authenticated):

```bash
ORG=sharatvikas

gh secret set AWS_PLAN_ROLE_ARN       --repo $ORG/terraform-ai-guardian          --body "$(terraform output -raw AWS_PLAN_ROLE_ARN)"
gh secret set TF_AWS_ROLE_ARN         --repo $ORG/terraform-ai-guardian          --body "$(terraform output -raw TF_AWS_ROLE_ARN)"
gh secret set AWS_DRIFT_ROLE_ARN      --repo $ORG/terraform-ai-guardian          --body "$(terraform output -raw AWS_DRIFT_ROLE_ARN)"
gh secret set AWS_ORG_READER_ROLE_ARN --repo $ORG/terraform-ai-guardian          --body "$(terraform output -raw AWS_ORG_READER_ROLE_ARN)"
gh secret set TF_STATE_BUCKET         --repo $ORG/terraform-ai-guardian          --body "$(terraform output -raw TF_STATE_BUCKET)"

gh secret set AWS_TERRAFORM_ROLE_ARN  --repo $ORG/platform-engineering-blueprint --body "$(terraform output -raw AWS_TERRAFORM_ROLE_ARN)"

gh secret set AWS_ROLE_ARN            --repo $ORG/aws-finops-intelligence        --body "$(terraform output -raw AWS_ROLE_ARN)"
```

In a workflow, assume the role like this (note the required `id-token: write`
permission that produces the OIDC token):

```yaml
permissions:
  id-token: write
  contents: read
steps:
  - uses: aws-actions/configure-aws-credentials@v4
    with:
      role-to-assume: ${{ secrets.AWS_PLAN_ROLE_ARN }}
      aws-region: us-east-1
```

## Least-privilege rationale

- **Guardian plan/drift** uses AWS-managed `ReadOnlyAccess` plus a tight inline
  policy granting R/W only to the specific state bucket path and lock table.
  `terraform plan` reads resource state, reads remote state, and takes the lock
  — it never mutates infrastructure, and this role cannot either.
- **Org-reader** grants Organizations read + `sts:AssumeRole` **scoped to a
  single member-role name** (`arn:aws:iam::*:role/<org_member_role_name>`), not
  `*`, plus Config/Security Hub read for posture scanning.
- **Platform-drift** is intentionally read-only. Broadening it to apply /
  provision is a **deliberate, separate escalation** you make yourself (attach a
  scoped write policy or `PowerUserAccess`) — it is not enabled by default.
- **FinOps** is strictly read. `ce:*` would include write actions
  (e.g. `CreateAnomalyMonitor`), so Cost Explorer is limited to
  `Get*/Describe*/List*`; `pricing:*` is read-only by API design.

## Reusing existing infrastructure

- Already have a GitHub OIDC provider? Set `create_oidc_provider = false` and
  pass `existing_oidc_provider_arn`. (AWS permits only one per account.)
- Already have a Terraform backend? Set `create_state_backend = false` and pass
  `existing_state_bucket_name` / `existing_state_lock_table_name`; the roles get
  access to it without creating anything.

## SECURITY — review before production

1. **Trust is repo-wide by default.** Every role trusts
   `sub = repo:<org>/<repo>:*`, i.e. **any** branch, tag, PR, or environment in
   that repo. **Tighten it** before production by editing `local.repo_subs` in
   `roles.tf`, e.g.:
   - a branch: `repo:<org>/<repo>:ref:refs/heads/main`
   - an environment: `repo:<org>/<repo>:environment:prod`
   - a tag: `repo:<org>/<repo>:ref:refs/tags/v*`
2. **`org_member_role_name` defaults to `OrganizationAccountAccessRole`, which
   is admin-level.** Point it at a dedicated **read-only** cross-account role
   before apply so the org-reader can only read member accounts.
3. **Review every policy** against your actual account before applying.
   `ReadOnlyAccess` is broad; trim to specific services if your CI only touches
   a subset.
4. Keep `max_session_duration` (1h) as short as your longest job needs.
