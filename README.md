# RoboFleet Analytics Lambda Workshop

**3-Day AWS Lambda Implementation for Amazon Robotics**

## Executive Summary

This project demonstrates a complete **3-day AWS Lambda workshop** implementing a production-grade serverless analytics platform for RoboFleet device telemetry. The implementation covers infrastructure-as-code (Terraform), Lambda development, CloudWatch monitoring, automated testing, and CI/CD automation.

**GitHub Repository:** https://github.com/KrishReigns/robofleet-lambda

---

## Project Structure at a Glance

| Component | Description |
|-----------|-------------|
| **Day 1: Infrastructure** | Terraform configuration for AWS resources (S3, Athena, Glue, CloudWatch, SNS, IAM) |
| **Day 2: Lambda Functions** | Two Lambda functions: Athena query executor + SNS-to-Slack bridge |
| **Day 3: Testing & CI/CD** | Pytest unit tests (10 test cases, 100% passing) + GitHub Actions workflow |

---

## Architecture Overview

### System Flow & Data Pipeline

The RoboFleet Analytics platform follows an **event-driven serverless architecture**:

```
┌─────────────────────────────────────────────────────────────┐
│                    RoboFleet Analytics Pipeline             │
└─────────────────────────────────────────────────────────────┘

1. DATA INGESTION
   └─> Raw CSV telemetry files → S3 Data Lake (partitioned by year/month/day)

2. METADATA CATALOG
   └─> AWS Glue Data Catalog defines schema for Athena

3. QUERY EXECUTION (Lambda)
   └─> EventBridge (scheduled) → Lambda → Athena Queries (3 parallel)
       • Fleet Health Summary
       • Error Analysis (RCA)
       • Low Battery Alert

4. RESULTS PROCESSING
   └─> Lambda formats results as HTML → AWS SES → Email delivery

5. MONITORING & ALERTS
   └─> CloudWatch Metrics → CloudWatch Alarms → SNS Topic

6. SLACK INTEGRATION
   └─> SNS Message → Lambda SNS-to-Slack → Slack Webhook
```

---

## Day 1: Infrastructure as Code (Terraform)

### AWS Resources Provisioned

#### Storage Layer (S3)
- **Data Lake Bucket**: Stores raw CSV telemetry files with year/month/day partitioning
- **Query Results Bucket**: Stores Athena query outputs (auto-expires after 30 days)
- **Security**: Server-side encryption (AES256), versioning, public access blocked, lifecycle policies

#### Analytics Layer (Athena & Glue)
- **Glue Database**: `robofleet_db` with `device_telemetry` external table
  - Columns: device_id, fleet_id, event_time, battery_level, speed_mps, status, error_code, location_zone, temperature_celsius
  - Partitions: year, month, day (extracted from S3 folder paths)

- **Athena Workgroup**: `robofleet-workgroup` with cost guardrails
  - Max 1GB per query scan (prevents expensive runaway scans)
  - Enforces configuration across all queries
  - Publishes CloudWatch metrics

- **Named Queries** (pre-built for team access):
  - Fleet Health Summary: Event counts, avg battery, active % per fleet
  - Error Analysis RCA: Error frequency by device and error code
  - Low Battery Alert: Robots <20% battery not charging

#### Monitoring Layer (CloudWatch)

**Three CloudWatch Alarms:**

| Alarm | Trigger | Purpose |
|-------|---------|---------|
| **Data Scanned** | Query > 100MB | Cost guardrail (prevent expensive scans) |
| **Query Failures** | Failed query execution | Data quality check (schema changes, corrupt files) |
| **S3 Put Errors** | 5+ write errors | Ingestion health (upstream pipeline failures) |

**CloudWatch Dashboard**: Visual overview with metrics for:
- Athena bytes scanned (max & avg per query)
- Athena execution time (total & engine time)
- Active alarm status

**SNS Topic**: `robofleet-alerts` receives all alarm notifications

#### Security & IAM

- **Lambda Execution Role**: `robofleet-athena-execution-role`
- **Least-Privilege Permissions**:
  - Athena: StartQueryExecution, GetQueryExecution, GetQueryResults, etc.
  - Glue Catalog: GetDatabase, GetTable, GetPartitions (read-only)
  - S3: Read from data lake, write to results bucket
  - CloudWatch Logs: Create log groups/streams and write events

---

## Day 2: Lambda Functions & CloudWatch Integration

### Lambda Function 1: Athena Query Executor

**File**: `lambda_robofleet_queries.py` (494 lines)

**Functionality**:
- Executes **3 daily Athena queries in parallel**
  1. **Fleet Health**: Event counts, battery levels, speed metrics per fleet
  2. **Error Analysis**: Error frequency by device and code for RCA
  3. **Low Battery Alert**: Robots with <20% battery not charging (operational alarm)
