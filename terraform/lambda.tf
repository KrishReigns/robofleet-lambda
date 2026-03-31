# =============================================================================
# Lambda Functions
#
# Two functions:
#   1. robofleet-analytics-queries — runs 3 Athena queries daily, emails HTML report via SES
#   2. robofleet-sns-to-slack      — optional, forwards CloudWatch alarms to Slack
#
# GitHub Actions updates the code on every push to main.
# Terraform manages the function config, IAM, EventBridge trigger, and permissions.
# =============================================================================

# Package src/ into a zip for initial Terraform deployment
# GitHub Actions replaces the code on every subsequent push.
data "archive_file" "lambda_package" {
  type        = "zip"
  source_dir  = "${path.module}/../src"
  output_path = "${path.module}/../lambda.zip"
}

# -----------------------------------------------------------------------------
# Lambda 1: Analytics Queries
# -----------------------------------------------------------------------------
resource "aws_lambda_function" "analytics_queries" {
  function_name    = "robofleet-analytics-queries"
  description      = "Runs 3 Athena queries daily and emails an HTML report via SES"
  filename         = data.archive_file.lambda_package.output_path
  source_code_hash = data.archive_file.lambda_package.output_base64sha256
  handler          = "lambda_robofleet_queries.lambda_handler"
  runtime          = "python3.11"
  role             = aws_iam_role.athena_execution.arn
  timeout          = 300
  memory_size      = 256

  environment {
    variables = {
      ATHENA_RESULTS_PATH = "s3://${aws_s3_bucket.athena_results.bucket}/query-results/"
      ATHENA_WORKGROUP    = aws_athena_workgroup.robofleet.name
      SES_SENDER_EMAIL    = var.ses_sender_email
      SES_RECIPIENT_EMAIL = var.alert_email
    }
  }

  tags = {
    Name = "robofleet-analytics-queries"
  }
}

# EventBridge rule: trigger daily at 08:00 UTC
resource "aws_cloudwatch_event_rule" "daily_analytics" {
  name                = "robofleet-daily-analytics"
  description         = "Trigger analytics Lambda daily at 08:00 UTC"
  schedule_expression = "cron(0 8 * * ? *)"
}

resource "aws_cloudwatch_event_target" "analytics_lambda" {
  rule      = aws_cloudwatch_event_rule.daily_analytics.name
  target_id = "robofleet-analytics-queries"
  arn       = aws_lambda_function.analytics_queries.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.analytics_queries.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily_analytics.arn
}

# -----------------------------------------------------------------------------
# Lambda 2: SNS-to-Slack (optional — only deployed when slack_webhook_url is set)
# -----------------------------------------------------------------------------
resource "aws_lambda_function" "sns_to_slack" {
  count            = var.slack_webhook_url != "" ? 1 : 0
  function_name    = "robofleet-sns-to-slack"
  description      = "Forwards CloudWatch alarm SNS messages to Slack"
  filename         = data.archive_file.lambda_package.output_path
  source_code_hash = data.archive_file.lambda_package.output_base64sha256
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.11"
  role             = aws_iam_role.athena_execution.arn
  timeout          = 30
  memory_size      = 128

  environment {
    variables = {
      SLACK_WEBHOOK_URL = var.slack_webhook_url
    }
  }

  tags = {
    Name = "robofleet-sns-to-slack"
  }
}

resource "aws_sns_topic_subscription" "slack_lambda" {
  count     = var.slack_webhook_url != "" ? 1 : 0
  topic_arn = aws_sns_topic.robofleet_alerts.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.sns_to_slack[0].arn
}

resource "aws_lambda_permission" "allow_sns_slack" {
  count         = var.slack_webhook_url != "" ? 1 : 0
  statement_id  = "AllowSNSInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.sns_to_slack[0].function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.robofleet_alerts.arn
}
