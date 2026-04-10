variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "aws_region" {
  type = string
}
variable "lambda_function_name" {
  type = string
}

variable "queue_name" {
  type = string
}

variable "processed_bucket_name" {
  type = string
}

variable "dlq_name" {
  type = string
}