- Formats results as **HTML tables with CSS styling** (alternating row colors, blue headers)
- Sends formatted email via **AWS SES** (Simple Email Service)

**Key Features**:
- ✅ Asynchronous polling: Checks query status every 2 seconds (max 5-minute timeout)
- ✅ Error handling: Graceful fallback if queries fail
- ✅ Pagination support: Handles paginated Athena results
- ✅ CloudWatch Logs: Detailed execution logs with timestamps and status indicators

**Example HTML Output**:
```html
<h2>Fleet Health Summary</h2>
<p><strong>Description:</strong> Daily fleet health: event counts, avg battery, active % per fleet</p>
<table border='1' style='border-collapse: collapse;'>
  <tr style='background-color: #D5E8F0;'>
    <th>fleet_id</th>
    <th>status</th>
    <th>event_count</th>
    <th>avg_battery</th>
    <th>avg_speed</th>
  </tr>
  <tr style='background-color: #FFFFFF;'>
    <td>FLEET-BOSTON-01</td>
    <td>ACTIVE</td>
    <td>450</td>
    <td>75.5</td>
    <td>1.23</td>
  </tr>
  <!-- more rows... -->
</table>
```

### Lambda Function 2: SNS-to-Slack Bridge

**File**: `lambda_function.py` (29 lines)

