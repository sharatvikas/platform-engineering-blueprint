variable "aws_region" {
  description = "AWS region for regional resources (DynamoDB lock table). IAM + the OIDC provider are global. Must match the region your Terraform backend uses."
  type        = string
  default     = "us-east-1"
}

variable "github_org" {
  description = "GitHub org/user that owns the repositories. Used to build the trust-policy `sub` claim: repo:<github_org>/<repo>:*"
  type        = string
  default     = "sharatvikas"
}

variable "tags" {
  description = "Extra tags merged into the provider default_tags for every resource."
  type        = map(string)
  default     = {}
}

# ── OIDC provider ────────────────────────────────────────────────────────────

variable "create_oidc_provider" {
  description = "Create the account-global GitHub OIDC identity provider. Set to false if your account already has one (only one per account is allowed) and pass its ARN via existing_oidc_provider_arn."
  type        = bool
  default     = true
}

variable "existing_oidc_provider_arn" {
  description = "ARN of a pre-existing GitHub OIDC provider to reuse when create_oidc_provider = false. Ignored when create_oidc_provider = true."
  type        = string
  default     = ""
}

variable "oidc_thumbprint_list" {
  description = <<-EOT
    Root-CA thumbprints for the GitHub OIDC issuer. Since 2023 AWS STS validates
    GitHub's OIDC token against Amazon's own trusted CA store, so these are no
    longer used for verification — but the aws_iam_openid_connect_provider
    resource still accepts them and they aid compatibility with older tooling.
    Defaults are GitHub's two published intermediate-CA thumbprints. If GitHub
    rotates its certificate you do NOT need to update these.
  EOT
  type        = list(string)
  default = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fca",
  ]
}

# ── Remote-state backend ───────────────────────────────────────────────────────

variable "create_state_backend" {
  description = "Create an S3 state bucket + DynamoDB lock table. Set to false if you already have a Terraform backend and pass its names via existing_state_bucket_name / existing_state_lock_table_name."
  type        = bool
  default     = true
}

variable "state_bucket_name" {
  description = "Explicit name for the created state bucket. Leave empty to auto-generate a globally-unique name: <github_org>-tfstate-<account_id>. Only used when create_state_backend = true."
  type        = string
  default     = ""
}

variable "state_lock_table_name" {
  description = "Name for the created DynamoDB lock table. Only used when create_state_backend = true."
  type        = string
  default     = "terraform-state-lock"
}

variable "existing_state_bucket_name" {
  description = "Name of a pre-existing state bucket to grant the CI roles access to, when create_state_backend = false."
  type        = string
  default     = ""
}

variable "existing_state_lock_table_name" {
  description = "Name of a pre-existing DynamoDB lock table to grant the CI roles access to, when create_state_backend = false."
  type        = string
  default     = "terraform-state-lock"
}

# ── Org-reader role ────────────────────────────────────────────────────────────

variable "org_member_role_name" {
  description = <<-EOT
    Name of the IAM role that exists in EACH member account of the AWS
    Organization and that the org-reader role is allowed to sts:AssumeRole into
    for multi-account scanning. The AssumeRole resource is scoped to
    arn:aws:iam::*:role/<this-name> across the org. CUSTOMIZE THIS to your own
    cross-account read-only role name before apply. Common default for
    Organizations is "OrganizationAccountAccessRole", but that role is
    admin-level — you should point this at a dedicated read-only role instead.
  EOT
  type        = string
  default     = "OrganizationAccountAccessRole"
}

variable "role_name_prefix" {
  description = "Prefix applied to every created IAM role name, for easy identification/deletion."
  type        = string
  default     = "gha-oidc"
}

variable "trusted_git_ref" {
  description = <<-EOT
    Git ref a GitHub Actions workflow must be running from to assume these roles,
    e.g. "refs/heads/main". Empty string ("") trusts ANY ref/branch/tag/PR/env in
    the repo (the sub wildcard ":*"). Set to "refs/heads/main" so ONLY workflows on
    the default branch (schedule runs + workflow_dispatch triggered on main) can
    assume the roles — no feature branches, PRs, or forks. Recommended for
    security. To gate on a GitHub Environment instead, use "environment:<name>"
    by editing local._sub_suffix in roles.tf.
  EOT
  type        = string
  default     = ""
}
