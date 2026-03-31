resource "random_id" "suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "raw" {
  bucket = "${var.project}-raw-${var.environment}-${random_id.suffix.hex}"
force_destroy = true

tags = {
    Project     = var.project
    Environment = var.environment
  }

}

resource "aws_s3_bucket" "processed" {
  bucket = "${var.project}-processed-${var.environment}-${random_id.suffix.hex}"
force_destroy = true

tags = {
    Project     = var.project
    Environment = var.environment
  }

}

resource "aws_s3_bucket_lifecycle_configuration" "raw" {
  bucket = aws_s3_bucket.raw.id

  rule {
    id     = "expire-raw-after-30-days"
    status = "Enabled"
    filter {}
    expiration {
      days = 30
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "processed" {
  bucket = aws_s3_bucket.processed.id

  rule {
    id     = "move-to-infrequent-access"
    status = "Enabled"
    filter {}
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
  }
}