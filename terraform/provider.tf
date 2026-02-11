terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

// Configure the AWS provider using variables. Do not hardcode credentials;
// use environment variables, shared credentials file, or an assumed role.
provider "aws" {
  region = var.region

  // Apply default tags to all resources for consistent tagging and cost tracking
  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      CreatedAt   = timestamp()
    }
  }
}

// Fetch availability zones for subnet placement
data "aws_availability_zones" "available" {
  state = "available"
}
