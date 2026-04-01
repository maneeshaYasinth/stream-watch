# stream-watch

> Real-time F1 telemetry ingestion and analytics pipeline on AWS — provisioned entirely with Terraform.

---

## What it does

stream-watch replays historical F1 race telemetry (speed, throttle, brake, DRS, GPS position) as a live data stream into AWS, processes it serverlessly, stores it in a partitioned data lake, and runs SQL analytics on it — all without managing a single server.

When a new fastest lap is detected mid-race, an alert fires automatically via email.

---

## Architecture

```
FastF1 (Python producer)
    │
    │  JSON telemetry records (per driver, per tick)
    ▼
SQS queue                     ← managed message queue (AWS Free Tier eligible)
    │
    │  triggers on new records
    ▼
Lambda (consumer)             ← enriches + converts to Parquet
    │                            traced with AWS X-Ray
    ├──► S3 raw/               ← original JSON (audit trail)
    │
    └──► S3 processed/         ← partitioned Parquet
              year=2024/
              race=Bahrain/
              driver=VER/
              lap=12/
    │
    ▼
Glue Data Catalog             ← schema registry, auto-crawls S3
    │
    ▼
Athena                        ← serverless SQL on S3
    │
    ▼
EventBridge                   ← fastest lap event rule
    │
    ▼
SNS → email alert             ← "VER set fastest lap — 1:31.447"
```

CloudWatch dashboard tracks Lambda invocations, SQS queue depth/message age, S3 PUT count, and error rates. X-Ray provides distributed traces across the full pipeline.

---

## AWS services used

| Service | Role |
|---|---|
| SQS | Real-time telemetry ingestion buffer |
| Lambda | Serverless stream processing |
| S3 | Data lake (raw + processed) |
| Glue Data Catalog | Schema management + partition crawling |
| Athena | Serverless SQL analytics |
| EventBridge | Event-driven fastest lap detection |
| SNS | Email alerting |
| CloudWatch | Metrics + dashboards |
| X-Ray | Distributed tracing |
| IAM | Least-privilege roles for producer + consumer |

All infrastructure is provisioned via **modular Terraform** — no ClickOps.

---

## Project structure

```
stream-watch/
├── main.tf               # root module — wires everything together
├── variables.tf
├── outputs.tf
├── terraform.tfvars
├── modules/
│   ├── sqs/              # queue config
│   ├── s3/               # raw + processed buckets, lifecycle rules
│   ├── iam/              # producer + consumer roles
│   ├── lambda/           # consumer function + X-Ray + event source mapping
│   ├── glue/             # catalog database + crawler
│   └── athena/           # workgroup + named queries
└── producer/
    ├── producer.py       # FastF1 → SQS replay script
    └── requirements.txt
```

---

## Getting started

### Prerequisites

- AWS CLI configured (`aws configure`)
- Terraform >= 1.6
- Python >= 3.10

### 1. Clone and init

```bash
git clone https://github.com/maneeshaYasinth/stream-watch.git
cd stream-watch
terraform init
```

### 2. Deploy infrastructure

```bash
terraform apply
```

Note the output values — you'll need `queue_url` for the producer.

### 3. Install producer dependencies

```bash
cd producer
python -m venv .venv && source .venv/bin/activate
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

---

## Sample Athena queries

**Average speed by driver through sector 2 — 2024 Bahrain GP**
```sql
SELECT driver_code, ROUND(AVG(speed), 2) AS avg_speed_kph
FROM telemetry
WHERE year = '2024' AND race = 'Bahrain' AND sector = 2
GROUP BY driver_code
ORDER BY avg_speed_kph DESC;
```

**Fastest lap per driver**
```sql
SELECT driver_code, MIN(lap_time_seconds) AS fastest_lap
FROM lap_summary
WHERE year = '2024' AND race = 'Bahrain'
GROUP BY driver_code
ORDER BY fastest_lap ASC;
```

**Throttle vs brake by lap (VER)**
```sql
SELECT lap, ROUND(AVG(throttle), 1) AS avg_throttle, SUM(CAST(brake AS INT)) AS brake_events
FROM telemetry
WHERE year = '2024' AND race = 'Bahrain' AND driver_code = 'VER'
GROUP BY lap
ORDER BY lap;
```

---

## Teardown

To avoid ongoing costs, destroy the stream-processing resources after a demo run:

```bash
terraform destroy
```

S3 and Glue catalog can be kept for continued Athena querying without incurring Lambda/SQS costs.

---

## Tech stack

`Python` `Terraform` `AWS SQS` `AWS Lambda` `AWS S3` `AWS Glue` `AWS Athena` `AWS EventBridge` `AWS SNS` `AWS X-Ray` `FastF1`

---

## Author

**Maneesha Yasinth Gunarathna**
[maneeshayasinth.site](https://maneeshayasinth.site) · [linkedin.com/in/maneeshayasinth](https://linkedin.com/in/maneeshayasinth) · [github.com/maneeshaYasinth](https://github.com/maneeshaYasinth)