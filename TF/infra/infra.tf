variable "DEPLOYMENTPREFIX" {}

resource "random_string" "random" {
  length  = 8
  special = false
}

resource "aws_s3_bucket" "lambda-store" {
  bucket        = lower(join("", [var.DEPLOYMENTPREFIX, "-", random_string.random.result]))
  force_destroy = true
}


resource "aws_s3_bucket_versioning" "s3_versioning" {
  bucket = aws_s3_bucket.lambda-store.id
  versioning_configuration {
    status = "Enabled"
  }
}

output "S3_DETAILS" {
  value = aws_s3_bucket.lambda-store
}