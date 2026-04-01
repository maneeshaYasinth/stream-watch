output "queue_arn" {
  value = aws_sqs_queue.telemetry.arn
}

output "queue_url" {
  value = aws_sqs_queue.telemetry.url
}

output "queue_name" {
  value = aws_sqs_queue.telemetry.name
}

output "dlq_arn" {
  value = aws_sqs_queue.telemetry_dlq.arn
}