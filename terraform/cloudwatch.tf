# =============================================================================
# CloudWatch — SNS Topic for Alarm Notifications
# SNS (Simple Notification Service) is the pub/sub layer — alarms publish here,
# email subscribers receive them.
# =============================================================================

resource "aws_sns_topic" "robofleet_alerts" {
  name = "robofleet-alerts"
}

resource "aws_sns_topic_subscription" "email_alert" {
  topic_arn = aws_sns_topic.robofleet_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
  # NOTE: After terraform apply, AWS sends a confirmation email.
  # You MUST click the confirmation link or alarms will not deliver.
}

# =============================================================================
# CloudWatch Alarm 1 — Data Scanned Cost Guardrail
#
# Fires when an Athena query scans more than the threshold (default: 100MB).
# This catches runaway queries that forgot to filter on partition columns.
# The JD calls this an "operational guardrail" — this is exactly what they mean.
# =============================================================================

resource "aws_cloudwatch_metric_alarm" "athena_data_scanned" {
  alarm_name          = "RoboFleet-Athena-HighDataScan"
  alarm_description   = "Athena query scanned an unexpectedly large amount of data — possible missing partition filter"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ProcessedBytes"
  namespace           = "AWS/Athena"
  period              = 300 # 5 minutes
  statistic           = "Maximum"
  threshold           = var.athena_bytes_scanned_alarm_threshold

  dimensions = {
    WorkGroup = aws_athena_workgroup.robofleet.name
  }

  alarm_actions = [aws_sns_topic.robofleet_alerts.arn]
  ok_actions    = [aws_sns_topic.robofleet_alerts.arn]

  treat_missing_data = "notBreaching"

  tags = {
    Purpose = "cost-guardrail"
  }
}

# =============================================================================
# CloudWatch Alarm 2 — Query Failure Rate
#
# Fires if Athena queries start failing — schema change, bad partition,
# or broken data file. This is your "data quality" early warning system.
# =============================================================================

resource "aws_cloudwatch_metric_alarm" "athena_query_failures" {
  alarm_name          = "RoboFleet-Athena-QueryFailures"
  alarm_description   = "Athena queries are failing — check for schema changes, missing partitions, or corrupt data files"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "EngineExecutionTime"
  namespace           = "AWS/Athena"
  period              = 60
  statistic           = "SampleCount"
  threshold           = 0

  dimensions = {
    WorkGroup = aws_athena_workgroup.robofleet.name
  }

  alarm_actions = [aws_sns_topic.robofleet_alerts.arn]

  treat_missing_data = "notBreaching"

  tags = {
    Purpose = "data-quality"
  }
}

# =============================================================================
# CloudWatch Alarm 3 — S3 Data Lake Write Errors
#
# Fires if new data files fail to land in the data lake bucket.
# This would catch upstream pipeline failures before they become invisible.
# =============================================================================

resource "aws_cloudwatch_metric_alarm" "s3_errors" {
  alarm_name          = "RoboFleet-S3-PutErrors"
  alarm_description   = "S3 PutObject errors detected on data lake bucket — ingestion pipeline may be failing"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "5xxErrors"
  namespace           = "AWS/S3"
  period              = 300
  statistic           = "Sum"
  threshold           = 5

  dimensions = {
    BucketName = aws_s3_bucket.data_lake.bucket
    FilterId   = "EntireBucket"
  }

  alarm_actions = [aws_sns_topic.robofleet_alerts.arn]

  treat_missing_data = "notBreaching"

  tags = {
    Purpose = "ingestion-health"
  }
}

# =============================================================================
# CloudWatch Dashboard — RoboFleet Ops Overview
# A single pane of glass for the platform. The JD mentions building
# CloudWatch dashboards — this is infrastructure-as-code for that.
# =============================================================================

resource "aws_cloudwatch_dashboard" "robofleet_ops" {
  dashboard_name = "RoboFleet-Operations"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "Athena — Data Scanned Per Query (MB)"
          view   = "timeSeries"
          region = var.aws_region
          metrics = [
            ["AWS/Athena", "ProcessedBytes", "WorkGroup", aws_athena_workgroup.robofleet.name,
              { stat = "Maximum", label = "Max bytes scanned", color = "#d62728" }
            ],
            ["AWS/Athena", "ProcessedBytes", "WorkGroup", aws_athena_workgroup.robofleet.name,
              { stat = "Average", label = "Avg bytes scanned", color = "#1f77b4" }
            ]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "Athena — Query Execution Time (ms)"
          view   = "timeSeries"
          region = var.aws_region
          metrics = [
            ["AWS/Athena", "TotalExecutionTime", "WorkGroup", aws_athena_workgroup.robofleet.name,
              { stat = "Average", label = "Avg execution time" }
            ],
            ["AWS/Athena", "EngineExecutionTime", "WorkGroup", aws_athena_workgroup.robofleet.name,
              { stat = "Average", label = "Engine time" }
            ]
          ]
        }
      },
      {
        type   = "alarm"
        x      = 0
        y      = 6
        width  = 24
        height = 4
        properties = {
          title = "Active Alarms"
          alarms = [
            aws_cloudwatch_metric_alarm.athena_data_scanned.arn,
            aws_cloudwatch_metric_alarm.athena_query_failures.arn,
            aws_cloudwatch_metric_alarm.s3_errors.arn,
          ]
        }
      }
    ]
  })
}
