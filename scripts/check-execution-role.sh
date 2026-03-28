#!/bin/bash

echo "=== Checking Athena Workgroup ExecutionRole ==="
echo ""

# Get full workgroup configuration including ExecutionRole
aws athena get-work-group --work-group robofleet-workgroup --region us-east-1 | jq '.WorkGroup'
echo ""

echo "=== Checking AmazonAthenaQueryServiceRole policy ==="
aws iam get-role-policy --role-name AmazonAthenaQueryServiceRole --policy-name AthenaS3Access --region us-east-1 | jq '.PolicyDocument'
