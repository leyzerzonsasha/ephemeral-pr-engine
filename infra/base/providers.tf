terraform {
  required_version = ">= 1.11.0"

  backend "s3" {
    key          = "base/terraform.tfstate"
    region       = "eu-west-1"
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

variable "aws_region" {
  type    = string
  default = "eu-west-1"
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Project   = "ephemeral-pr-engine"
      Layer     = "base"
      ManagedBy = "terraform"
    }
  }
}