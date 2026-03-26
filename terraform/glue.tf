# =============================================================================
# AWS Glue Data Catalog — Database
# Athena uses the Glue Data Catalog as its metadata store.
# Think of this as the "schema registry" that tells Athena:
#   - Where data lives in S3
#   - What columns exist
#   - How data is partitioned
# Azure equivalent: This is similar to a database in Azure Synapse Analytics.
# =============================================================================

resource "aws_glue_catalog_database" "robofleet" {
  name        = "robofleet_db"
  description = "RoboFleet device telemetry analytics — partitioned by year/month/day"
}

# =============================================================================
# AWS Glue Catalog Table — device_telemetry
#
# KEY CONCEPTS:
# 1. storage_descriptor.columns  → the actual data columns in the CSV
# 2. partition_keys               → the folder-name columns (year, month, day)
#    IMPORTANT: partition_keys must NOT be repeated in storage_descriptor.columns
#    Athena treats them separately — they come from the folder path, not the file
#
# 3. SerDe = Serializer/Deserializer — tells Athena how to parse the file format
#    LazySimpleSerDe = standard CSV parser
# =============================================================================

resource "aws_glue_catalog_table" "device_telemetry" {
  name          = "device_telemetry"
  database_name = aws_glue_catalog_database.robofleet.name

  # EXTERNAL_TABLE = Athena doesn't own the data.
  # Dropping this table does NOT delete the S3 files. Always use this for analytics.
  table_type = "EXTERNAL_TABLE"

  parameters = {
    "classification"           = "csv"
    "skip.header.line.count"  = "1"
    "EXTERNAL"                 = "TRUE"
    "has_encrypted_data"       = "false"
  }

  storage_descriptor {
    # Where the data lives in S3 (all partitions live under this prefix)
    location      = "s3://${local.data_lake_bucket}/${local.telemetry_prefix}/"

    # These are the Hadoop input/output format classes for CSV files
    input_format  = "org.apache.hadoop.mapred.TextInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"

    # SerDe: how to parse CSV rows into columns
    ser_de_info {
      serialization_library = "org.apache.hadoop.hive.serde2.lazy.LazySimpleSerDe"
      parameters = {
        "field.delim"          = ","
        "serialization.format" = ","
        "escape.delim"         = "\\"
      }
    }

    # Data columns — same order as the CSV file columns
    # NOTE: Do NOT include year/month/day here — those are partition_keys below
    columns {
      name    = "device_id"
      type    = "string"
      comment = "Robot device identifier e.g. ROBOT-0001"
    }
    columns {
      name    = "fleet_id"
      type    = "string"
      comment = "Fleet grouping e.g. FLEET-BOSTON-01"
    }
    columns {
      name    = "event_time"
      type    = "timestamp"
      comment = "UTC timestamp when the event was recorded"
    }
    columns {
      name    = "battery_level"
      type    = "int"
      comment = "Battery percentage 0-100"
    }
    columns {
      name    = "speed_mps"
      type    = "double"
      comment = "Robot speed in meters per second"
    }
    columns {
      name    = "status"
      type    = "string"
      comment = "Operational state: ACTIVE | IDLE | ERROR | CHARGING"
    }
    columns {
      name    = "error_code"
      type    = "string"
      comment = "Error identifier, populated only when status=ERROR"
    }
    columns {
      name    = "location_zone"
      type    = "string"
      comment = "Physical zone within the facility e.g. ZONE-A"
    }
    columns {
      name    = "temperature_celsius"
      type    = "double"
      comment = "Device internal temperature in Celsius"
    }
  }

  # Partition keys — these match the S3 folder naming: year=2026/month=03/day=22
  # Athena reads these from the folder path, NOT from inside the CSV file
  partition_keys {
    name    = "year"
    type    = "string"
    comment = "Partition year extracted from folder path"
  }
  partition_keys {
    name    = "month"
    type    = "string"
    comment = "Partition month (zero-padded) extracted from folder path"
  }
  partition_keys {
    name    = "day"
    type    = "string"
    comment = "Partition day (zero-padded) extracted from folder path"
  }

  # Re-create table if the S3 location changes
  lifecycle {
    create_before_destroy = true
  }

  # Table depends on data being uploaded first
  depends_on = [aws_s3_object.telemetry_data]
}
