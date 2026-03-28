#!/usr/bin/env python3
"""
Batch test the RoboFleet Lambda pipeline with sample telemetry data
"""

import json
import sys
import boto3
from datetime import datetime

# AWS clients
lambda_client = boto3.client('lambda', region_name='us-east-1')
s3_client = boto3.client('s3', region_name='us-east-1')
logs_client = boto3.client('logs', region_name='us-east-1')

def test_ingest_lambda(records_batch, batch_name="test-batch"):
    """Test Ingest Lambda with a batch of records"""
    
    print(f"\n{'='*60}")
    print(f"Testing Ingest Lambda: {batch_name}")
    print(f"Records in batch: {len(records_batch)}")
    print(f"{'='*60}\n")
    
    # Create SQS-like event structure
    event = {
        "Records": [
            {
                "body": json.dumps(record)
            }
            for record in records_batch
        ]
    }
    
    try:
        # Invoke Lambda
        response = lambda_client.invoke(
            FunctionName='robofleet-ingest',
            InvocationType='RequestResponse',
            LogType='Tail',
            Payload=json.dumps(event)
        )
        
        # Parse response
        status_code = response['StatusCode']
        logs = response.get('LogResult', '')
        
        print(f"✅ Lambda Response Status: {status_code}")
        print(f"   Request ID: {response['ResponseMetadata']['RequestId']}")
        
        # Try to parse response body
        if 'Payload' in response:
            payload = json.loads(response['Payload'].read())
            print(f"   Response Body: {json.dumps(payload, indent=2)}")
        
        return True
        
    except Exception as e:
        print(f"❌ Error invoking Lambda: {e}")
        return False

def check_s3_data(bucket="robofleet-data-lake"):
    """Check if data was written to S3"""
    
    print(f"\n{'='*60}")
    print(f"Checking S3 Data Lake: {bucket}")
    print(f"{'='*60}\n")
    
    try:
        response = s3_client.list_objects_v2(
            Bucket=bucket,
            Prefix='year=2026',
            MaxKeys=20
        )
        
        if 'Contents' in response:
            print(f"✅ Found {len(response['Contents'])} objects in S3:")
            for obj in response['Contents'][:10]:
                size_kb = obj['Size'] / 1024
                print(f"   • {obj['Key']} ({size_kb:.1f} KB)")
            
            if len(response['Contents']) > 10:
                print(f"   ... and {len(response['Contents']) - 10} more")
        else:
            print(f"⚠️  No data found in S3 yet (may take a moment)")
        
        return True
        
    except Exception as e:
        print(f"❌ Error checking S3: {e}")
        return False

def main():
    # Load sample data
    try:
        with open('sample_telemetry.jsonl', 'r') as f:
            records = [json.loads(line) for line in f]
    except FileNotFoundError:
        print("❌ sample_telemetry.jsonl not found. Run: python3 generate_sample_telemetry.py")
        sys.exit(1)
    
    print(f"Loaded {len(records)} sample telemetry records")
    
    # Test 1: Small batch (5 records)
    print("\n" + "█" * 60)
    print("TEST 1: Small Batch (5 records)")
    print("█" * 60)
    test_ingest_lambda(records[:5], "small-batch-5-records")
    
    # Test 2: Medium batch (50 records)
    print("\n" + "█" * 60)
    print("TEST 2: Medium Batch (50 records)")
    print("█" * 60)
    test_ingest_lambda(records[5:55], "medium-batch-50-records")
    
    # Test 3: Large batch (all records)
    print("\n" + "█" * 60)
    print("TEST 3: Large Batch (all 500 records)")
    print("█" * 60)
    test_ingest_lambda(records[55:], "large-batch-remaining-records")
    
    # Check S3 after all invocations
    print("\n" + "█" * 60)
    print("VERIFICATION: Checking S3")
    print("█" * 60)
    check_s3_data()
    
    print("\n" + "=" * 60)
    print("✅ All tests completed!")
    print("=" * 60)
    print("\nNext steps:")
    print("  1. Verify data in S3:")
    print("     aws s3 ls s3://robofleet-data-lake/year=2026/ --recursive")
    print("\n  2. Check CloudWatch Logs:")
    print("     aws logs tail /aws/lambda/robofleet-ingest --follow")
    print("\n  3. Test Query Lambda:")
    print("     python3 test_lambda_query.py")

if __name__ == "__main__":
    main()
