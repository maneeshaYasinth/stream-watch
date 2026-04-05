resource "aws_glue_catalog_database" "telemetry"{
    name = "${var.project}-${var.environment}"
}

resource "aws_iam_role" "glue_crawler" {
  name = "${var.project}-glue-crawler-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "glue.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "glue_service" {
  role       = aws_iam_role.glue_crawler.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

resource "aws_iam_role_policy" "glue_s3" {
  name = "s3-read"
  role = aws_iam_role.glue_crawler.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:GetObject", "s3:ListBucket"]
      Resource = [
        var.processed_bucket_arn,
        "${var.processed_bucket_arn}/*"
      ]
    }]
  })
}

resource "aws_glue_crawler" "telemetry" {
  name          = "${var.project}-crawler-${var.environment}"
  role          = aws_iam_role.glue_crawler.arn
  database_name = aws_glue_catalog_database.telemetry.name

  s3_target {
    path = "s3://${var.processed_bucket_name}/telemetry/"
  }

  configuration = jsonencode({
    Version = 1.0
    CrawlerOutput = {
      Partitions = { AddOrUpdateBehavior = "InheritFromTable" }
    }
  })

  schema_change_policy {
    update_behavior = "UPDATE_IN_DATABASE"
    delete_behavior = "LOG"
  }
    tags = {
        Environment = var.environment
        Project     = var.project
    }
}