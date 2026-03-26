variable "aws_region" {
  description = "AWS region to deploy all resources. Use us-east-1 — Athena is cheapest here."
  type        = string
  default     = "us-east-1"
}

variable "name_suffix" {
  description = "Short unique suffix for resource names (e.g. 'sk'). Keeps S3 bucket names globally unique."
  type        = string
  default     = "sk"

  validation {
    condition     = length(var.name_suffix) >= 2 && length(var.name_suffix) <= 8
    error_message = "name_suffix must be 2-8 characters."
  }
}

variable "data_lake_bucket_name" {
  description = "S3 bucket name for raw telemetry data. Must be globally unique."
  type        = string
  default     = ""
}

variable "athena_results_bucket_name" {
  description = "S3 bucket name where Athena writes query results."
  type        = string
  default     = ""
}

variable "alert_email" {
  description = "Email for CloudWatch alarm notifications."
  type        = string
  default     = "krishna1996sai@gmail.com"
}

variable "athena_bytes_scanned_alarm_threshold" {
  description = "Alarm fires if query scans more than this many bytes. Default: 100MB."
  type        = number
  default     = 104857600
}
