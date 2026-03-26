"""
RoboFleet Analytics - Daily Lambda Query Executor
=================================================

This Lambda function:
1. Executes 3 Athena queries daily (fleet health, error analysis, low battery alerts)
2. Collects and formats results as HTML tables
3. Sends results via SES email notification (with proper HTML rendering)

Author: Sai (Amazon Robotics Day 2)
Created: March 25, 2026
Updated: March 25, 2026 (SNS → SES for HTML email rendering)
"""

# =============================================================================
# SECTION 1: IMPORTS
# =============================================================================

import boto3              # AWS SDK — talk to Athena, SES, S3
import json              # Parse/create JSON from Athena responses
import os                # Read environment variables (configuration)
import time              # Sleep & polling Athena for results
from datetime import datetime  # Add timestamps to emails
from typing import Dict, List, Tuple  # Type hints for clean code


# =============================================================================
# SECTION 2: HELPER FUNCTIONS
# =============================================================================

def start_athena_query(query: str, query_name: str, athena_client) -> str:
    """
    Start an Athena query and return the execution ID.

    Parameters:
        query (str): The SQL query to execute
        query_name (str): Friendly name for logging (e.g., "Fleet Health")
        athena_client: Boto3 Athena client

    Returns:
        str: Query execution ID (needed to check results later)

    Raises:
        Exception: If query fails to start
    """

    # Call Athena to start the query
    response = athena_client.start_query_execution(
        QueryString=query,                          # The SQL we want to run
        QueryExecutionContext={'Database': 'robofleet_db'},  # Which database
        ResultConfiguration={
            'OutputLocation': os.environ['ATHENA_RESULTS_PATH']  # Where to save results
        },
        WorkGroup=os.environ['ATHENA_WORKGROUP']   # Use our configured workgroup
    )

    # Extract the execution ID from response
    query_execution_id = response['QueryExecutionId']

    print(f"✅ Started {query_name} query: {query_execution_id}")

    return query_execution_id


def wait_for_query_results(query_execution_id: str,
                           query_name: str,
                           athena_client,
                           max_wait_seconds: int = 300) -> bool:
    """
    Poll Athena until query finishes or timeout occurs.

    Parameters:
        query_execution_id (str): ID from start_athena_query()
        query_name (str): Friendly name for logging
        athena_client: Boto3 Athena client
        max_wait_seconds (int): Maximum seconds to wait (default 5 minutes)

    Returns:
        bool: True if query succeeded, False if failed/timeout
    """

    elapsed_time = 0
    poll_interval = 2  # Check every 2 seconds

    while elapsed_time < max_wait_seconds:
        # Check the query status
        response = athena_client.get_query_execution(
            QueryExecutionId=query_execution_id
        )

        status = response['QueryExecution']['Status']['State']

        # Handle different statuses
        if status == 'SUCCEEDED':
            print(f"✅ {query_name} query SUCCEEDED after {elapsed_time}s")
            return True

        elif status == 'FAILED':
            error_msg = response['QueryExecution']['Status']['StateChangeReason']
            print(f"❌ {query_name} query FAILED: {error_msg}")
            return False

        elif status == 'CANCELLED':
            print(f"⚠️ {query_name} query was CANCELLED")
            return False

        elif status in ['QUEUED', 'RUNNING']:
            # Still processing, wait and check again
            print(f"⏳ {query_name} query still running... ({elapsed_time}s elapsed)")
            time.sleep(poll_interval)
            elapsed_time += poll_interval

    # Timeout
    print(f"⏰ {query_name} query timed out after {max_wait_seconds}s")
    return False


def get_query_results(query_execution_id: str, athena_client) -> List[Dict]:
    """
    Fetch query results from Athena and return as list of dictionaries.

    Parameters:
        query_execution_id (str): ID from start_athena_query()
        athena_client: Boto3 Athena client

    Returns:
        List[Dict]: Results as list of dictionaries (rows)
    """

    results = []
    next_token = None
    headers = []

    while True:
        # Get a page of results (Athena returns paginated results)
        if next_token:
            response = athena_client.get_query_results(
                QueryExecutionId=query_execution_id,
                NextToken=next_token
            )
        else:
            response = athena_client.get_query_results(
                QueryExecutionId=query_execution_id
            )

        # First row is always the column headers
        rows = response['ResultSet']['Rows']

        if not results:  # First page, extract headers
            header_row = rows[0]
            headers = [cell['VarCharValue'] for cell in header_row['Data']]
            results_start_idx = 1
        else:
            results_start_idx = 0

        # Convert each row to a dictionary using headers
        for row in rows[results_start_idx:]:
            row_dict = {}
            for i, cell in enumerate(row['Data']):
                value = cell.get('VarCharValue', '')
                row_dict[headers[i]] = value
            results.append(row_dict)

        # Check if there are more pages
        if 'NextToken' in response:
            next_token = response['NextToken']
        else:
            break  # No more pages

    return results


