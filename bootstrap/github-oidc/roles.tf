# ─────────────────────────────────────────────────────────────────────────────
# Least-privilege IAM roles for GitHub Actions, one per repo/purpose.
#
# Every trust policy:
#   • uses sts:AssumeRoleWithWebIdentity federated to the OIDC provider
#   • pins  aud = sts.amazonaws.com
#   • pins  sub = repo:<github_org>/<repo>:*   (all refs/branches/envs)
#
# SECURITY: `:*` on the sub trusts ANY workflow in the repo (any branch, tag,
# PR, or environment). For production you should tighten each sub to a specific
# ref or environment — see README "Tightening trust". The knobs are the
# local.repo_subs values below.
# ─────────────────────────────────────────────────────────────────────────────

locals {
  # `sub` suffix derived from var.trusted_git_ref:
  #   ""               -> "*"                    (any ref/branch/PR/env — scaffold default)
  #   "refs/heads/main"-> "ref:refs/heads/main"  (only the main branch — recommended)
  #   "environment:x"  -> "environment:x"        (a GitHub Environment)
  _sub_suffix = var.trusted_git_ref == "" ? "*" : (
    startswith(var.trusted_git_ref, "environment:") ? var.trusted_git_ref : "ref:${var.trusted_git_ref}"
  )

  # Repo → the `sub` condition value its role trusts.
  repo_subs = {
    guardian = "repo:${var.github_org}/terraform-ai-guardian:${local._sub_suffix}"
    platform = "repo:${var.github_org}/platform-engineering-blueprint:${local._sub_suffix}"
    finops   = "repo:${var.github_org}/aws-finops-intelligence:${local._sub_suffix}"
  }
}

# ── Reusable trust-policy document generator ─────────────────────────────────
# One data source per repo `sub`; roles reference the matching one.
data "aws_iam_policy_document" "trust" {
  for_each = local.repo_subs

  statement {
    sid     = "GitHubActionsOIDC"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.oidc_provider_arn]
    }

    # Audience must be sts.amazonaws.com (the client_id on the provider).
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Subject scoped to the specific repo. StringLike so the trailing ":*"
    # wildcard matches any workflow context within that repo.
    condition {
      test     = "StringLike"
      variable = "${local.oidc_host}:sub"
      values   = [each.value]
    }
  }
}

# ── Shared policy: Terraform remote-state access (read/write state + lock) ────
# Attached to the plan/drift roles. Scoped to exactly the state bucket and lock
# table resolved in main.tf — nothing else.
data "aws_iam_policy_document" "tf_state_access" {
  statement {
    sid       = "TFStateBucketList"
    effect    = "Allow"
    actions   = ["s3:ListBucket", "s3:GetBucketLocation", "s3:GetBucketVersioning"]
    resources = [local.state_bucket_arn]
  }

  statement {
    sid       = "TFStateObjectRW"
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["${local.state_bucket_arn}/*"]
  }

  statement {
    sid       = "TFStateLock"
    effect    = "Allow"
    actions   = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:DeleteItem"]
    resources = [local.state_lock_arn]
  }
}

# =============================================================================
# terraform-ai-guardian  →  plan / validate / drift role
#
# Feeds THREE secrets, all pointing at THIS one role because they need the
# identical permission set (read-only everywhere + Terraform state R/W):
#   AWS_PLAN_ROLE_ARN, TF_AWS_ROLE_ARN, AWS_DRIFT_ROLE_ARN
#
# Read-only everywhere = AWS-managed ReadOnlyAccess. `terraform plan` never
# mutates infra; it only reads current state of resources, reads remote state,
# and takes the state lock. This role deliberately CANNOT create/modify/delete
# any infrastructure.
# =============================================================================
resource "aws_iam_role" "guardian_plan" {
  name                 = "${var.role_name_prefix}-guardian-plan"
  description          = "GitHub Actions (terraform-ai-guardian): read-only plan/validate/drift + Terraform state access. No infra mutation."
  assume_role_policy   = data.aws_iam_policy_document.trust["guardian"].json
  max_session_duration = 3600
}

resource "aws_iam_role_policy_attachment" "guardian_plan_readonly" {
  role       = aws_iam_role.guardian_plan.name
  policy_arn = "arn:${local.partition}:iam::aws:policy/ReadOnlyAccess"
}

resource "aws_iam_role_policy" "guardian_plan_state" {
  name   = "tf-state-access"
  role   = aws_iam_role.guardian_plan.id
  policy = data.aws_iam_policy_document.tf_state_access.json
}

