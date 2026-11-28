terraform {
  required_version = ">= 1.11.0"
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

variable "github_owner" { type = string }
variable "github_owner_id" { type = string }
variable "github_repo" { type = string }
variable "github_repo_id" { type = string }

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Project   = "ephemeral-pr-engine"
      ManagedBy = "terraform-bootstrap"
    }
  }
}

data "aws_caller_identity" "current" {}

# --- 1. Terraform Remote State Bucket (Native S3 Locking via .tflock) ---
resource "aws_s3_bucket" "tfstate" {
  bucket        = "tfstate-pr-engine-${data.aws_caller_identity.current.account_id}"
  force_destroy = true # Easy cleanup for portfolio project
}

resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket                  = aws_s3_bucket.tfstate.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# --- 2. GitHub OIDC Provider & Scoped IAM Role ---
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

locals {
  oidc_repo_id = "repo:${var.github_owner}@${var.github_owner_id}/${var.github_repo}@${var.github_repo_id}"
}

data "aws_iam_policy_document" "github_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "${local.oidc_repo_id}:pull_request",
        "${local.oidc_repo_id}:ref:refs/heads/main"
      ]
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name               = "gha-ephemeral-pr-engine-role"
  assume_role_policy = data.aws_iam_policy_document.github_trust.json
}

data "aws_iam_policy_document" "github_permissions" {
  statement {
    sid    = "TerraformStateAndLockfile"
    effect = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject"
    ]
    resources = [
      aws_s3_bucket.tfstate.arn,
      "${aws_s3_bucket.tfstate.arn}/*"
    ]
  }

  statement {
    sid    = "EphemeralPreviewInfra"
    effect = "Allow"
    actions = [
      "ecs:*",
      "ecr:*",
      "elasticloadbalancing:*",
      "ec2:Describe*",
      "ec2:*SecurityGroup*",
      "logs:*",
      "tag:GetResources",
      "iam:GetRole",
      "iam:PassRole"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "github_actions" {
  name   = "ephemeral-pr-engine-policy"
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.github_permissions.json
}

output "tfstate_bucket" {
  value = aws_s3_bucket.tfstate.bucket
}

output "github_actions_role_arn" {
  value = aws_iam_role.github_actions.arn
}