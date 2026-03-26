# =============================================================================
# S3 — Data Lake Bucket (raw telemetry data)
# =============================================================================

resource "aws_s3_bucket" "data_lake" {
  bucket = local.data_lake_bucket

  lifecycle {
    prevent_destroy = false
  }
}

resource "aws_s3_bucket_versioning" "data_lake" {
  bucket = aws_s3_bucket.data_lake.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "data_lake" {
  bucket = aws_s3_bucket.data_lake.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "data_lake" {
  bucket = aws_s3_bucket.data_lake.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "data_lake" {
  bucket = aws_s3_bucket.data_lake.id

  rule {
    id     = "archive-old-telemetry"
    status = "Enabled"

    filter {
      prefix = "raw/device_telemetry/"
    }

    transition {
      days          = 90
      storage_class = "GLACIER_IR"
    }

    expiration {
      days = 365
    }
  }
}

resource "aws_s3_object" "telemetry_data" {
  for_each = local.sample_data_files

  bucket       = aws_s3_bucket.data_lake.id
  key          = "${local.telemetry_prefix}/${each.value}"
  source       = "${path.module}/../robofleet-data/${each.value}"
  content_type = "text/csv"

  etag = filemd5("${path.module}/../robofleet-data/${each.value}")
}

# =============================================================================
# S3 — Athena Query Results Bucket
# =============================================================================

resource "aws_s3_bucket" "athena_results" {
  bucket = local.athena_results_bucket
}

resource "aws_s3_bucket_server_side_encryption_configuration" "athena_results" {
  bucket = aws_s3_bucket.athena_results.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "athena_results" {
  bucket = aws_s3_bucket.athena_results.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "athena_results" {
  bucket = aws_s3_bucket.athena_results.id

  rule {
    id     = "cleanup-query-results"
    status = "Enabled"
    filter {}  #  THIS LINE (empty filter = applies to ALL objects)
    expiration {
      days = 30
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }
}
