resource "aws_lambda_function" "consumer" {
  function_name    = "${var.project}-consumer-${var.environment}"
  role             = var.consumer_role_arn
  runtime          = "python3.12"
  handler          = "lambda_function.lambda_handler"
  s3_bucket        = var.raw_bucket_name
  s3_key           = "lambda/lambda.zip"
  source_code_hash = filebase64sha256("${path.module}/lambda.zip")
  timeout          = 300
  memory_size      = 512
  architectures    = ["arm64"]

  environment {
    variables = {
      PROCESSED_BUCKET = var.processed_bucket_name
    }
  }

  tracing_config {
    mode = "Active"
  }

  tags = {
    Project     = var.project
    Environment = var.environment
  }
}

resource "aws_lambda_event_source_mapping" "sqs" {
  event_source_arn                   = var.queue_arn
  function_name                      = aws_lambda_function.consumer.arn
  batch_size                         = 10
  maximum_batching_window_in_seconds = 5
  enabled                            = true
  function_response_types            = ["ReportBatchItemFailures"]
}