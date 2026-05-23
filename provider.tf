terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.39.0"
    }
  }
  backend "s3" {
    bucket = "remote-state-roboshop-dev-rk1214"
    key    = "roboshop-dev-catalogue"
    region = "us-east-1"
    ##dynamodb_table = "terraform-lock-table" # Optional: for locking
    encrypt      = true # Recommended
    use_lockfile = true
  }
}

provider "aws" {
  # Configuration options
}
