#!/bin/bash

echo "=== Checking KMS Key Policy ==="
echo ""

KMS_KEY="f7a7991c-10b6-4290-a211-ecdcb642c9f7"

echo "KMS Key: $KMS_KEY"
echo ""

aws kms get-key-policy --key-id "$KMS_KEY" --policy-name default --region us-east-1 | jq '.Policy | fromjson'

echo ""
echo "=== Does the policy allow AmazonAthenaQueryServiceRole? ==="
ROLE_ARN="arn:aws:iam::235695894002:role/AmazonAthenaQueryServiceRole"
echo "Looking for: $ROLE_ARN"

aws kms get-key-policy --key-id "$KMS_KEY" --policy-name default --region us-east-1 | jq ".Policy | fromjson | .Statement[] | select(.Principal | tostring | contains(\"$ROLE_ARN\"))"

echo ""
echo "=== All principals allowed by KMS key ==="
aws kms get-key-policy --key-id "$KMS_KEY" --policy-name default --region us-east-1 | jq '.Policy | fromjson | .Statement[] | .Principal'
