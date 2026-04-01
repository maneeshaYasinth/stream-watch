output "producer_role_arn" {
  value = aws_iam_role.producer_role.arn
}

output "consumer_role_arn" {
  value = aws_iam_role.consumer.arn
}