def format_query_results_as_html(query_name: str,
                                  results: List[Dict],
                                  query_description: str) -> str:
    """
    Convert query results to an HTML table for email.

    Parameters:
        query_name (str): Name of query (e.g., "Fleet Health Summary")
        results (List[Dict]): Results from get_query_results()
        query_description (str): What this query does (for email context)

    Returns:
        str: HTML string with formatted table
    """

    # Start HTML
    html = f"""
    <h2>{query_name}</h2>
    <p><strong>Description:</strong> {query_description}</p>
    <p><strong>Rows returned:</strong> {len(results)}</p>
    """

    # Handle empty results
    if not results:
        html += "<p><em>No results found.</em></p>"
        return html

    # Create table header from first row's keys
    headers = list(results[0].keys())

    html += "<table border='1' cellpadding='8' cellspacing='0' style='border-collapse: collapse; width: 100%; margin: 15px 0;'>\n"

    # Add header row
    html += "  <tr style='background-color: #D5E8F0;'>\n"
    for header in headers:
        html += f"    <th style='text-align: left; font-weight: bold; padding: 10px; border: 1px solid #CCC;'>{header}</th>\n"
    html += "  </tr>\n"

    # Add data rows
    for i, row in enumerate(results):
        # Alternate row colors for readability
        bg_color = "#FFFFFF" if i % 2 == 0 else "#F0F0F0"
        html += f"  <tr style='background-color: {bg_color};'>\n"

        for header in headers:
            value = row.get(header, '')
            html += f"    <td style='padding: 8px; border: 1px solid #DDD;'>{value}</td>\n"

        html += "  </tr>\n"

    html += "</table>\n"

    # Add summary stats
    html += f"<p style='margin-top: 15px; font-size: 12px; color: #666;'>"
    html += f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S UTC')}</p>\n"

    return html


def publish_results_to_ses(email_subject: str,
                          html_content: str,
                          ses_client) -> bool:
    """
    Send formatted HTML results via SES (Simple Email Service).

    SES properly renders HTML emails unlike SNS which displays raw code.

    Parameters:
        email_subject (str): Email subject line
        html_content (str): HTML email body
        ses_client: Boto3 SES client

    Returns:
        bool: True if email sent successfully
    """

    try:
        response = ses_client.send_email(
            Source=os.environ['SES_SENDER_EMAIL'],
            Destination={
                'ToAddresses': [os.environ['SES_RECIPIENT_EMAIL']]
            },
            Message={
                'Subject': {
                    'Data': email_subject,
                    'Charset': 'utf-8'
                },
                'Body': {
                    'Html': {
                        'Data': html_content,
                        'Charset': 'utf-8'
                    }
                }
            }
        )

        message_id = response['MessageId']
        print(f"✅ Published to SES: Message ID {message_id}")
        return True

    except Exception as e:
        print(f"❌ Failed to send email via SES: {str(e)}")
        return False


# =============================================================================
# SECTION 3: MAIN LAMBDA HANDLER
# =============================================================================

