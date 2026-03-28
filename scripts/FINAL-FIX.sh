#!/bin/bash

set -e

echo "========================================================================"
echo "ROBOFLEET QUERY LAMBDA - COMPLETE FIX"
echo "========================================================================"
echo ""

# Step 1: Build the code
echo "Step 1: Building TypeScript code..."
cd /Users/krishna/Desktop/robofleet-lambda-cdk
npm run build
echo "✅ Build successful"
echo ""

# Step 2: Update Query Lambda code directly
echo "Step 2: Updating Query Lambda function code..."
npm run build
cd src
zip -r /tmp/lambda-query.zip functions/query/ -q
cd ..

aws lambda update-function-code \
  --function-name robofleet-query \
  --zip-file fileb:///tmp/lambda-query.zip \
  --region us-east-1 > /dev/null

echo "✅ Lambda code updated"
echo ""

# Step 3: Update IAM policy to allow both workgroups
echo "Step 3: Updating Query Lambda IAM policy..."
aws iam put-role-policy \
  --role-name robofleet-query-lambda-role \
  --policy-name AthenaAndS3Access \
  --policy-document '{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "athena:StartQueryExecution",
          "athena:GetQueryExecution",
          "athena:GetQueryResults",
          "athena:StopQueryExecution",
          "athena:ListQueryExecutions"
        ],
        "Resource": [
          "arn:aws:athena:us-east-1:235695894002:workgroup/robofleet-workgroup",
          "arn:aws:athena:us-east-1:235695894002:workgroup/robofleet-workgroup-v2"
        ]
      },
      {
        "Effect": "Allow",
        "Action": [
          "glue:GetDatabase",
          "glue:GetTable",
          "glue:GetPartitions",
          "glue:GetPartition",
          "glue:BatchGetPartition"
        ],
        "Resource": [
          "arn:aws:glue:us-east-1:235695894002:catalog",
          "arn:aws:glue:us-east-1:235695894002:database/robofleet_db",
          "arn:aws:glue:us-east-1:235695894002:table/robofleet_db/*"
        ]
      },
      {
        "Effect": "Allow",
        "Action": [
          "s3:GetObject",
          "s3:PutObject",
          "s3:GetBucketLocation"
        ],
        "Resource": [
          "arn:aws:s3:::robofleet-data-lake-*/*",
          "arn:aws:s3:::robofleet-athena-results-*/*"
        ]
      },
      {
        "Effect": "Allow",
        "Action": [
          "s3:ListBucket"
        ],
        "Resource": [
          "arn:aws:s3:::robofleet-data-lake-*",
          "arn:aws:s3:::robofleet-athena-results-*"
        ]
      },
      {
        "Effect": "Allow",
        "Action": [
          "kms:Decrypt",
          "kms:DescribeKey"
        ],
        "Resource": [
          "arn:aws:kms:us-east-1:235695894002:key/*"
        ]
      },
      {
        "Effect": "Allow",
        "Action": [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        "Resource": [
          "arn:aws:logs:us-east-1:235695894002:log-group:/aws/lambda/query:*"
        ]
      },
      {
        "Effect": "Allow",
        "Action": [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface"
        ],
        "Resource": ["*"]
      }
    ]
  }'

echo "✅ IAM policy updated"
echo ""

# Step 4: Wait and test
echo "Step 4: Waiting for Lambda to be ready..."
sleep 5

echo ""
echo "========================================================================"
echo "TESTING QUERY LAMBDA"
echo "========================================================================"
echo ""

PAYLOAD='{"query":"SELECT COUNT(*) as record_count FROM device_telemetry"}'
ENCODED=$(echo -n "$PAYLOAD" | base64)

echo "Executing query: SELECT COUNT(*) as record_count FROM device_telemetry"
echo ""

aws lambda invoke \
  --function-name robofleet-query \
  --region us-east-1 \
  --payload "$ENCODED" \
  /tmp/final_response.json

echo ""
echo "Response:"
RESPONSE=$(cat /tmp/final_response.json)
echo "$RESPONSE" | jq '.'

echo ""
echo "========================================================================"

# Check if successful
if echo "$RESPONSE" | jq -e '.statusCode == 200' > /dev/null 2>&1; then
  echo "✅ SUCCESS! Query Lambda is working!"
  echo ""
  BODY=$(echo "$RESPONSE" | jq -r '.body' | jq '.')
  echo "Results:"
  echo "$BODY" | jq '.'
elif echo "$RESPONSE" | jq -e '.statusCode == 400' > /dev/null 2>&1; then
  echo "❌ Query execution failed"
  ERROR=$(echo "$RESPONSE" | jq -r '.body' | jq -r '.message')
  echo "Error: $ERROR"
fi

echo ""
echo "========================================================================"
