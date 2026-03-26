locals {
  # Auto-generate bucket names from name_suffix if not explicitly provided
  # If you set data_lake_bucket_name in variables.tf, use that. Otherwise auto-generate.
  data_lake_bucket     = var.data_lake_bucket_name != "" ? var.data_lake_bucket_name : "robofleet-analytics-${var.name_suffix}"
  athena_results_bucket = var.athena_results_bucket_name != "" ? var.athena_results_bucket_name : "robofleet-athena-results-${var.name_suffix}"

  # S3 folder prefix where your telemetry data lives
  telemetry_prefix = "raw/device_telemetry"

  # Find all CSV files in your robofleet-data folder (one folder level up from terraform)
  # fileset looks in ../robofleet-data and finds all .csv files recursively
  # Returns paths like: year=2026/month=03/day=20/telemetry_001.csv
  sample_data_files = fileset("${path.module}/../robofleet-data", "**/*.csv")
}
