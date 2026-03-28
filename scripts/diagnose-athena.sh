#!/bin/bash

echo "=== Diagnosing Athena Configuration ==="
echo ""

# Check if the results bucket exists
echo "1. Checking if results bucket exists..."
aws s3 ls s3://robofleet-athena-results-235695894002/ --region us-east-1 2>&1
echo ""

# Get workgroup details
echo "2. Current Workgroup Configuration..."
aws athena get-work-group --work-group robofleet-workgroup --region us-east-1 | jq '.WorkGroup.Configuration'
echo ""

# Check Athena service role
echo "3. Looking for AmazonAthenaQueryServiceRole..."
aws iam get-role --role-name AmazonAthenaQueryServiceRole 2>&1 | head -20
echo ""

# Check the role's S3 permissions
echo "4. Checking S3 permissions for AmazonAthenaQueryServiceRole..."
aws iam list-role-policies --role-name AmazonAthenaQueryServiceRole --region us-east-1 2>&1
echo ""

# Get inline policy details
echo "5. Policy details..."
aws iam get-role-policy --role-name AmazonAthenaQueryServiceRole --policy-name athena-s3-access 2>&1 | jq '.PolicyDocument'
echo ""

# Check Query Lambda's role
echo "6. Query Lambda execution role..."
aws lambda get-function-configuration --function-name robofleet-query --region us-east-1 | jq '.Role'
echo ""

# Check Query Lambda role's S3 permissions
echo "7. Query Lambda role S3 permissions..."
ROLE_NAME=$(aws lambda get-function-configuration --function-name robofleet-query --region us-east-1 | jq -r '.Role' | awk -F'/' '{print $NF}')
echo "Role name: $ROLE_NAME"
aws iam list-role-policies --role-name "$ROLE_NAME" --region us-east-1
