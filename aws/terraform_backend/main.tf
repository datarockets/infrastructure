# Ignored rules:
#   Bucket does not have encryption enabled
#   Bucket has logging disabled
#   Bucket does not encrypt data with a customer managed key
#trivy:ignore:AVD-AWS-0089 trivy:ignore:AVD-AWS-0132 trivy:ignore:AVD-AWS-0088
resource "aws_s3_bucket" "state" {
  bucket = var.s3_bucket
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Ignored rules:
#   Point-in-time recovery is not enabled
#   Table encryption does not use a customer-managed KMS key
#trivy:ignore:AVD-AWS-0024 trivy:ignore:AVD-AWS-0025
resource "aws_dynamodb_table" "state" {
  name         = var.dynamodb_table
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket = aws_s3_bucket.state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
