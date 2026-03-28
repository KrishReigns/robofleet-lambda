#!/bin/bash

echo "=== Creating Proper Athena Service Role ==="
echo ""

# Check if role already exists
if aws iam get-role --role-name robofleet-athena-service-role --region us-east-1 2>&1 | grep -q "NoSuchEntity"; then
  echo "Creating robofleet-athena-service-role..."

  aws iam create-role \
    --role-name robofleet-athena-service-role \
    --assume-role-policy-document '{
      "Version": "2012-10-17",
      "Statement": [
        {
          "Effect": "Allow",
          "Principal": {
            "Service": "athena.amazonaws.com"
          },
          "Action": "sts:AssumeRole"
        }
      ]
    }' \
    --region us-east-1

  echo "✅ Role created"
else
  echo "Role robofleet-athena-service-role already exists"
fi

echo ""
echo "=== Adding S3 and KMS Permissions to Role ==="

# Attach inline policy with S3 and KMS permissions
aws iam put-role-policy \
  --role-name robofleet-athena-service-role \
  --policy-name AthenaExecutionPolicy \
  --region us-east-1 \
  --policy-document '{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ],
        "Resource": [
          "arn:aws:s3:::robofleet-*",
          "arn:aws:s3:::robofleet-*/*"
        ]
      },
      {
        "Effect": "Allow",
        "Action": [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:Encrypt",
          "kms:GenerateDataKey*",
          "kms:ReEncrypt*"
        ],
        "Resource": "*"
      }
    ]
  }'

if [ $? -eq 0 ]; then
  echo "✅ Policy attached"
else
  echo "❌ Failed to attach policy"
  exit 1
fi

echo ""
echo "=== Updating Workgroup with ExecutionRole ==="

ROLE_ARN="arn:aws:iam::235695894002:role/robofleet-athena-service-role"

aws athena update-work-group \
  --work-group robofleet-workgroup \
  --region us-east-1 \
  --configuration-updates "ExecutionRole=$ROLE_ARN"

if [ $? -eq 0 ]; then
  echo "✅ Workgroup updated"
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
  cat /tmp/query_response.json | jq '.'

else
  echo "❌ Failed to update workgroup"
  exit 1
fi
