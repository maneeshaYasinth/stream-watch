import json
import io
import os
import boto3
import pyarrow as pa
import pyarrow.parquet as pq
from datetime import datetime, timezone
from collections import defaultdict

S3_BUCKET = os.environ["PROCESSED_BUCKET"]
REGION    = os.environ.get("AWS_REGION", "ap-southeast-1")

s3 = boto3.client("s3", region_name=REGION)


def enrich(record: dict) -> dict:
    """
    Add derived fields that weren't in the raw telemetry.
    These make Athena queries more useful.
    """
    ts = datetime.fromisoformat(record["timestamp"])

    record["year"]  = str(ts.year)
    record["month"] = str(ts.month).zfill(2)
    record["day"]   = str(ts.day).zfill(2)
    record["hour"]  = str(ts.hour).zfill(2)

    record["drs_active"] = record.get("drs", 0) in (10, 12, 14)

    record["full_throttle"] = record.get("throttle", 0) >= 95.0

    record["processed_at"] = datetime.now(timezone.utc).isoformat()

    return record


def to_parquet(records: list) -> bytes:
    """
    Convert a list of dicts to Parquet format in memory.
    pyarrow handles the schema inference automatically.
    """
    # Convert list of dicts → columnar format pyarrow understands
    columns = defaultdict(list)
    for r in records:
        for k, v in r.items():
            columns[k].append(v)

    table  = pa.table(dict(columns))
    buffer = io.BytesIO()
    pq.write_table(table, buffer)
    return buffer.getvalue()


def build_s3_key(record: dict, batch_id: str) -> str:
    """
    Partitioned layout — Athena uses these folder names as filter columns.
    year=2024/race=Bahrain/driver=VER/batch_<id>.parquet
    """
    return (
        f"telemetry/"
        f"year={record['year']}/"
        f"race={record.get('gp', 'unknown')}/"
        f"driver={record.get('driver_code', 'unknown')}/"
        f"batch_{batch_id}.parquet"
    )


def group_by_partition(records: list) -> dict:
    """
    Group records so each S3 file contains one driver's data
    from one race. Smaller files = faster Athena queries.
    """
    groups = defaultdict(list)
    for r in records:
        key = (r.get("year"), r.get("gp", "unknown"), r.get("driver_code"))
        groups[key].append(r)
    return groups


def lambda_handler(event, context):
    """
    SQS triggers this with a batch of messages.
    event["Records"] is a list of SQS messages.
    """
    records     = []
    failed_ids  = []
    batch_id    = context.aws_request_id[:8]

    print(f"[consumer] Received {len(event['Records'])} SQS messages")

    for msg in event["Records"]:
        try:
            record = json.loads(msg["body"])
            record = enrich(record)
            records.append(record)
        except Exception as e:
            print(f"[consumer] Failed to parse message {msg['messageId']}: {e}")
            failed_ids.append({"itemIdentifier": msg["messageId"]})

    print(f"[consumer] {len(records)} records parsed, {len(failed_ids)} failed")

    groups = group_by_partition(records)

    for (year, race, driver), group_records in groups.items():
        try:
            parquet_bytes = to_parquet(group_records)
            s3_key        = build_s3_key(group_records[0], batch_id)

            s3.put_object(
                Bucket=S3_BUCKET,
                Key=s3_key,
                Body=parquet_bytes,
                ContentType="application/octet-stream",
            )

            print(f"[consumer] Written {len(group_records)} records → s3://{S3_BUCKET}/{s3_key}")

        except Exception as e:
            print(f"[consumer] Failed to write partition {year}/{race}/{driver}: {e}")
            # Mark all messages in this group as failed
            for msg in event["Records"]:
                failed_ids.append({"itemIdentifier": msg["messageId"]})

    
    if failed_ids:
        return {"batchItemFailures": failed_ids}