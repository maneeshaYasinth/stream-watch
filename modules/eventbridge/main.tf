resource "aws_sns_topic" "fastest_lap" {
  name = "${var.project}-fastest-lap-${var.environment}"

  tags = {
    project = var.project
    environment = var.environment
  }
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.fastest_lap.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_cloudwatch_event_rule" "fastest_lap" {
    name = "${var.project}-fastest-lap-${var.environment}"
    description = "Triggers when a new fastest lap is set"

    event_pattern = jsonencode({
      source      = ["stream-watch.telemetry"]
      detail-type = ["FastestLap"]
    })

    tags = {
    project = var.project
    environment = var.environment
  }
}

resource "aws_cloudwatch_event_target" "sns" {
  rule = aws_cloudwatch_event_rule.fastest_lap.name
  target_id = "SendToSNS"
  arn  = aws_sns_topic.fastest_lap.arn
}

resource "aws_sns_topic_policy" "eventbridge" {
  arn = aws_sns_topic.fastest_lap.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "events.amazonaws.com" }
      Action    = "sns:Publish"
      Resource  = aws_sns_topic.fastest_lap.arn
    }]
  })
}