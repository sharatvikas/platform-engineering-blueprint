# ─────────────────────────────────────────────────────────────────────────────
# GitHub Actions → AWS OIDC bootstrap
#
# Creates (all in the caller's own AWS account, no hardcoded account IDs):
#   • one account-global GitHub OIDC identity provider          (oidc.tf)
#   • least-privilege IAM roles, one per repo/purpose           (roles.tf)
#   • an optional Terraform remote-state backend (S3 + DynamoDB) (state-backend.tf)
#
# Everything is driven by variables + data sources so it is safe to apply into
# any account. See README.md for the apply + `gh secret set` workflow.
# ─────────────────────────────────────────────────────────────────────────────

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = merge(
      {
        ManagedBy = "terraform"
        Component = "github-oidc-bootstrap"
        Repo      = "platform-engineering-blueprint"
      },
      var.tags,
    )
  }
}

# Resolve the account ID at plan/apply time — never hardcoded.
data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  partition  = data.aws_partition.current.partition

  # ARN of the OIDC provider that role trust policies federate against —
  # either the one we create here, or a pre-existing one the user passes in.
  oidc_provider_arn = var.create_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : var.existing_oidc_provider_arn

  # Fully-qualified name of the OIDC issuer, used to build the sub/aud
  # condition keys (e.g. "token.actions.githubusercontent.com:sub").
  oidc_host = "token.actions.githubusercontent.com"

  # Resolved remote-state backend identifiers, whether we create them or the
  # user is pointing us at an existing backend.
  state_bucket_name = var.create_state_backend ? coalesce(var.state_bucket_name, "${var.github_org}-tfstate-${local.account_id}") : var.existing_state_bucket_name
  state_lock_table  = var.create_state_backend ? aws_dynamodb_table.tf_lock[0].name : var.existing_state_lock_table_name

  state_bucket_arn = "arn:${local.partition}:s3:::${local.state_bucket_name}"
  state_lock_arn   = "arn:${local.partition}:dynamodb:${var.aws_region}:${local.account_id}:table/${local.state_lock_table}"
}
