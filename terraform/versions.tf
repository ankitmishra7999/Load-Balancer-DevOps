# Pins the Terraform CLI and provider versions so `terraform init` always
# resolves to the same behavior on any machine (yours, CI, an interviewer's).
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}
