#!/usr/bin/env python3
"""
Test the RoboFleet Query Lambda (Athena queries on ingested data)
"""

import json
import boto3
import time
import sys

athena_client = boto3.client('athena', region_name='us-east-1')

# Pre-defined queries matching your analytics report
QUERIES = {
    "fleet_health": """
        SELECT 
            fleet_id,
            status,
            COUNT(*) as event_count,
            CAST(AVG(battery_level) AS DECIMAL(5,2)) as avg_battery,
            CAST(AVG(speed) AS DECIMAL(5,2)) as avg_speed
        FROM robofleet_telemetry
        WHERE year = 2026 AND month = 3
        GROUP BY fleet_id, status
        ORDER BY fleet_id, status
    """,
    
    "error_analysis": """
        SELECT 
            device_id,
            error_code,
            COUNT(*) as error_count,
            MIN(timestamp) as first_seen,
            MAX(timestamp) as last_seen
        FROM robofleet_telemetry
        WHERE year = 2026 AND month = 3 AND status = 'ERROR'
        GROUP BY device_id, error_code
        ORDER BY error_count DESC
    """,
    
    "low_battery_alert": """
        SELECT 
            device_id,
            fleet_id,
            location_zone,
            battery_level,
            status,
            timestamp as event_time
        FROM robofleet_telemetry
        WHERE year = 2026 AND month = 3 
            AND battery_level < 20 
            AND status != 'CHARGING'
        ORDER BY timestamp DESC
    """,
    
    "device_summary": """
        SELECT 
            device_id,
            fleet_id,
            COUNT(*) as total_events,
            SUM(CASE WHEN status = 'ERROR' THEN 1 ELSE 0 END) as error_count,
            CAST(AVG(battery_level) AS DECIMAL(5,2)) as avg_battery,
            CAST(AVG(speed) AS DECIMAL(5,2)) as avg_speed,
            MIN(timestamp) as first_event,
            MAX(timestamp) as last_event
        FROM robofleet_telemetry
        WHERE year = 2026 AND month = 3
        GROUP BY device_id, fleet_id
        ORDER BY device_id
    """
}

def execute_query(query_name, query_string):
    """Execute Athena query and wait for results"""
    
    print(f"\n{'─'*60}")
    print(f"Query: {query_name}")
    print(f"{'─'*60}\n")
    
    try:
        # Start query execution
        response = athena_client.start_query_execution(
            QueryString=query_string,
            QueryExecutionContext={'Database': 'robofleet'},
            ResultConfiguration={'OutputLocation': 's3://robofleet-athena-results/'},
            WorkGroup='primary'
        )
        
        query_execution_id = response['QueryExecutionId']
        print(f"Query started: {query_execution_id}")
        
        # Poll for completion
        max_attempts = 30
        attempt = 0
        
        while attempt < max_attempts:
            execution = athena_client.get_query_execution(QueryExecutionId=query_execution_id)
            status = execution['QueryExecution']['Status']['State']
            
            if status == 'SUCCEEDED':
                print(f"✅ Query completed in {execution['QueryExecution']['Statistics']['EngineExecutionTimeInMillis']}ms")
                
                # Get results
                results = athena_client.get_query_results(QueryExecutionId=query_execution_id)
                rows = results['ResultSet']['Rows']
                
                print(f"\nResults ({len(rows)-1} data rows):\n")
                
                # Print header
                headers = [col['VarCharValue'] for col in rows[0]['Data']]
                print("  " + " | ".join(f"{h:20}" for h in headers[:5]))
                print("  " + "─" * 100)
                
                # Print data rows (limit to 10)
                for row in rows[1:11]:
                    cols = [cell.get('VarCharValue', 'NULL')[:20] for cell in row['Data'][:5]]
                    print("  " + " | ".join(f"{c:20}" for c in cols))
                
                if len(rows) > 11:
                    print(f"\n  ... and {len(rows)-11} more rows")
                
                return True
                
            elif status == 'FAILED':
                reason = execution['QueryExecution']['Status'].get('StateChangeReason', 'Unknown')
                print(f"❌ Query failed: {reason}")
                return False
            
            attempt += 1
            if attempt < max_attempts:
                print(f"⏳ Waiting... ({status})")
                time.sleep(2)
        
        print(f"❌ Query timeout after {max_attempts*2} seconds")
        return False
        
    except Exception as e:
        print(f"❌ Error: {e}")
        return False

def main():
    print("="*60)
    print("Testing RoboFleet Query Lambda (Athena)")
    print("="*60)
    
    results = {}
    
    for query_name, query_string in QUERIES.items():
        success = execute_query(query_name, query_string)
        results[query_name] = "✅" if success else "❌"
        time.sleep(1)  # Rate limiting
    
    # Summary
    print("\n" + "="*60)
    print("Query Summary")
    print("="*60)
    for query_name, status in results.items():
        print(f"{status} {query_name}")
    
    print("\n✅ Query testing completed!")

if __name__ == "__main__":
    main()
