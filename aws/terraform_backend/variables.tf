variable "dynamodb_table" {
  type        = string
  description = "DynamoDB table name for terraform states locking"
}

variable "s3_bucket" {
  type        = string
  description = "S3 bucket name for terraform states"
}
