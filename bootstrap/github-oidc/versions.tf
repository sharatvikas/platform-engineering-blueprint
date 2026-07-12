terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.40"
    }
  }

  # NOTE: intentionally NO remote backend here.
  #
  # This is a *bootstrap* configuration: it can create the very S3 bucket +
  # DynamoDB lock table that every other root module in this repo uses for
  # remote state. It therefore has to run with local state on first apply
  # (chicken-and-egg). Once the backend exists you MAY migrate this config's
  # own state into it, but it is small and rarely-changing so local state
  # (committed nowhere — see .gitignore) is perfectly acceptable.
}
