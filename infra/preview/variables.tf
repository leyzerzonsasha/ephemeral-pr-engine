variable "aws_region" {
  type    = string
  default = "eu-west-1"
}

variable "tfstate_bucket" {
  type        = string
  description = "S3 bucket containing base/terraform.tfstate"
}

variable "pr_number" {
  type        = number
  description = "GitHub Pull Request number"

  validation {
    condition     = var.pr_number > 0 && var.pr_number < 49000
    error_message = "pr_number must be between 1 and 48999 to fit ALB listener rule priority limits."
  }
}

variable "image_uri" {
  type        = string
  description = "Full immutable ECR image URI for this PR commit"
}

variable "git_sha" {
  type        = string
  description = "Short Git commit SHA deployed to this preview"
}