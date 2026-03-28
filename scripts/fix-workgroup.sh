#!/bin/bash

echo "=== Fixing Athena Workgroup Configuration ==="
echo ""

# Update the workgroup to use the correct results bucket
echo "Updating workgroup to use robofleet-athena-results-235695894002..."
aws athena update-work-group \
  --work-group robofleet-workgroup \
  --region us-east-1 \
  --configuration-updates 'ResultConfigurationUpdates={OutputLocation=s3://robofleet-athena-results-235695894002/query-results/,EncryptionConfiguration={EncryptionOption=SSE_S3}},EnforceWorkGroupConfiguration=true,PublishCloudWatchMetricsEnabled=true'

if [ $? -eq 0 ]; then
  echo "✅ Workgroup updated successfully"
  echo ""
  echo "=== Testing Query Lambda ==="
  echo ""

  # Test the query lambda with a simple count query
  PAYLOAD='{"query":"SELECT COUNT(*) as record_count FROM device_telemetry"}'
  ENCODED=$(echo -n "$PAYLOAD" | base64)

  echo "Invoking Query Lambda with payload: $PAYLOAD"
  echo ""

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
  echo "❌ Failed to update workgroup"
  exit 1
fi
