#!/bin/bash

# Configuration
AWS_PROFILE="default"          # AWS CLI profile
REGION="us-east-1"             # Region to clean snapshots from
TAG_KEY="Backup"               # Snapshot tag key to filter
TAG_VALUE="dr-backup"          # Snapshot tag value to filter
RETENTION_DAYS=30              # Delete snapshots older than this (days)
LOG_DIR="/tmp"                 # Directory containing logs to clean
LOG_RETENTION_DAYS=30          # Delete logs older than this (days)

echo "Starting cleanup of snapshots older than $RETENTION_DAYS days in region $REGION..."

# Get date threshold
THRESHOLD_DATE=$(date -d "-$RETENTION_DAYS days" +%Y-%m-%dT%H:%M:%S)

# List snapshots filtered by tag, older than threshold
SNAPSHOTS=$(aws ec2 describe-snapshots \
  --region "$REGION" \
  --profile "$AWS_PROFILE" \
  --owner-ids self \
  --filters "Name=tag:$TAG_KEY,Values=$TAG_VALUE" \
  --query "Snapshots[?StartTime<='${THRESHOLD_DATE}'].SnapshotId" \
  --output text)

if [ -z "$SNAPSHOTS" ]; then
  echo "No snapshots older than $RETENTION_DAYS days found."
else
  echo "Deleting snapshots:"
  for snap in $SNAPSHOTS; do
    echo "Deleting snapshot $snap ..."
    aws ec2 delete-snapshot --snapshot-id "$snap" --region "$REGION" --profile "$AWS_PROFILE"
  done
fi

echo "Cleaning up logs older than $LOG_RETENTION_DAYS days in $LOG_DIR..."

find "$LOG_DIR" -name "*.log" -type f -mtime +$LOG_RETENTION_DAYS -print -delete

echo "Cleanup completed."
