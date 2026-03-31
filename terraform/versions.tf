terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }

  backend "s3" {
    bucket = "amzn-s3-atstatic-pott1212-tfstate"
    key    = "inventory-tracker/terraform.tfstate"
    region = "eu-north-1"
  }
}
