# RoboFleet Testing - Quick Start (5 minutes)

## 📋 What You Have

I've created a complete testing suite with **500 realistic sample telemetry records** and **4 automated test scripts**.

## 🚀 Quick Start (Step by Step)

### Step 1: Generate Sample Data
```bash
cd /path/to/robofleet-lambda
python3 generate_sample_telemetry.py
```

✅ Creates:
- `sample_telemetry.jsonl` (500 records, one per line)
- `sample_telemetry.json` (500 records in JSON array)

### Step 2: Test Ingest Lambda (Send data to S3)
```bash
python3 test_lambda_batch.py
```

This will:
1. ✅ Send 5-record batch → Lambda
2. ✅ Send 50-record batch → Lambda
3. ✅ Send 500-record batch → Lambda
4. ✅ Verify data in S3

**Expected Output:** All Lambda invocations return status 200 ✅

### Step 3: Verify S3 Data
```bash
aws s3 ls s3://robofleet-data-lake/year=2026/month=03/ --recursive | head -20
```

Should show Parquet files in partitioned folders:
```
2026-03-27 19:45:32      45123 year=2026/month=03/day=20/hour=14/data.parquet
2026-03-27 19:45:33      51234 year=2026/month=03/day=21/hour=08/data.parquet
...
```

### Step 4: Test Query Lambda (Run Athena Queries)
```bash
python3 test_lambda_query.py
```

This will:
1. ✅ Query Fleet Health
2. ✅ Query Error Analysis
3. ✅ Query Low Battery Alerts
4. ✅ Query Device Summary

**Expected Output:** Results matching your analytics report

---

## 📊 Sample Data Structure

Each telemetry record has:
```json
{
  "device_id": "ROBOT-0012",           // 20 unique devices
  "fleet_id": "FLEET-SEATTLE-01",      // 3 fleets
  "timestamp": "2026-03-22T14:30:45Z", // March 2026
  "location_zone": "ZONE-B",           // 5 zones
  "battery_level": 75,                 // 0-100%
  "status": "ACTIVE",                  // ACTIVE|IDLE|CHARGING|ERROR
  "speed": 2.45                        // 0-3.5 m/s
}
```

**Distribution:**
- 500 total records
- 20 devices × 3 fleets
- ACTIVE (40%), IDLE (35%), CHARGING (15%), ERROR (10%)
- Matches your analytics report exactly

---

## 🔍 Monitoring

### Watch Lambda Logs in Real-Time
```bash
# Ingest Lambda
aws logs tail /aws/lambda/robofleet-ingest --follow

# Query Lambda
aws logs tail /aws/lambda/robofleet-query --follow
```

### Check CloudWatch Dashboard
```
https://console.aws.amazon.com/cloudwatch/home?region=us-east-1#dashboards:name=robofleet-metrics
```

---

## ❌ Troubleshooting

### Issue: "Lambda function not found"
```bash
# Verify function exists
aws lambda list-functions --region us-east-1 | grep robofleet
```

### Issue: "Permission denied" writing to S3
```bash
# Check Ingest Lambda execution role
aws lambda get-function-concurrency --function-name robofleet-ingest
```

### Issue: "Table not found" in Athena
```bash
# Wait for Glue Crawler to finish
sleep 30

# Manually trigger if needed
aws glue start-crawler --name robofleet-crawler
```

---

## 📝 Files Included

| File | Purpose |
|------|---------|
| `generate_sample_telemetry.py` | Generate 500 test records |
| `test_lambda_batch.py` | Test Ingest Lambda (recommended) |
| `test_lambda_ingest.sh` | Test single record (alternative) |
| `test_lambda_query.py` | Test Query Lambda with Athena |
| `sample_telemetry.jsonl` | 500 test records (JSON Lines) |
| `sample_telemetry.json` | 500 test records (JSON array) |
| `TESTING_GUIDE.md` | Complete detailed guide |
| `QUICK_START_TESTING.md` | This file |

---

## ✅ Success Checklist

- [ ] `generate_sample_telemetry.py` runs successfully
- [ ] `test_lambda_batch.py` shows all 3 batches with status 200
- [ ] S3 shows Parquet files in `year=2026/month=03/` structure
- [ ] Glue Catalog table exists and has correct schema
- [ ] `test_lambda_query.py` returns query results
- [ ] CloudWatch Dashboard shows metrics

---

## Next Steps

After testing succeeds:

1. **Set up SNS alerts** for low battery and errors
2. **Create QuickSight dashboard** connected to Athena
3. **Schedule daily reports** via Lambda
4. **Load production data** with real device IDs

See `TESTING_GUIDE.md` for detailed instructions.

---

**Questions?** Check `TESTING_GUIDE.md` for complete documentation.
