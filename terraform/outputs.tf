# =============================================================================
# Outputs — printed after `terraform apply` completes
# Copy these values — you'll need them to configure Athena in the console
# and for Day 2 (Lambda + QuickSight setup)
# =============================================================================

output "data_lake_bucket_name" {
  description = "S3 data lake bucket — this is where your telemetry data lives"
  value       = aws_s3_bucket.data_lake.bucket
}

output "data_lake_bucket_arn" {
  description = "ARN of the data lake bucket — used in IAM policies"
  value       = aws_s3_bucket.data_lake.arn
}

output "athena_results_bucket_name" {
  description = "S3 bucket for Athena query results — paste this in Athena console Settings"
  value       = aws_s3_bucket.athena_results.bucket
}

output "athena_results_s3_path" {
  description = "Full S3 path to paste into Athena console → Settings → Query result location"
  value       = "s3://${aws_s3_bucket.athena_results.bucket}/query-results/"
}

output "athena_workgroup_name" {
  description = "Athena workgroup name — select this in the Athena console Workgroup dropdown"
  value       = aws_athena_workgroup.robofleet.name
}

output "glue_database_name" {
  description = "Glue database name — select this in the Athena console Database dropdown"
  value       = aws_glue_catalog_database.robofleet.name
}

output "glue_table_name" {
  description = "Glue table name — use this in your SQL queries"
  value       = aws_glue_catalog_table.device_telemetry.name
}

output "iam_role_arn" {
  description = "IAM role ARN for Lambda (needed on Day 2)"
  value       = aws_iam_role.athena_execution.arn
}

output "cloudwatch_dashboard_url" {
  description = "Direct link to your CloudWatch ops dashboard"
  value       = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.robofleet_ops.dashboard_name}"
}

output "sns_topic_arn" {
  description = "SNS topic ARN for alerts (needed for Day 2 Lambda notifications)"
  value       = aws_sns_topic.robofleet_alerts.arn
}

output "uploaded_data_files" {
  description = "List of CSV files uploaded to S3"
  value       = [for k, v in aws_s3_object.telemetry_data : "s3://${v.bucket}/${v.key}"]
}

output "next_step_athena_query" {
  description = "Run this in Athena console after terraform apply to load partitions"
  value       = "MSCK REPAIR TABLE ${aws_glue_catalog_database.robofleet.name}.${aws_glue_catalog_table.device_telemetry.name};"
}
