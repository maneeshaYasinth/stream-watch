output "queue_name" {
  value = module.sqs.queue_name
}

output "queue_url" {
  value = module.sqs.queue_url
}

output "raw_bucket_name" {
  value = module.s3.raw_bucket_name
}

output "processed_bucket_name" {
  value = module.s3.processed_bucket_name
}

output "producer_role_arn" {
  value = module.iam.producer_role_arn
}

output "consumer_role_arn" {
  value = module.iam.consumer_role_arn
}