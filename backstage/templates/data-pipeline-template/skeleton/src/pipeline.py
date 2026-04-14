"""
${{ values.name }} — data pipeline entry point.

${{ values.description }}

Pipeline type: ${{ values.pipeline_type }}
Schedule: ${{ values.schedule }}
"""
from __future__ import annotations

import logging
import os
import sys
from datetime import datetime, timezone

import boto3

logger = logging.getLogger(__name__)
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(name)s %(message)s",
)

# ── Config ──────────────────────────────────────────────────────────────────

SOURCE_BUCKET = os.environ.get("SOURCE_BUCKET", "${{ values.source_bucket }}")
OUTPUT_BUCKET = os.environ.get("OUTPUT_BUCKET", "${{ values.name }}-output")
AWS_REGION = os.environ.get("AWS_REGION", "us-east-1")
RUN_DATE = os.environ.get("RUN_DATE", datetime.now(timezone.utc).strftime("%Y-%m-%d"))


def extract(s3: "boto3.client", bucket: str, prefix: str) -> list[dict]:
    """List and download source objects matching prefix."""
    logger.info("extracting from s3://%s/%s", bucket, prefix)
    paginator = s3.get_paginator("list_objects_v2")
    objects = []
    for page in paginator.paginate(Bucket=bucket, Prefix=prefix):
        for obj in page.get("Contents", []):
            body = s3.get_object(Bucket=bucket, Key=obj["Key"])["Body"].read()
            objects.append({"key": obj["Key"], "data": body})
    logger.info("extracted %d objects", len(objects))
    return objects


def transform(objects: list[dict]) -> list[dict]:
    """Apply pipeline-specific transformations.

    TODO: Implement your transformation logic here.
    """
    logger.info("transforming %d records", len(objects))
    results = []
    for obj in objects:
        # Example: pass-through; replace with actual business logic
        results.append(
            {
                "source_key": obj["key"],
                "processed_at": datetime.now(timezone.utc).isoformat(),
                "size_bytes": len(obj["data"]),
            }
        )
    return results


def load(s3: "boto3.client", records: list[dict], bucket: str, run_date: str) -> str:
    """Write transformed records to S3 output bucket."""
    import json

    key = f"output/{run_date}/${{ values.name }}-results.json"
    payload = json.dumps(records, indent=2).encode()
    s3.put_object(Bucket=bucket, Key=key, Body=payload, ContentType="application/json")
    logger.info("loaded %d records → s3://%s/%s", len(records), bucket, key)
    return key


def run() -> int:
    logger.info("starting ${{ values.name }} pipeline, run_date=%s", RUN_DATE)
    s3 = boto3.client("s3", region_name=AWS_REGION)

    try:
        objects = extract(s3, SOURCE_BUCKET, f"raw/{RUN_DATE}/")
        if not objects:
            logger.warning("no source objects found for %s — exiting", RUN_DATE)
            return 0

        records = transform(objects)
        output_key = load(s3, records, OUTPUT_BUCKET, RUN_DATE)
        logger.info("pipeline complete: %s", output_key)
        return 0
    except Exception as exc:
        logger.exception("pipeline failed: %s", exc)
        return 1


if __name__ == "__main__":
    sys.exit(run())
