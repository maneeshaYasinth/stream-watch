output "workgroup_name" {
  value = aws_athena_workgroup.telemetry.name
}

output "results_bucket" {
  value = aws_s3_bucket.results
}