output "producer_role_arn" {
  value = aws_iam_role.producer.arn
}

output "consumer_role_arn" {
  value = aws_iam_role.consumer.arn
}