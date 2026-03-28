#!/bin/bash

echo "=== Setting ExecutionRole for Athena Workgroup ==="
echo ""

# Add ExecutionRole to the workgroup
echo "Adding ExecutionRole to robofleet-workgroup..."
aws athena update-work-group \
  --work-group robofleet-workgroup \
  --region us-east-1 \
  --configuration-updates 'ExecutionRole=arn:aws:iam::235695894002:role/AmazonAthenaQueryServiceRole'

if [ $? -eq 0 ]; then
  echo "✅ ExecutionRole added successfully"
  echo ""
  echo "=== Verifying Workgroup Configuration ==="
  aws athena get-work-group --work-group robofleet-workgroup --region us-east-1 | jq '.WorkGroup.Configuration'
  echo ""
  echo "=== Testing Query Lambda Again ==="
  echo ""

  # Test the query lambda with a simple count query
  PAYLOAD='{"query":"SELECT COUNT(*) as record_count FROM device_telemetry"}'
  ENCODED=$(echo -n "$PAYLOAD" | base64)

  echo "Invoking Query Lambda..."
  aws lambda invoke \
    --function-name robofleet-query \
    --region us-east-1 \
    --payload "$ENCODED" \
    /tmp/query_response.json

  echo ""
  echo "Response:"
  cat /tmp/query_response.json
  echo ""

else
  echo "❌ Failed to add ExecutionRole"
  exit 1
fi
