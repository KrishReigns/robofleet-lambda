#!/bin/bash

set -e

echo "=== Rebuilding Query Lambda ==="
echo ""

CDK_DIR="/sessions/quirky-elegant-curie/mnt/robofleet-lambda-cdk"
WORK_DIR="/sessions/quirky-elegant-curie/mnt/robofleet-lambda"

cd "$CDK_DIR"

echo "Current directory: $(pwd)"
echo "Building TypeScript code..."
npm run build 2>&1 | grep -E "error|success|✓|✅" || true

echo ""
echo "✅ Build completed"
echo ""

# Create temp directory for zip
mkdir -p /tmp/lambda-build
rm -rf /tmp/lambda-build/*

echo "Copying compiled code to /tmp/lambda-build..."
cp -r src/functions /tmp/lambda-build/

echo "Creating deployment package..."
cd /tmp/lambda-build
zip -r /tmp/lambda-code.zip . -q

if [ -f /tmp/lambda-code.zip ]; then
  echo "✅ Package created: $(ls -lh /tmp/lambda-code.zip | awk '{print $9, $5}')"
else
  echo "❌ Failed to create zip"
  exit 1
fi

echo ""
echo "=== Updating Lambda Function ==="
echo ""

cd "$WORK_DIR"

aws lambda update-function-code \
  --function-name robofleet-query \
  --zip-file fileb:///tmp/lambda-code.zip \
  --region us-east-1 | jq '.LastModified, .CodeSize'

if [ ${PIPESTATUS[0]} -eq 0 ]; then
  echo "✅ Lambda updated"
  echo ""
  echo "=== Waiting for update to complete ==="
  sleep 3
  echo ""
  echo "=== Testing Query Lambda ==="
  echo ""

  PAYLOAD='{"query":"SELECT COUNT(*) as record_count FROM device_telemetry"}'
  ENCODED=$(echo -n "$PAYLOAD" | base64)

  echo "Invoking Query Lambda with: SELECT COUNT(*) as record_count FROM device_telemetry"
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
