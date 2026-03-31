terraform {
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
}

provider "aws" {
  region = var.region
}

module "s3" {
  source = "./modules/s3"
  project = var.project
  environment = var.environment
}

module "kinesis" {
  source = "./modules/kinesis"
  project = var.project
  environment = var.environment
}

module "iam" {
  source = "./modules/iam"
  project = var.project
  environment = var.environment
  kinesis_stream_arn = module.kinesis.kinesis_stream_arn
  raw_bucket_arn = module.s3.raw_bucket_arn
  processed_bucket_arn = module.s3.processed_bucket_arn
}