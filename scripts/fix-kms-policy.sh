#!/bin/bash

echo "=== Fixing KMS Key Policy for Athena ==="
echo ""

KMS_KEY="f7a7991c-10b6-4290-a211-ecdcb642c9f7"
ROLE_ARN="arn:aws:iam::235695894002:role/AmazonAthenaQueryServiceRole"

echo "Adding AmazonAthenaQueryServiceRole to KMS key policy..."
echo ""

# Create the new policy with Athena role included
aws kms put-key-policy \
  --key-id "$KMS_KEY" \
  --policy-name default \
  --region us-east-1 \
  --policy '{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "AWS": "arn:aws:iam::235695894002:root"
        },
        "Action": "kms:*",
        "Resource": "*"
      },
      {
        "Effect": "Allow",
        "Principal": {
          "AWS": "arn:aws:iam::235695894002:root"
        },
        "Action": [
          "kms:CreateGrant",
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:Encrypt",
          "kms:GenerateDataKey*",
          "kms:ReEncrypt*"
        ],
        "Resource": "*",
        "Condition": {
          "StringEquals": {
            "kms:ViaService": "secretsmanager.us-east-1.amazonaws.com"
          }
        }
      },
      {
        "Effect": "Allow",
        "Principal": {
          "AWS": "'$ROLE_ARN'"
        },
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
  echo "✅ KMS policy updated successfully"
  echo ""
  echo "=== Verifying New Policy ==="
  aws kms get-key-policy --key-id "$KMS_KEY" --policy-name default --region us-east-1 | jq '.Policy | fromjson'
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
  echo "❌ Failed to update KMS policy"
  exit 1
fi
