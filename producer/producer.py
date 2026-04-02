import json
import time
import boto3
import fastf1
import argparse
import os
from datetime import datetime, timezone

fastf1.Cache.enable_cache("./f1_cache")

# ---- Config--------------------------------------------------------
QUEUE_NAME = os.environ.get("SQS_QUEUE_NAME", "stream-watch-telemetry-dev")
REGION     = os.environ.get("AWS_REGION", "ap-southeast-1")
BATCH_SIZE = 10    # SQS max batch size
REPLAY_HZ  = 0.1  # seconds between batches


def get_queue_url(queue_name, region):
    print(f"[producer] Resolving queue URL for: {queue_name}")
    client   = boto3.client("sqs", region_name=region)
    response = client.get_queue_url(QueueName=queue_name)
    url      = response["QueueUrl"]
    print(f"[producer] Queue URL: {url}")
    return url


def load_session(year: int, gp: str, session_type: str):
    print(f"\n[producer] Loading {year} {gp} {session_type}...")
    print("[producer] First run downloads telemetry from F1 API — may take a minute")

    session = fastf1.get_session(year, gp, session_type)
    session.load(telemetry=True, weather=False, messages=False)

    print(f"[producer] Session loaded — {len(session.drivers)} drivers found")
    return session


def extract_records(session):
    """
    FastF1 returns per-driver telemetry as a pandas DataFrame.
    We flatten everything into a list of plain dicts.
    One dict = one SQS message.
    """
    records = []

    for drv in session.drivers:
        try:
            tel = session.car_data[drv]
        except Exception as e:
            print(f"[producer] Skipping driver {drv} — {e}")
            continue

        info = session.get_driver(drv)

        for _, row in tel.iterrows():
            records.append({
                "driver_number": drv,
                "driver_code":   info.get("Abbreviation", drv),
                "team":          info.get("TeamName", "Unknown"),
                "timestamp":     row["Date"].isoformat(),
                "speed":         float(row.get("Speed",    0)),
                "throttle":      float(row.get("Throttle", 0)),
                "brake":         bool(row.get("Brake",     False)),
                "gear":          int(row.get("nGear",      0)),
                "rpm":           float(row.get("RPM",      0)),
                "drs":           int(row.get("DRS",        0)),
                "x":             float(row.get("X",        0)),
                "y":             float(row.get("Y",        0)),
                "ingested_at": datetime.now(timezone.utc).isoformat(),
            })

    records.sort(key=lambda r: r["timestamp"])
    print(f"[producer] {len(records):,} telemetry records extracted")
    return records


def send_to_sqs(records, queue_url, region, dry_run=False):
    if dry_run:
        print(f"\n[dry-run] Would send {len(records):,} messages to SQS")
        print("[dry-run] First record:")
        print(json.dumps(records[0], indent=2))
        print("\n[dry-run] Last record:")
        print(json.dumps(records[-1], indent=2))
        return

    client        = boto3.client("sqs", region_name=region)
    total_sent    = 0
    total_failed  = 0
    batches       = [records[i:i + BATCH_SIZE] for i in range(0, len(records), BATCH_SIZE)]
    total_batches = len(batches)

    print(f"\n[producer] Sending {len(records):,} records in {total_batches:,} batches...")

    for i, batch in enumerate(batches):
        entries = [
            {
                "Id":          str(idx),
                "MessageBody": json.dumps(record),
            }
            for idx, record in enumerate(batch)
        ]

        response     = client.send_message_batch(QueueUrl=queue_url, Entries=entries)
        sent         = len(response.get("Successful", []))
        failed       = len(response.get("Failed",     []))
        total_sent   += sent
        total_failed += failed

        if failed > 0:
            print(f"[producer] WARNING batch {i} — {failed} messages failed")
            for f in response["Failed"]:
                print(f"  → {f['Id']}: {f['Message']}")

        if i % 100 == 0 and i > 0:
            pct = (i / total_batches) * 100
            print(f"[producer] Progress: {i}/{total_batches} batches ({pct:.0f}%) — sent: {total_sent:,}")

        time.sleep(REPLAY_HZ)

    print(f"\n[producer] Done!")
    print(f"[producer] Sent:   {total_sent:,}")
    print(f"[producer] Failed: {total_failed:,}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="stream-watch FastF1 → SQS producer")
    parser.add_argument("--year",       type=int, default=2024,      help="Season year")
    parser.add_argument("--gp",         type=str, default="Bahrain", help="Grand Prix name")
    parser.add_argument("--session",    type=str, default="R",       help="R / Q / FP1 / FP2 / FP3")
    parser.add_argument("--queue-name", type=str, default=QUEUE_NAME, help="SQS queue name")
    parser.add_argument("--region",     type=str, default=REGION)
    parser.add_argument("--dry-run",    action="store_true",         help="Print records, skip SQS")
    args = parser.parse_args()

    session   = load_session(args.year, args.gp, args.session)
    records   = extract_records(session)

    if args.dry_run:
        send_to_sqs(records, None, args.region, dry_run=True)
    else:
        queue_url = get_queue_url(args.queue_name, args.region)
        send_to_sqs(records, queue_url, args.region)