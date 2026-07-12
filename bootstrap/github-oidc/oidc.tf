# ─────────────────────────────────────────────────────────────────────────────
# GitHub Actions OIDC identity provider (account-global — exactly one allowed).
#
# Modern best practice (AWS provider >= 5.x):
#   • url          = https://token.actions.githubusercontent.com
#   • client_id    = sts.amazonaws.com   (the `aud` every role trust checks)
#   • thumbprint   = supplied for backward-compat only. Since mid-2023 AWS STS
#                    verifies GitHub's OIDC JWT against Amazon's trusted CA store
#                    and ignores the thumbprint for the well-known GitHub issuer,
#                    so certificate rotation on GitHub's side does NOT break you.
#
# Guarded by create_oidc_provider so accounts that already have a GitHub OIDC
# provider (only one per account is permitted) can set it false and pass the
# existing ARN via var.existing_oidc_provider_arn.
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_iam_openid_connect_provider" "github" {
  count = var.create_oidc_provider ? 1 : 0

  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = var.oidc_thumbprint_list

  tags = {
    Name = "github-actions-oidc"
  }
}
