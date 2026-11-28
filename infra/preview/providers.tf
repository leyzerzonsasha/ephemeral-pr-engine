terraform {
  required_version = ">= 1.11.0"

  backend "s3" {
    encrypt      = true
    use_lockfile = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Project     = "ephemeral-pr-engine"
      Environment = "ephemeral"
      PRNumber    = tostring(var.pr_number)
      TTLHours    = "24"
      ManagedBy   = "terraform"
    }
  }
}