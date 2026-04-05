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
  source      = "./modules/s3"
  project     = var.project
  environment = var.environment
}

module "sqs" {
  source      = "./modules/sqs"
  project     = var.project
  environment = var.environment
}

module "iam" {
  source               = "./modules/iam"
  project              = var.project
  environment          = var.environment
  queue_arn            = module.sqs.queue_arn
  raw_bucket_arn       = module.s3.raw_bucket_arn
  processed_bucket_arn = module.s3.processed_bucket_arn
}

module "lambda" {
  source                = "./modules/lambda"
  project               = var.project
  environment           = var.environment
  consumer_role_arn     = module.iam.consumer_role_arn
  queue_arn             = module.sqs.queue_arn
  processed_bucket_name = module.s3.processed_bucket_name
  raw_bucket_name       = module.s3.raw_bucket_name
}