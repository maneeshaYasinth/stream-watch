output "stream_arn" {
  value = aws_kinesis_stream.telemetry.arn
}

output "stream_name" {
  value = aws_kinesis_stream.telemetry.name
}