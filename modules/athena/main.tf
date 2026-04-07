resource "random_id" "suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "results" {
  bucket        = "${var.project}-athena-results-${var.environment}-${random_id.suffix.hex}"
  force_destroy = true

   tags = {
    Project     = var.project
    Environment = var.environment
  }

}

resource "aws_athena_workgroup" "telemetry" {
  name = "${var.project}-athena-telemetry-${var.environment}"
  force_destroy = true
  configuration {
    result_configuration {
      output_location = "s3://${aws_s3_bucket.results.bucket}/"
    }
  }

   tags = {
    Project     = var.project
    Environment = var.environment
  }
  
}