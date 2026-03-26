# =============================================================================
# Athena Workgroup
#
# A workgroup is a named execution context for Athena queries.
# It lets you:
#   - Set per-workgroup query result locations
#   - Enforce data usage limits (cost control)
#   - Separate dev/prod query environments
#   - Track query history per team
#
# Azure equivalent: Think of it like a dedicated SQL pool in Azure Synapse,
# but serverless and pay-per-query.
# =============================================================================

resource "aws_athena_workgroup" "robofleet" {
  name        = "robofleet-workgroup"
  description = "RoboFleet analytics — device telemetry queries"

  configuration {
    # Force all queries in this workgroup to write results to our results bucket
    # This prevents users from accidentally writing results elsewhere
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = true  # enables CloudWatch metrics for alarms

    result_configuration {
      output_location = "s3://${aws_s3_bucket.athena_results.bucket}/query-results/"

      encryption_configuration {
        encryption_option = "SSE_S3"
      }
    }

    # Cost guardrail: cancel any query that would scan more than 1GB
    # In production this protects against runaway full-table scans
    bytes_scanned_cutoff_per_query = 1073741824 # 1 GB in bytes
  }

  # Preserve query history even if workgroup is recreated
  force_destroy = true
}

# =============================================================================
# Athena Named Queries
# Save your most-used SQL queries so anyone on the team can find and run them.
# The JD mentions "repeatable reporting" — this is the mechanism for that.
# =============================================================================

resource "aws_athena_named_query" "fleet_health_summary" {
  name        = "fleet-health-summary"
  workgroup   = aws_athena_workgroup.robofleet.id
  database    = aws_glue_catalog_database.robofleet.name
  description = "Daily fleet health: event counts, avg battery, active % per fleet"

  query = <<-SQL
    SELECT
      fleet_id,
      status,
      COUNT(*)                    AS event_count,
      ROUND(AVG(battery_level), 1) AS avg_battery,
      ROUND(AVG(speed_mps), 2)    AS avg_speed
    FROM robofleet_db.device_telemetry
    WHERE year  = '2026'
      AND month = '03'
    GROUP BY fleet_id, status
    ORDER BY fleet_id, event_count DESC;
  SQL
}

resource "aws_athena_named_query" "error_analysis" {
  name        = "error-analysis-rca"
  workgroup   = aws_athena_workgroup.robofleet.id
  database    = aws_glue_catalog_database.robofleet.name
  description = "Error frequency by device and error code — use for RCA investigations"

  query = <<-SQL
    SELECT
      device_id,
      error_code,
      COUNT(*)          AS error_count,
      MIN(event_time)   AS first_seen,
      MAX(event_time)   AS last_seen
    FROM robofleet_db.device_telemetry
    WHERE year   = '2026'
      AND month  = '03'
      AND status = 'ERROR'
      AND error_code != ''
    GROUP BY device_id, error_code
    ORDER BY error_count DESC;
  SQL
}

resource "aws_athena_named_query" "low_battery_alert" {
  name        = "low-battery-operational-check"
  workgroup   = aws_athena_workgroup.robofleet.id
  database    = aws_glue_catalog_database.robofleet.name
  description = "Robots with battery < 20% that are not charging — operational alarm query"

  query = <<-SQL
    SELECT
      device_id,
      fleet_id,
      location_zone,
      battery_level,
      status,
      event_time
    FROM robofleet_db.device_telemetry
    WHERE year          = '2026'
      AND month         = '03'
      AND battery_level < 20
      AND status        NOT IN ('CHARGING')
    ORDER BY battery_level ASC;
  SQL
}
