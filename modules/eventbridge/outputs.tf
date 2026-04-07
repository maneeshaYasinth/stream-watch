output "sns_topic_arn" {
  value = aws_sns_topic.fastest_lap.arn
}

output "event_rule_name" {
  value = aws_cloudwatch_event_rule.fastest_lap.name
}