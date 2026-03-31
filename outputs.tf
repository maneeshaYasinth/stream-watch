output "kinesis_stream_name" {
  value = module.kinesis.stream_name
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