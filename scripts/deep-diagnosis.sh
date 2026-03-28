#!/bin/bash

echo "=== Deep Diagnosis ==="
echo ""

echo "1. Full Workgroup JSON (to see if ExecutionRole is elsewhere)..."
aws athena get-work-group --work-group robofleet-workgroup --region us-east-1 | jq '.'
echo ""

echo "2. Query Lambda Role Permissions..."
ROLE_NAME=$(aws lambda get-function-configuration --function-name robofleet-query --region us-east-1 | jq -r '.Role' | awk -F'/' '{print $NF}')
echo "Role: $ROLE_NAME"
aws iam get-role --role-name "$ROLE_NAME" --region us-east-1 | jq '.Role'
echo ""

echo "3. Query Lambda Inline Policies..."
aws iam list-role-policies --role-name "$ROLE_NAME" | jq '.PolicyNames'
echo ""

for policy in $(aws iam list-role-policies --role-name "$ROLE_NAME" | jq -r '.PolicyNames[]'); do
  echo "=== Policy: $policy ==="
  aws iam get-role-policy --role-name "$ROLE_NAME" --policy-name "$policy" | jq '.PolicyDocument'
done
echo ""

echo "4. KMS Key Policy..."
KMS_KEY="f7a7991c-10b6-4290-a211-ecdcb642c9f7"
aws kms get-key-policy --key-id "$KMS_KEY" --policy-name default --region us-east-1 | jq '.Policy | fromjson'
echo ""

echo "5. AmazonAthenaQueryServiceRole Permissions..."
aws iam get-role-policy --role-name AmazonAthenaQueryServiceRole --policy-name AthenaS3Access | jq '.PolicyDocument'
echo ""

echo "6. Checking if Lambda can assume the AmazonAthenaQueryServiceRole..."
echo "Lambda Role ARN: arn:aws:iam::235695894002:role/$ROLE_NAME"
echo "Athena Service Role ARN: arn:aws:iam::235695894002:role/AmazonAthenaQueryServiceRole"
