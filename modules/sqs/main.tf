resource "aws_sqs_queue" "telemetry_dlq" {
  name                      = "${var.project}-telemetry-dlq-${var.environment}"
  message_retention_seconds = 1209600

  tags = {
    Project     = var.project
    Environment = var.environment
  }
}

resource "aws_sqs_queue" "telemetry" {
  name                       = "${var.project}-telemetry-${var.environment}"
  visibility_timeout_seconds = 300
  message_retention_seconds  = 86400
  receive_wait_time_seconds  = 20

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.telemetry_dlq.arn
    maxReceiveCount     = 3
  })

  tags = {
    Project     = var.project
    Environment = var.environment
  }
}