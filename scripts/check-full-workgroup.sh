#!/bin/bash

echo "=== Full Workgroup JSON (all fields) ==="
echo ""

aws athena get-work-group --work-group robofleet-workgroup --region us-east-1 | jq '.WorkGroup'

echo ""
echo "=== Looking specifically for ExecutionRole field ==="
aws athena get-work-group --work-group robofleet-workgroup --region us-east-1 | jq '.WorkGroup | keys'

echo ""
echo "=== Searching for any 'ExecutionRole' mention ==="
aws athena get-work-group --work-group robofleet-workgroup --region us-east-1 | jq '. | tostring | contains("ExecutionRole")'
