resource "aws_kinesis_stream" "telemetry" {
  name             = "${var.project}-telemetry-${var.environment}"
  shard_count      = 2
  retention_period = 24

  stream_mode_details {
    stream_mode = "PROVISIONED"
  }

  tags = {
    Project     = var.project
    Environment = var.environment
  }
}