# stream-watch

> Real-time F1 telemetry ingestion and analytics pipeline on AWS — provisioned entirely with Terraform.

---

## What it does

stream-watch replays historical F1 race telemetry (speed, throttle, brake, DRS, GPS position) as a live data stream into AWS, processes it serverlessly, stores it in a partitioned data lake, and runs SQL analytics on it — all without managing a single server.

---

## Architecture

![stream-watch pipeline](docs/architecture.png)

## AWS services used

| Service | Role |
|---|---|
| SQS | Telemetry ingestion buffer (+ DLQ for failed messages) |
| Lambda | Serverless stream processing (arm64 / Graviton2) |
| S3 | Data lake — raw + processed buckets with lifecycle rules |
| Glue Data Catalog | Schema management + partition registry |
| Athena | Serverless SQL analytics on S3 |
| EventBridge | Event-driven fastest lap detection |
| SNS | Email alerting |
| X-Ray | Distributed tracing across the pipeline |
| IAM | Least-privilege roles for producer and consumer |

All infrastructure provisioned with **modular Terraform** — no ClickOps.

---

## Project structure

```
stream-watch/
├── main.tf
├── variables.tf
├── outputs.tf
├── terraform.tfvars
├── run.sh                    # one-command setup after destroy
├── modules/
│   ├── sqs/                  # queue + DLQ
│   ├── s3/                   # raw + processed buckets, lifecycle rules
│   ├── iam/                  # producer + consumer roles
│   ├── lambda/               # consumer function, X-Ray, SQS event source
│   ├── glue/                 # catalog database + crawler
│   ├── athena/               # workgroup + results bucket
│   └── eventbridge/          # fastest lap rule + SNS topic
└── producer/
    ├── producer.py           # FastF1 → SQS replay script
    └── requirements.txt
```

---

## Getting started

### Prerequisites

- AWS CLI configured (`aws configure`)
- Terraform >= 1.6
- Python 3.12

### 1. Clone and init

```bash
git clone https://github.com/maneeshaYasinth/stream-watch.git
cd stream-watch
terraform init
```

### 2. Deploy everything

```bash
bash run.sh
```

This handles the full deployment in the correct order — base infra, Lambda zip upload, full apply.

### 3. Install producer dependencies

```bash
cd producer
python3.12 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
```

### 4. Dry run (no AWS interaction)

```bash
python producer.py --year 2024 --gp Bahrain --dry-run
```

### 5. Stream real telemetry

```bash
python producer.py --year 2024 --gp Bahrain
```

### 6. Register schema and run queries

```bash
# Create Athena table
aws athena start-query-execution \
  --work-group $(terraform output -raw athena_workgroup) \
  --query-execution-context Database=$(terraform output -raw glue_database_name) \
  --query-string "CREATE EXTERNAL TABLE IF NOT EXISTS telemetry (
    driver_number STRING, driver_code STRING, team STRING, gp STRING,
    timestamp STRING, speed DOUBLE, throttle DOUBLE, brake BOOLEAN,
    gear INT, rpm DOUBLE, drs INT, x DOUBLE, y DOUBLE,
    ingested_at STRING, drs_active BOOLEAN, full_throttle BOOLEAN, processed_at STRING
  )
  PARTITIONED BY (year STRING, race STRING, driver STRING)
  ROW FORMAT SERDE 'org.openx.data.jsonserde.JsonSerDe'
  LOCATION 's3://$(terraform output -raw processed_bucket_name)/telemetry/'
  TBLPROPERTIES ('classification'='json')" \
  --output text --query 'QueryExecutionId'

# Load partitions
aws athena start-query-execution \
  --work-group $(terraform output -raw athena_workgroup) \
  --query-execution-context Database=$(terraform output -raw glue_database_name) \
  --query-string "MSCK REPAIR TABLE telemetry" \
  --output text --query 'QueryExecutionId'
```

---

## Sample Athena queries

**Record count by driver**
```sql
SELECT driver_code, COUNT(*) as records
FROM telemetry
GROUP BY driver_code
ORDER BY records DESC;
```

**Average speed by driver**
```sql
SELECT driver_code, ROUND(AVG(speed), 2) AS avg_speed_kph
FROM telemetry
GROUP BY driver_code
ORDER BY avg_speed_kph DESC;
```

**DRS activation count by driver**
```sql
SELECT driver_code,
  SUM(CASE WHEN drs_active THEN 1 ELSE 0 END) AS drs_activations
FROM telemetry
GROUP BY driver_code
ORDER BY drs_activations DESC;
```

**Full throttle percentage by driver**
```sql
SELECT driver_code,
  ROUND(100.0 * SUM(CASE WHEN full_throttle THEN 1 ELSE 0 END) / COUNT(*), 1) AS full_throttle_pct
FROM telemetry
GROUP BY driver_code
ORDER BY full_throttle_pct DESC;
```

---

## Teardown

```bash
# Delete Athena workgroup first (has query history)
aws athena delete-work-group \
  --work-group $(terraform output -raw athena_workgroup) \
  --recursive-delete-option

terraform destroy --auto-approve
```

---

## Design notes

**SQS over Kinesis** — Kinesis is not free tier eligible. SQS provides equivalent functionality for dev/demo with 1M free requests/month. The architecture and resume reference Kinesis as the production-grade design.

**JSON over Parquet** — pyarrow compiled on macOS ARM64 is incompatible with Lambda's Linux ARM64 runtime. JSON is used as the storage format; Athena queries it natively via JsonSerDe. Parquet can be introduced later by building the Lambda package inside a Docker container matching the Lambda runtime.

**Lambda on arm64** — Graviton2 is ~20% cheaper and faster than x86 for this workload, and matches the local M-series build environment.

---

## Tech stack

`Python` `Terraform` `AWS SQS` `AWS Lambda` `AWS S3` `AWS Glue` `AWS Athena` `AWS EventBridge` `AWS SNS` `AWS X-Ray` `FastF1`

---

## Author

**Maneesha Yasinth Gunarathna**
[maneeshayasinth.site](https://maneeshayasinth.site) · [linkedin.com/in/maneeshayasinth](https://linkedin.com/in/maneeshayasinth) · [github.com/maneeshaYasinth](https://github.com/maneeshaYasinth)