**Functionality**:
- Triggered by **SNS topic subscriptions** (from CloudWatch alarms)
- Transforms SNS alarm messages to Slack message format
- **Color codes**: Red (#FF0000) for ALARM state, Green (#00FF00) for OK state
- Posts to **Slack webhook URL** (stored in Lambda environment variable)

**Example Slack Message**:
```json
{
  "attachments": [{
    "color": "#FF0000",
    "title": "🚨 RoboFleet-Athena-HighDataScan",
    "text": "Athena query scanned 150MB — exceeds 100MB threshold",
    "fields": [{"title": "State", "value": "ALARM", "short": true}]
  }]
}
```

### Environment Variables (Both Functions)

Both Lambda functions require these environment variables:
- `ATHENA_RESULTS_PATH`: S3 path for query results
- `ATHENA_WORKGROUP`: Name of Athena workgroup
- `SES_SENDER_EMAIL`: Email address to send from
- `SES_RECIPIENT_EMAIL`: Email address to receive results
- `SLACK_WEBHOOK_URL`: Slack incoming webhook URL

---

## Day 3: Testing, Monitoring & CI/CD

### Unit Testing with Pytest

**File**: `test_lambda.py` (172 lines, 10 test cases)

| Test Case | Validates |
|-----------|-----------|
| Empty Results | Handles empty query results correctly |
| Single Result | Formats single data row |
| Multiple Results | Handles multiple rows |
| HTML Table Structure | Valid HTML markup (table, tr, td, th tags) |
| CSS Styling | Proper formatting (colors, padding, borders) |
| Alternating Colors | Row background colors (#FFFFFF, #F0F0F0) |
| Query Name | Query name included in output |
| Query Description | Query description included |
| Row Count Accuracy | Correct count in HTML |
| Special Characters | Handles special characters (& < >) |

**Test Results**: ✅ **10/10 tests passing**

**Run Locally**:
```bash
pip install pytest boto3 urllib3
python -m pytest test_lambda.py -v
```

### CI/CD Pipeline (GitHub Actions)

**Workflow File**: `.github/workflows/deploy.yml`

**Trigger**: Automatic on push to `main` branch

#### Job 1: Test
```yaml
- Checkout code from GitHub
- Setup Python 3.11
- Install dependencies: pytest, boto3, urllib3
- Run: python -m pytest test_lambda.py -v
```

#### Job 2: Deploy (depends on Test passing)
```yaml
- Checkout code
- Create lambda.zip with both Python files
- Deploy via AWS CLI:
  aws lambda update-function-code \
    --function-name robofleet-analytics-queries \
    --zip-file fileb://lambda.zip
- Authentication: AWS credentials from GitHub repository secrets
```

---

## Repository Structure

```
robofleet-lambda/
├── terraform/                         # Day 1: Infrastructure code
│   ├── providers.tf                   # AWS provider configuration
│   ├── s3.tf                          # S3 buckets (data lake, results)
│   ├── athena.tf                      # Athena workgroup, named queries
│   ├── cloudwatch.tf                  # Monitoring dashboard, alarms
│   ├── glue.tf                        # Glue database, table catalog
│   ├── iam.tf                         # Lambda execution role, policies
│   ├── locals.tf                      # Local variables (bucket names, etc.)
│   ├── variables.tf                   # Terraform input variables
│   ├── outputs.tf                     # Terraform outputs
│   └── terraform.lock.hcl             # Dependency lock file
│
├── sample-data/                       # Day 1: Test telemetry data
│   └── year=2026/month=03/day={20,21,22}/
│       └── telemetry_001.csv          # Sample CSV files
│
├── .github/workflows/                 # Day 3: CI/CD automation
│   └── deploy.yml                     # GitHub Actions workflow
│
├── lambda_robofleet_queries.py        # Day 2: Main query executor (494 lines)
├── lambda_function.py                 # Day 2: SNS-to-Slack bridge (29 lines)
├── test_lambda.py                     # Day 3: Unit tests (172 lines)
├── .gitignore                         # Git exclusions
└── README.md                          # This file
```

---

## How to Deploy and Use

### Prerequisites

- AWS Account with appropriate IAM permissions
- Terraform installed (v1.3.0+)
- Python 3.11+
- Git and GitHub account
- AWS credentials configured locally (`aws configure`)

### Deployment Steps

1. **Clone the repository**:
   ```bash
   git clone https://github.com/KrishReigns/robofleet-lambda.git
   cd robofleet-lambda
   ```

2. **Initialize Terraform**:
   ```bash
   cd terraform
   terraform init
   ```

3. **Preview changes**:
   ```bash
   terraform plan
   ```

4. **Apply infrastructure**:
   ```bash
   terraform apply
   ```

5. **Configure Lambda environment variables** (via AWS Console or Terraform):
   - `ATHENA_RESULTS_PATH`
   - `ATHENA_WORKGROUP`
   - `SES_SENDER_EMAIL`
   - `SES_RECIPIENT_EMAIL`
   - `SLACK_WEBHOOK_URL`

6. **Push to GitHub** to trigger automated CI/CD:
   ```bash
   git push origin main
   ```

### Running Tests Locally

```bash
cd robofleet-lambda
pip install pytest boto3 urllib3
python -m pytest test_lambda.py -v
```

### Manual Lambda Execution

```bash
aws lambda invoke \
  --function-name robofleet-analytics-queries \
  --payload '{}' \
  response.json

cat response.json
```

---

## Key Technical Learnings

✅ **Serverless Architecture Patterns**: Event-driven Lambda functions with AWS managed services

✅ **Infrastructure-as-Code**: Terraform for reproducible, version-controlled AWS deployments

✅ **Analytics with Athena**: Querying S3 data without maintaining data warehouse infrastructure

✅ **CloudWatch Monitoring**: Custom dashboards and alarms for operational insights

✅ **Least-Privilege IAM**: Security best practices for Lambda execution roles

✅ **CI/CD Automation**: GitHub Actions for automated testing and deployment

✅ **Testing Strategies**: Unit testing for Lambda functions with pytest

✅ **Integration Patterns**: SNS, Lambda, and webhook integration for multi-service workflows

✅ **Observability**: CloudWatch Logs with detailed execution traces

✅ **Cost Optimization**: Athena workgroup guardrails and S3 lifecycle policies

---

## Verification & Status

### ✅ Completed Items

- ✅ Infrastructure: All Terraform files in `terraform/` directory
- ✅ Lambda Functions: Both `lambda_robofleet_queries.py` and `lambda_function.py` deployed
- ✅ Testing: 10/10 unit tests passing
- ✅ CI/CD: GitHub Actions workflow configured and triggered on push
- ✅ Repository: Complete monorepo with Days 1-3 code together
- ✅ Documentation: Comprehensive README with architecture and implementation details

### AWS Resources Deployed

- ✅ S3: Data lake and query results buckets
- ✅ Glue: robofleet_db database with device_telemetry table
- ✅ Athena: robofleet-workgroup with 3 named queries
- ✅ CloudWatch: Dashboard with 3 alarms (cost, quality, ingestion)
- ✅ SNS: robofleet-alerts topic
- ✅ IAM: robofleet-athena-execution-role with least-privilege policies
- ✅ Lambda: robofleet-analytics-queries function deployed

---

## About This Implementation

This 3-day workshop demonstrates **production-grade cloud engineering practices** for serverless analytics. The project combines:

- Infrastructure automation (Terraform)
- Serverless compute (AWS Lambda)
- Data analytics (Athena + Glue)
- Monitoring & observability (CloudWatch)
- DevOps best practices (GitHub Actions CI/CD)
- Testing & quality assurance (pytest)

Developed as a hands-on learning experience to prepare for **Amazon Robotics Cloud Developer** roles.

---

## Contact & Resources

**GitHub Repository**: https://github.com/KrishReigns/robofleet-lambda

**AWS Account ID**: 235695894002

**Author**: Sai (Krishna)

**Email**: krishna1996sai@gmail.com

---

**Last Updated**: March 26, 2026

**Status**: ✅ Complete and Production-Ready
