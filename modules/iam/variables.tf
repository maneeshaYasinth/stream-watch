variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "kinesis_stream_arn" {
  type = string
}

variable "raw_bucket_arn" {
  type = string
}

variable "processed_bucket_arn" {
  type = string
}
