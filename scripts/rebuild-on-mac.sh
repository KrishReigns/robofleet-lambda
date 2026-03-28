#!/bin/bash

echo "=== Finding your project folders ==="
echo ""

echo "Current directory: $(pwd)"
echo ""

# Check if we're already in the CDK folder
if [ -d "lib/stacks" ]; then
  CDK_DIR="$(pwd)"
  WORK_DIR="$(pwd)"
  echo "✅ Found CDK folder: $CDK_DIR"
else
  # Try to find it
  echo "Looking for CDK folder..."
  CDK_DIR=$(find ~ -maxdepth 3 -type d -name "robofleet-lambda-cdk" 2>/dev/null | head -1)

  if [ -z "$CDK_DIR" ]; then
    echo "❌ Could not find robofleet-lambda-cdk folder"
    echo ""
    echo "Please do one of the following:"
    echo "1. Run this script from the robofleet-lambda-cdk directory"
    echo "2. Or tell me the path to your robofleet-lambda-cdk folder"
    exit 1
  fi

  WORK_DIR=$(pwd)
  echo "✅ Found CDK folder: $CDK_DIR"
fi

echo ""
echo "=== Building TypeScript ==="
echo ""

cd "$CDK_DIR"
npm run build

if [ $? -ne 0 ]; then
  echo "❌ Build failed"
  exit 1
fi

echo ""
echo "✅ Build succeeded"
echo ""

# Create temp directory for zip
echo "=== Creating Lambda deployment package ==="
echo ""

TEMP_BUILD=$(mktemp -d)
echo "Using temp directory: $TEMP_BUILD"

# Copy the query function
mkdir -p "$TEMP_BUILD/functions/query"
cp -r src/functions/query/* "$TEMP_BUILD/functions/query/"

echo "Creating zip file..."
cd "$TEMP_BUILD"
zip -r /tmp/lambda-code.zip . -q

if [ -f /tmp/lambda-code.zip ]; then
  SIZE=$(ls -lh /tmp/lambda-code.zip | awk '{print $5}')
  echo "✅ Package created: /tmp/lambda-code.zip ($SIZE)"
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
  --region us-east-1

if [ $? -eq 0 ]; then
  echo ""
  echo "✅ Lambda updated successfully"
  echo ""
  echo "Waiting 3 seconds for update to propagate..."
  sleep 3

  echo ""
  echo "=== Testing Query Lambda ==="
  echo ""

  PAYLOAD='{"query":"SELECT COUNT(*) as record_count FROM device_telemetry"}'
  ENCODED=$(echo -n "$PAYLOAD" | base64)

  echo "Invoking robofleet-query..."
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

# Cleanup
rm -rf "$TEMP_BUILD"