# =============================================================================
# terraform-ai-guardian  →  org-wide reader role   (AWS_ORG_READER_ROLE_ARN)
#
# For multi-account scanning: describe the org, assume a read-only role in each
# member account, and read Config / Security Hub findings. AssumeRole is scoped
# to a single documented member-role NAME across all accounts (customize via
# var.org_member_role_name) — NOT to "*".
# =============================================================================
data "aws_iam_policy_document" "org_reader" {
  statement {
    sid    = "OrganizationsRead"
    effect = "Allow"
    actions = [
      "organizations:Describe*",
      "organizations:List*",
    ]
    resources = ["*"]
  }

  statement {
    sid       = "AssumeMemberAccountReadRole"
    effect    = "Allow"
    actions   = ["sts:AssumeRole"]
    resources = ["arn:${local.partition}:iam::*:role/${var.org_member_role_name}"]
  }

  statement {
    sid    = "ConfigAndSecurityHubRead"
    effect = "Allow"
    actions = [
      "config:Describe*",
      "config:Get*",
      "config:List*",
      "config:BatchGet*",
      "config:SelectResourceConfig",
      "securityhub:Get*",
      "securityhub:List*",
      "securityhub:Describe*",
      "securityhub:BatchGetSecurityControls",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role" "org_reader" {
  name                 = "${var.role_name_prefix}-guardian-org-reader"
  description          = "GitHub Actions (terraform-ai-guardian): org-wide read for multi-account scanning; AssumeRole into member accounts' read-only role."
  assume_role_policy   = data.aws_iam_policy_document.trust["guardian"].json
  max_session_duration = 3600
}

resource "aws_iam_role_policy" "org_reader" {
  name   = "org-read-and-assume"
  role   = aws_iam_role.org_reader.id
  policy = data.aws_iam_policy_document.org_reader.json
}

# =============================================================================
# platform-engineering-blueprint  →  drift role   (AWS_TERRAFORM_ROLE_ARN)
#
# Read-only everywhere + Terraform state access, for drift detection of the
# platform itself (see .github/workflows/drift-detection.yaml, which reads
# secrets.AWS_TERRAFORM_ROLE_ARN). Deliberately NOT allowed to apply/provision.
# Broadening this to apply is a separate, explicit escalation — see README.
# =============================================================================
resource "aws_iam_role" "platform_drift" {
  name                 = "${var.role_name_prefix}-platform-drift"
  description          = "GitHub Actions (platform-engineering-blueprint): read-only drift detection + Terraform state access. No apply/provision."
  assume_role_policy   = data.aws_iam_policy_document.trust["platform"].json
  max_session_duration = 3600
}

resource "aws_iam_role_policy_attachment" "platform_drift_readonly" {
  role       = aws_iam_role.platform_drift.name
  policy_arn = "arn:${local.partition}:iam::aws:policy/ReadOnlyAccess"
}

resource "aws_iam_role_policy" "platform_drift_state" {
  name   = "tf-state-access"
  role   = aws_iam_role.platform_drift.id
  policy = data.aws_iam_policy_document.tf_state_access.json
}

# =============================================================================
# aws-finops-intelligence  →  cost/usage reader role   (AWS_ROLE_ARN)
#
# Strictly read-only cost + usage telemetry. Note ce:* would include write
# actions (CreateAnomalyMonitor, etc.); we deliberately restrict Cost Explorer
# to Get*/Describe*/List* to honour "no write". pricing:* is read-only by API.
# =============================================================================
data "aws_iam_policy_document" "finops" {
  statement {
    sid    = "CostExplorerRead"
    effect = "Allow"
    actions = [
      "ce:Get*",
      "ce:Describe*",
      "ce:List*",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "CloudWatchMetricsRead"
    effect = "Allow"
    actions = [
      "cloudwatch:GetMetricData",
      "cloudwatch:GetMetricStatistics",
      "cloudwatch:ListMetrics",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "UsageAndInventoryRead"
    effect = "Allow"
    actions = [
      "compute-optimizer:Get*",
      "ec2:Describe*",
      "rds:Describe*",
      "s3:List*",
      "pricing:*",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role" "finops" {
  name                 = "${var.role_name_prefix}-finops-reader"
  description          = "GitHub Actions (aws-finops-intelligence): read-only cost/usage telemetry (Cost Explorer, CloudWatch, Compute Optimizer, Pricing). No write."
  assume_role_policy   = data.aws_iam_policy_document.trust["finops"].json
  max_session_duration = 3600
}

resource "aws_iam_role_policy" "finops" {
  name   = "finops-read"
  role   = aws_iam_role.finops.id
  policy = data.aws_iam_policy_document.finops.json
}
