# ─────────────────────────────────────────────────────────────────────────────
# Terraform remote-state backend: S3 bucket + DynamoDB lock table.
#
# Gated behind create_state_backend. When false, nothing here is created and
# the CI roles are granted access to your existing backend
# (var.existing_state_bucket_name / var.existing_state_lock_table_name).
#
# Hardened per AWS best practice: versioning, SSE, all public access blocked,
# and a bucket policy that denies any non-TLS request.
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_s3_bucket" "tf_state" {
  count = var.create_state_backend ? 1 : 0

  bucket = local.state_bucket_name

  tags = {
    Name = local.state_bucket_name
  }
}

resource "aws_s3_bucket_versioning" "tf_state" {
  count = var.create_state_backend ? 1 : 0

  bucket = aws_s3_bucket.tf_state[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tf_state" {
  count = var.create_state_backend ? 1 : 0

  bucket = aws_s3_bucket.tf_state[0].id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "tf_state" {
  count = var.create_state_backend ? 1 : 0

  bucket                  = aws_s3_bucket.tf_state[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Deny any request that is not made over TLS.
data "aws_iam_policy_document" "tf_state_bucket" {
  count = var.create_state_backend ? 1 : 0

  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [local.state_bucket_arn, "${local.state_bucket_arn}/*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "tf_state" {
  count = var.create_state_backend ? 1 : 0

  bucket = aws_s3_bucket.tf_state[0].id
  policy = data.aws_iam_policy_document.tf_state_bucket[0].json

  # Ensure public-access-block is in place before we attach a policy.
  depends_on = [aws_s3_bucket_public_access_block.tf_state]
}

resource "aws_dynamodb_table" "tf_lock" {
  count = var.create_state_backend ? 1 : 0

  name         = var.state_lock_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name = var.state_lock_table_name
  }
}