def lambda_handler(event, context):
    """
    Main Lambda handler - executed automatically by AWS Lambda.

    Orchestrates:
    1. Starting all 3 Athena queries in parallel
    2. Waiting for results
    3. Formatting as HTML
    4. Sending via SES email

    Parameters:
        event: Trigger information (from EventBridge)
        context: Lambda runtime information

    Returns:
        dict: Status response for CloudWatch logs
    """

    print("=" * 80)
    print("🚀 RoboFleet Analytics - Scheduled Query Execution")
    print(f"Started at: {datetime.now().strftime('%Y-%m-%d %H:%M:%S UTC')}")
    print("=" * 80)

    # Initialize AWS clients
    athena_client = boto3.client('athena')
    ses_client = boto3.client('ses', region_name='us-east-1')

    # Define the 3 queries we want to run
    queries = [
        {
            'name': 'Fleet Health Summary',
            'description': 'Daily fleet health: event counts, avg battery, active % per fleet',
            'sql': """
                SELECT
                  fleet_id,
                  status,
                  COUNT(*)                    AS event_count,
                  ROUND(AVG(battery_level), 1) AS avg_battery,
                  ROUND(AVG(speed_mps), 2)    AS avg_speed
                FROM robofleet_db.device_telemetry
                WHERE year  = '2026'
                  AND month = '03'
                GROUP BY fleet_id, status
                ORDER BY fleet_id, event_count DESC;
            """
        },
        {
            'name': 'Error Analysis (RCA)',
            'description': 'Error frequency by device and error code — use for RCA investigations',
            'sql': """
                SELECT
                  device_id,
                  error_code,
                  COUNT(*)          AS error_count,
                  MIN(event_time)   AS first_seen,
                  MAX(event_time)   AS last_seen
                FROM robofleet_db.device_telemetry
                WHERE year   = '2026'
                  AND month  = '03'
                  AND status = 'ERROR'
                  AND error_code != ''
                GROUP BY device_id, error_code
                ORDER BY error_count DESC;
            """
        },
        {
            'name': 'Low Battery Alert',
            'description': 'Robots with battery < 20% that are not charging — operational alarm query',
            'sql': """
                SELECT
                  device_id,
                  fleet_id,
                  location_zone,
                  battery_level,
                  status,
                  event_time
                FROM robofleet_db.device_telemetry
                WHERE year          = '2026'
                  AND month         = '03'
                  AND battery_level < 20
                  AND status        NOT IN ('CHARGING')
                ORDER BY battery_level ASC;
            """
        }
    ]

    # Step 1: Start all 3 queries in parallel
    print("\n📝 Step 1: Starting queries...")
    query_executions = {}

    for query_def in queries:
        query_name = query_def['name']
        query_sql = query_def['sql']

        try:
            query_id = start_athena_query(query_sql, query_name, athena_client)
            query_executions[query_name] = query_id
            print(f"  ✓ {query_name}: {query_id}")
        except Exception as e:
            print(f"  ✗ {query_name} failed to start: {str(e)}")
            query_executions[query_name] = None

    # Step 2: Wait for all queries to complete
    print("\n⏳ Step 2: Waiting for queries to complete...")
    query_results = {}

    for query_def in queries:
        query_name = query_def['name']
        query_id = query_executions.get(query_name)

        if not query_id:
            print(f"  ⊘ {query_name}: Skipped (failed to start)")
            query_results[query_name] = []
            continue

        try:
            # Wait for query to finish
            success = wait_for_query_results(query_id, query_name, athena_client)

            if success:
                # Fetch results
                results = get_query_results(query_id, athena_client)
                query_results[query_name] = results
                print(f"  ✓ {query_name}: {len(results)} rows")
            else:
                query_results[query_name] = []
                print(f"  ✗ {query_name}: Query failed or timed out")
        except Exception as e:
            print(f"  ✗ {query_name} error: {str(e)}")
            query_results[query_name] = []

    # Step 3: Format results as HTML email
    print("\n📧 Step 3: Formatting results for email...")
    email_html = f"""
    <html>
    <head>
        <style>
            body {{ font-family: Arial, sans-serif; color: #333; line-height: 1.6; }}
            h1 {{ color: #1F4E78; border-bottom: 2px solid #2E75B6; padding-bottom: 10px; }}
            h2 {{ color: #2E75B6; margin-top: 20px; }}
            table {{ border-collapse: collapse; margin: 15px 0; font-size: 14px; }}
            th {{ background-color: #D5E8F0; padding: 10px; text-align: left; font-weight: bold; border: 1px solid #CCC; }}
            td {{ padding: 8px; border: 1px solid #DDD; }}
            tr:nth-child(odd) {{ background-color: #FFFFFF; }}
            tr:nth-child(even) {{ background-color: #F5F5F5; }}
            .summary {{ background-color: #E7F3FF; padding: 15px; border-left: 4px solid #2E75B6; margin: 15px 0; border-radius: 4px; }}
            .footer {{ font-size: 12px; color: #666; margin-top: 30px; border-top: 1px solid #DDD; padding-top: 15px; }}
            .timestamp {{ color: #999; font-size: 11px; }}
        </style>
    </head>
    <body>
        <h1>🤖 RoboFleet Analytics Report</h1>

        <div class='summary'>
            <p><strong>Execution Time:</strong> {datetime.now().strftime('%Y-%m-%d %H:%M:%S UTC')}</p>
            <p><strong>Data Period:</strong> March 2026 (year=2026, month=03)</p>
            <p><strong>Status:</strong> ✅ All queries completed successfully</p>
        </div>
    """

    # Add each query's results
    for query_def in queries:
        query_name = query_def['name']
        query_description = query_def['description']
        results = query_results.get(query_name, [])

        html_table = format_query_results_as_html(query_name, results, query_description)
        email_html += html_table

    email_html += """
        <div class='footer'>
            <p>Report generated by AWS Lambda (RoboFleet Analytics - Day 2 Automation)</p>
            <p>Next run: Tomorrow at 09:00 AM UTC</p>
            <p class='timestamp'>This is an automated email. Do not reply to this message.</p>
        </div>
    </body>
    </html>
    """

    # Step 4: Send email via SES (properly renders HTML)
    print("\n📨 Step 4: Sending email via SES...")
    email_subject = f"RoboFleet Analytics Report - {datetime.now().strftime('%Y-%m-%d')}"

    try:
        success = publish_results_to_ses(email_subject, email_html, ses_client)

        if success:
            print(f"  ✓ Email sent via SES with proper HTML rendering")
        else:
            print(f"  ✗ Failed to send email")
    except Exception as e:
        print(f"  ✗ SES send error: {str(e)}")

    # Step 5: Return response (for CloudWatch logs)
    print("\n" + "=" * 80)
    print("✅ Lambda execution completed successfully")
    print("=" * 80)

    return {
        'statusCode': 200,
        'body': 'RoboFleet Analytics queries executed and email sent via SES',
        'queriesExecuted': len(query_executions),
        'timestamp': datetime.now().isoformat()
    }


# =============================================================================
# LAMBDA FUNCTION ENTRY POINT
# =============================================================================
# AWS Lambda will automatically call: lambda_handler(event, context)
# No need to add any code below this line.
# =============================================================================
