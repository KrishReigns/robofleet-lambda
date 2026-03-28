# RoboFleet Lambda Testing Guide

## Overview
This guide walks through testing the complete data pipeline:
```
Raw Telemetry Data → Ingest Lambda → S3 → Glue Catalog → Athena → Query Lambda
```

## Prerequisites

1. **AWS CLI configured**
   ```bash
   aws configure
   # Use your AWS credentials
   ```

2. **Python 3.8+** with boto3
   ```bash
   pip install boto3
   ```

3. **jq** (optional, for JSON formatting)
   ```bash
   brew install jq  # macOS
   apt install jq   # Ubuntu
   ```

---

## Phase 1: Generate Sample Data

Generate 500 realistic telemetry records matching your fleet structure:

```bash
python3 generate_sample_telemetry.py
```

**Output:**
- `sample_telemetry.jsonl` - JSON Lines format (one record per line, for streaming)
- `sample_telemetry.json` - JSON array format (for reference)

**Sample Record:**
```json
{
  "device_id": "ROBOT-0012",
  "fleet_id": "FLEET-SEATTLE-01",
  "timestamp": "2026-03-22T14:30:45Z",
  "location_zone": "ZONE-B",
  "battery_level": 75,
  "status": "ACTIVE",
  "speed": 2.45
}
```

**Data Distribution:**
- 20 devices (ROBOT-0001 to ROBOT-0020)
- 3 fleets (FLEET-BOSTON-01, FLEET-BOSTON-02, FLEET-SEATTLE-01)
- March 2-6, 2026 (realistic time range)
- Statuses: ACTIVE (40%), IDLE (35%), CHARGING (15%), ERROR (10%)
- Battery: 5-100% depending on status
- Speed: 0-3.5 m/s

---

## Phase 2: Test Ingest Lambda

### Option A: Batch Test (Recommended)
```bash
python3 test_lambda_batch.py
```

This automatically:
1. ✅ Tests small batch (5 records)
2. ✅ Tests medium batch (50 records)
3. ✅ Tests large batch (500 records)
4. ✅ Verifies data in S3
5. ✅ Checks CloudWatch logs

**Expected Output:**
```
TEST 1: Small Batch (5 records)
✅ Lambda Response Status: 200

TEST 2: Medium Batch (50 records)  
✅ Lambda Response Status: 200

TEST 3: Large Batch (500 records)
✅ Lambda Response Status: 200

VERIFICATION: Checking S3 Data Lake
✅ Found 155 objects in S3:
   • year=2026/month=03/day=22/hour=14/...parquet
   • year=2026/month=03/day=23/hour=08/...parquet
   ...
```

### Option B: Manual Single Test
```bash
bash test_lambda_ingest.sh
```

---

## Phase 3: Verify Data in S3

Check that telemetry data was partitioned correctly:

```bash
# List all data files
aws s3 ls s3://robofleet-data-lake/year=2026/ --recursive

# Count files by month/day
aws s3 ls s3://robofleet-data-lake/year=2026/month=03/ --recursive | wc -l

# Download a sample Parquet file to inspect
aws s3 cp s3://robofleet-data-lake/year=2026/month=03/day=20/hour=14/data.parquet . 
```

**Expected Structure:**
```
s3://robofleet-data-lake/
├── year=2026/
│   └── month=03/
│       ├── day=20/
│       │   ├── hour=14/data.parquet
│       │   ├── hour=15/data.parquet
│       │   └── ...
│       ├── day=21/
│       │   └── ...
│       └── ...
```

---

## Phase 4: Verify Glue Catalog

Check that the Glue Catalog table was created with correct schema:

```bash
# Get table metadata
aws glue get-table --database-name robofleet --name telemetry

# Get table schema
aws glue get-table --database-name robofleet --name telemetry \
  --query 'Table.StorageDescriptor.Columns' --output table
```

**Expected Columns:**
- device_id (string)
- fleet_id (string)
- timestamp (timestamp)
- location_zone (string)
- battery_level (int)
- status (string)
- speed (double)
- error_code (string, nullable)

**Expected Partitions:**
- year (int)
- month (int)
- day (int)
- hour (int)

---

## Phase 5: Test Query Lambda

Run analytical queries on the ingested data:

```bash
python3 test_lambda_query.py
```

This executes 4 key queries matching your analytics report:

### Query 1: Fleet Health
```sql
SELECT fleet_id, status, COUNT(*) as event_count,
       AVG(battery_level) as avg_battery, AVG(speed) as avg_speed
FROM robofleet_telemetry
WHERE year = 2026 AND month = 3
GROUP BY fleet_id, status
```

