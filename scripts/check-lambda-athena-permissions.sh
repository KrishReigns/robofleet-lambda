#!/bin/bash

echo "=== Checking Query Lambda Role Athena Permissions ==="
echo ""

ROLE_NAME="robofleet-query-lambda-role"

echo "Role: $ROLE_NAME"
echo ""

echo "Inline policies:"
aws iam list-role-policies --role-name "$ROLE_NAME" --region us-east-1

echo ""
echo "=== Checking each policy for Athena permissions ==="
echo ""

for policy in $(aws iam list-role-policies --role-name "$ROLE_NAME" --region us-east-1 | jq -r '.PolicyNames[]'); do
  echo "Policy: $policy"
  echo "---"
  aws iam get-role-policy --role-name "$ROLE_NAME" --policy-name "$policy" --region us-east-1 | jq '.PolicyDocument | {Version, Statement: [.Statement[] | {Effect, Action, Resource}]}'
  echo ""
done

echo "=== Does the role have athena:StartQueryExecution? ==="
aws iam get-role-policy --role-name "$ROLE_NAME" --policy-name "AthenaAndS3Access" --region us-east-1 | jq '.PolicyDocument' | grep -i "startqueryexecution" || echo "NOT FOUND"
