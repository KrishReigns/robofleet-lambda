# =============================================================================
# IAM — Athena Execution Role
#
# This role will be used by Lambda (Day 2) to run Athena queries programmatically.
# For Day 1, creating it now means Day 2 just references it — no IAM work needed.
#
# Principle of least privilege: only the exact S3 paths and actions needed.
# =============================================================================

# Trust policy: allows Lambda service to assume this role
data "aws_iam_policy_document" "athena_lambda_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "athena_execution" {
  name               = "robofleet-athena-execution-role"
  assume_role_policy = data.aws_iam_policy_document.athena_lambda_trust.json
  description        = "Role assumed by Lambda to execute Athena queries on RoboFleet data"
}

# =============================================================================
# Athena + S3 permissions policy
# =============================================================================

data "aws_iam_policy_document" "athena_s3_access" {

  # Athena: run queries and check status
  statement {
    sid    = "AthenaQueryAccess"
    effect = "Allow"
    actions = [
      "athena:StartQueryExecution",
      "athena:GetQueryExecution",
      "athena:GetQueryResults",
      "athena:StopQueryExecution",
      "athena:ListQueryExecutions",
      "athena:GetWorkGroup",
    ]
    resources = [
      aws_athena_workgroup.robofleet.arn,
    ]
  }

  # Glue Data Catalog: read schema (needed for Athena to understand table structure)
  statement {
    sid    = "GlueCatalogRead"
    effect = "Allow"
    actions = [
      "glue:GetDatabase",
      "glue:GetDatabases",
      "glue:GetTable",
      "glue:GetTables",
      "glue:GetPartition",
      "glue:GetPartitions",
      "glue:BatchGetPartition",
    ]
    resources = [
      "arn:aws:glue:*:*:catalog",
      aws_glue_catalog_database.robofleet.arn,
      "arn:aws:glue:*:*:table/${aws_glue_catalog_database.robofleet.name}/*",
    ]
  }

  # S3: read from data lake, write to results bucket
  statement {
    sid    = "S3DataLakeRead"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:ListBucket",
      "s3:GetBucketLocation",
    ]
    resources = [
      aws_s3_bucket.data_lake.arn,
      "${aws_s3_bucket.data_lake.arn}/*",
    ]
  }

  statement {
    sid    = "S3ResultsWrite"
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:ListBucket",
      "s3:GetBucketLocation",
    ]
    resources = [
      aws_s3_bucket.athena_results.arn,
      "${aws_s3_bucket.athena_results.arn}/*",
    ]
  }

  # SES: send HTML email analytics reports
  statement {
    sid    = "SESEmailSend"
    effect = "Allow"
    actions = [
      "ses:SendEmail",
      "ses:SendRawEmail",
    ]
    resources = ["*"]
  }

  # CloudWatch Logs: Lambda needs to write execution logs
  statement {
    sid    = "CloudWatchLogs"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["arn:aws:logs:*:*:*"]
  }
}

resource "aws_iam_policy" "athena_s3_access" {
  name        = "robofleet-athena-s3-access"
  description = "Least-privilege policy for Athena query execution on RoboFleet data"
  policy      = data.aws_iam_policy_document.athena_s3_access.json
}

resource "aws_iam_role_policy_attachment" "athena_execution" {
  role       = aws_iam_role.athena_execution.name
  policy_arn = aws_iam_policy.athena_s3_access.arn
}

# Attach basic Lambda execution policy (needed for Lambda to start at all)
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.athena_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
