#!/bin/bash

echo "=== Getting CloudWatch Logs for Query Lambda ==="
echo ""

# Get the last 50 log events from the query lambda log group
aws logs tail /aws/lambda/query --follow=false --format=short --region us-east-1 --max-items 50

echo ""
echo "=== Full Lambda invocation details from last 5 minutes ==="
aws logs filter-log-events \
  --log-group-name /aws/lambda/query \
  --start-time $(($(date +%s000) - 300000)) \
  --region us-east-1 \
  | jq '.events[] | {timestamp: .timestamp, message: .message}'
