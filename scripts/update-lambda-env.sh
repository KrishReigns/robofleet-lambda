#!/bin/bash

echo "=== Updating Lambda Environment Variables ==="
echo ""

echo "Current environment for robofleet-query:"
aws lambda get-function-configuration --function-name robofleet-query --region us-east-1 | jq '.Environment.Variables'
echo ""

echo "Updating ATHENA_OUTPUT_BUCKET to ATHENA_RESULTS_BUCKET..."
aws lambda update-function-configuration \
  --function-name robofleet-query \
  --region us-east-1 \
  --environment 'Variables={ATHENA_RESULTS_BUCKET=robofleet-athena-results-235695894002,GLUE_DATABASE=robofleet_db,DEVICE_TELEMETRY_TABLE=device_telemetry,LOG_LEVEL=INFO}' \
  | jq '.Environment.Variables'

echo ""
echo "=== Testing Query Lambda ==="
echo ""

PAYLOAD='{"query":"SELECT COUNT(*) as record_count FROM device_telemetry"}'
ENCODED=$(echo -n "$PAYLOAD" | base64)

echo "Invoking robofleet-query with: $PAYLOAD"
aws lambda invoke \
  --function-name robofleet-query \
  --region us-east-1 \
  --payload "$ENCODED" \
  /tmp/query_response.json

echo ""
echo "Response:"
cat /tmp/query_response.json | jq '.'