**Expected Results:**
```
fleet_id           | status   | event_count | avg_battery | avg_speed
FLEET-BOSTON-01    | ACTIVE   | 45          | 45.8        | 1.77
FLEET-BOSTON-01    | ERROR    | 56          | 55.9        | 0.0
...
```

### Query 2: Error Analysis (RCA)
```sql
SELECT device_id, error_code, COUNT(*) as error_count,
       MIN(timestamp) as first_seen, MAX(timestamp) as last_seen
FROM robofleet_telemetry
WHERE year = 2026 AND month = 3 AND status = 'ERROR'
GROUP BY device_id, error_code
```

### Query 3: Low Battery Alert
```sql
SELECT device_id, fleet_id, location_zone, battery_level, status
FROM robofleet_telemetry
WHERE year = 2026 AND month = 3 
  AND battery_level < 20 
  AND status != 'CHARGING'
```

### Query 4: Device Summary
```sql
SELECT device_id, fleet_id, COUNT(*) as total_events,
       SUM(CASE WHEN status = 'ERROR' THEN 1 ELSE 0 END) as error_count,
       AVG(battery_level) as avg_battery
FROM robofleet_telemetry
WHERE year = 2026 AND month = 3
GROUP BY device_id, fleet_id
```

---

## Phase 6: Monitor Lambda Logs

Watch real-time Lambda logs during testing:

```bash
# Follow Ingest Lambda logs
aws logs tail /aws/lambda/robofleet-ingest --follow

# Follow Processing Lambda logs
aws logs tail /aws/lambda/robofleet-processing --follow

# Follow Query Lambda logs
aws logs tail /aws/lambda/robofleet-query --follow
```

---

## Phase 7: Dashboard & Alerts

### CloudWatch Dashboard
View your deployed dashboard:
```
https://console.aws.amazon.com/cloudwatch/home?region=us-east-1#dashboards:name=robofleet-metrics
```

### CloudWatch Alarms
Check configured alarms:
```bash
aws cloudwatch describe-alarms --region us-east-1 | jq '.MetricAlarms[] | {AlarmName, StateValue}'
```

---

## Troubleshooting

### Issue: Lambda returns error 403
**Cause:** VPC endpoint not available or security group misconfigured
**Fix:**
```bash
# Check security group rules
aws ec2 describe-security-groups --group-ids <security-group-id>

# Verify VPC endpoint
aws ec2 describe-vpc-endpoints --region us-east-1
```

### Issue: Data not appearing in S3
**Cause:** Ingest Lambda processing failed silently
**Fix:**
```bash
# Check CloudWatch Logs
aws logs tail /aws/lambda/robofleet-ingest --follow

# Check Lambda Dead Letter Queue (DLQ) if configured
aws sqs receive-message --queue-url <dlq-url>
```

### Issue: Athena query returns "table not found"
**Cause:** Glue Catalog not yet updated
**Fix:**
```bash
# Wait 30 seconds for Glue crawler to run
sleep 30

# Manually trigger crawler
aws glue start-crawler --name robofleet-crawler

# Verify partitions were added
aws glue batch-get-partition --database-name robofleet --table-name telemetry \
  --partitions-to-get '[{"Values":["2026","03"]}]'
```

---

## Success Criteria

✅ All tests pass when:

1. **Phase 2:** Ingest Lambda returns status 200
2. **Phase 3:** S3 contains Parquet files in correct partitions
3. **Phase 4:** Glue Catalog table exists with correct schema
4. **Phase 5:** Athena queries return expected data
5. **Phase 6:** No errors in CloudWatch Logs
6. **Phase 7:** Dashboard displays metrics

---

## Next Steps

After successful testing:

1. **Load Production Data**
   - Update `generate_sample_telemetry.py` with real device IDs and fleet configuration
   - Run generation and ingest in scheduled intervals

2. **Set Up Alerting**
   - Configure SNS topics for low battery, errors, anomalies
   - Update Lambda functions to publish to SNS

3. **Build QuickSight Dashboard**
   - Connect QuickSight to Athena
   - Create visualizations matching your analytics report

4. **Automate Daily Reports**
   - Lambda daily trigger → Athena queries → SNS email/Slack
   - See: `src/functions/processing/index.ts` for report generation

---

## Files in This Package

- `generate_sample_telemetry.py` - Generate sample data
- `test_lambda_batch.py` - Test Ingest Lambda with batches
- `test_lambda_ingest.sh` - Single-record Lambda test
- `test_lambda_query.py` - Test Query Lambda with Athena
- `TESTING_GUIDE.md` - This file
- `sample_telemetry.jsonl` - Generated test data (JSON Lines)
- `sample_telemetry.json` - Generated test data (JSON array)

