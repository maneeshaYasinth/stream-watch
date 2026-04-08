import json
import io
import os
import boto3
from datetime import datetime, timezone

S3_BUCKET = os.environ["PROCESSED_BUCKET"]
REGION    = os.environ.get("AWS_REGION", "ap-southeast-1")
s3        = boto3.client("s3", region_name=REGION)
events_client = boto3.client("events", region_name=REGION)


def enrich(record: dict) -> dict:
    ts = datetime.fromisoformat(record["timestamp"])
    record["year"]         = str(ts.year)
    record["month"]        = str(ts.month).zfill(2)
    record["day"]          = str(ts.day).zfill(2)
    record["drs_active"]   = record.get("drs", 0) in (10, 12, 14)
    record["full_throttle"] = record.get("throttle", 0) >= 95.0
    record["processed_at"] = datetime.now(timezone.utc).isoformat()
    return record


def lambda_handler(event, context):
    records    = []
    failed_ids = []
    batch_id   = context.aws_request_id[:8]

    print(f"[consumer] Received {len(event['Records'])} SQS messages")

    for msg in event["Records"]:
        try:
            record = json.loads(msg["body"])
            record = enrich(record)
            records.append(record)
        except Exception as e:
            print(f"[consumer] Failed to parse {msg['messageId']}: {e}")
            failed_ids.append({"itemIdentifier": msg["messageId"]})

    if records:
        # Write entire batch as newline-delimited JSON
        first = records[0]
        s3_key = (
            f"telemetry/"
            f"year={first.get('year', 'unknown')}/"
            f"race={first.get('gp', 'unknown')}/"
            f"driver={first.get('driver_code', 'unknown')}/"
            f"batch_{batch_id}.json"
        )

        body = "\n".join(json.dumps(r) for r in records)

        s3.put_object(
            Bucket=S3_BUCKET,
            Key=s3_key,
            Body=body.encode("utf-8"),
            ContentType="application/json",
        )

        print(f"[consumer] Written {len(records)} records → s3://{S3_BUCKET}/{s3_key}")

    if failed_ids:
        return {"batchItemFailures": failed_ids}

def publish_fastest_lap(record: dict):
    events_client.put_events(
        Entries=[{
            "Source":       "stream-watch.telemetry",
            "DetailType":   "FastestLap",
            "Detail":       json.dumps({
                "driver":    record.get("driver_code"),
                "team":      record.get("team"),
                "speed":     record.get("speed"),
                "gp":        record.get("gp"),
                "timestamp": record.get("timestamp"),
            }),
        }]
    )