output "s3_bucket" {
  value = aws_s3_bucket.state.bucket
}

output "dynamodb_table" {
  value = aws_dynamodb_table.state.name
}
