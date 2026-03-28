#!/bin/bash

# Test script to invoke RoboFleet Ingest Lambda with sample telemetry data
# Prerequisites:
#   - AWS CLI configured with proper credentials
#   - Sample telemetry data in sample_telemetry.jsonl

set -e

FUNCTION_NAME="robofleet-ingest"
REGION="us-east-1"

echo "════════════════════════════════════════════════════════════"
echo "Testing Ingest Lambda: $FUNCTION_NAME"
echo "════════════════════════════════════════════════════════════"

# Check if sample data exists
if [ ! -f "sample_telemetry.jsonl" ]; then
    echo "❌ Error: sample_telemetry.jsonl not found"
    echo "Run: python3 generate_sample_telemetry.py"
    exit 1
fi

echo ""
echo "📊 Sample Data Stats:"
wc -l sample_telemetry.jsonl
head -1 sample_telemetry.jsonl | jq .

echo ""
echo "🚀 Testing single record invocation..."

# Extract first record and test
FIRST_RECORD=$(head -1 sample_telemetry.jsonl)

# Create test event
cat > /tmp/lambda_test_event.json << TESTEOF
{
  "Records": [
    {
      "body": $(echo "$FIRST_RECORD" | jq -c .)
    }
  ]
}
TESTEOF

echo "Test event:"
cat /tmp/lambda_test_event.json | jq .

# Invoke Lambda
echo ""
echo "Invoking Lambda function..."
aws lambda invoke \
  --function-name "$FUNCTION_NAME" \
  --region "$REGION" \
  --payload file:///tmp/lambda_test_event.json \
  --log-type Tail \
  /tmp/lambda_response.json

echo ""
echo "✅ Lambda Response:"
cat /tmp/lambda_response.json | jq .

echo ""
echo "════════════════════════════════════════════════════════════"
echo "Next Steps:"
echo "  1. Check CloudWatch Logs: aws logs tail /aws/lambda/$FUNCTION_NAME --follow"
echo "  2. Verify S3: aws s3 ls s3://robofleet-data-lake/year=2026/ --recursive"
echo "  3. Check Glue Catalog: aws glue get-table --database-name robofleet --name telemetry"
echo "════════════════════════════════════════════════════════════"
