#!/bin/bash

echo "=== Rebuilding Query Lambda ==="
echo ""

# Navigate to the CDK folder
cd /sessions/quirky-elegant-curie/mnt/robofleet-lambda-cdk || exit 1

echo "Building TypeScript code..."
npm run build 2>&1 | tail -20

if [ $? -ne 0 ]; then
  echo "❌ Build failed"
  exit 1
fi

echo ""
echo "✅ Build succeeded"
echo ""

# Zip the compiled code
echo "Creating deployment package..."
cd src || exit 1

# Remove old zip if it exists
rm -f /tmp/lambda-code.zip

# Zip the source and compiled code
zip -r /tmp/lambda-code.zip . -x "*.ts" "node_modules/*" 2>&1 | tail -10

if [ $? -ne 0 ]; then
  echo "❌ Zip failed"
  exit 1
fi

echo "✅ Zip created"
echo ""

echo "=== Updating Lambda Function ==="
echo ""

cd /sessions/quirky-elegant-curie/mnt/robofleet-lambda || exit 1

aws lambda update-function-code \
  --function-name robofleet-query \
  --zip-file fileb:///tmp/lambda-code.zip \
  --region us-east-1

if [ $? -eq 0 ]; then
  echo "✅ Lambda updated"
  echo ""
  echo "=== Testing Query Lambda ==="
  echo ""

  # Wait for update to complete
  sleep 2

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
  cat /tmp/query_response.json | jq '.'

else
  echo "❌ Lambda update failed"
  exit 1
fi
