output "database_name" {
  value = aws_glue_catalog_database.telemetry.name
}

output "crawler_name" {
  value = aws_glue_crawler.telemetry.name
}