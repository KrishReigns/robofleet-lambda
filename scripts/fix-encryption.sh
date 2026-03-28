#!/bin/bash

echo "=== Finding KMS Key for RoboFleet ==="
echo ""

# Get all KMS keys
echo "Available KMS keys:"
aws kms list-keys --region us-east-1 | jq -r '.Keys[] | "\(.KeyId)"'

echo ""
echo "=== KMS Key Aliases ==="
aws kms list-aliases --region us-east-1 | jq '.Aliases[] | select(.AliasName | contains("robofleet")) | {AliasName, TargetKeyId}'

echo ""
echo "=== Updating Workgroup with KMS Encryption ==="
echo ""

# Get the robofleet KMS key
KMS_KEY=$(aws kms list-aliases --region us-east-1 | jq -r '.Aliases[] | select(.AliasName | contains("robofleet")) | .TargetKeyId' | head -1)

if [ -z "$KMS_KEY" ]; then
  echo "❌ Could not find robofleet KMS key"
  echo "Available aliases:"
  aws kms list-aliases --region us-east-1 | jq '.Aliases[].AliasName'
  exit 1
fi

echo "Using KMS Key: $KMS_KEY"
echo ""

# Update workgroup with KMS encryption and ExecutionRole
aws athena update-work-group \
  --work-group robofleet-workgroup \
  --region us-east-1 \
  --configuration-updates "ResultConfigurationUpdates={OutputLocation=s3://robofleet-athena-results-235695894002/query-results/,EncryptionConfiguration={EncryptionOption=SSE_KMS,KmsKey=$KMS_KEY}},ExecutionRole=arn:aws:iam::235695894002:role/AmazonAthenaQueryServiceRole"

if [ $? -eq 0 ]; then
  echo "✅ Workgroup updated with KMS encryption and ExecutionRole"
  echo ""
  echo "=== Verifying Workgroup Configuration ==="
  aws athena get-work-group --work-group robofleet-workgroup --region us-east-1 | jq '.WorkGroup.Configuration'
  echo ""
  echo "=== Testing Query Lambda ==="
  echo ""

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
  echo "❌ Failed to update workgroup"
  exit 1
fi
