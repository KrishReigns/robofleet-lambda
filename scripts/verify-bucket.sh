#!/bin/bash

echo "=== Verifying Athena Results Bucket ==="
echo ""

echo "1. Checking if bucket exists..."
aws s3 ls s3://robofleet-athena-results-235695894002/ --region us-east-1 2>&1
echo ""

echo "2. Checking bucket versioning and ACL..."
aws s3api head-bucket --bucket robofleet-athena-results-235695894002 --region us-east-1
echo ""

echo "3. Listing all buckets to verify it's there..."
aws s3 ls | grep athena
echo ""

echo "4. Getting bucket policy..."
aws s3api get-bucket-policy --bucket robofleet-athena-results-235695894002 --region us-east-1 2>&1
echo ""

echo "5. Getting workgroup full details including ExecutionRole..."
aws athena get-work-group --work-group robofleet-workgroup --region us-east-1 | jq '.'
