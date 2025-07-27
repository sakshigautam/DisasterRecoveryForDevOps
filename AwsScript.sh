#!/bin/bash

# === CONFIGURATION ===
SOURCE_REGION="us-east-1"
DR_REGION="us-west-2"
INSTANCE_ID="i-0123456789abcdef0"
KEY_NAME="your-key"
SECURITY_GROUP_ID="sg-0123456789abcdef0"
SUBNET_ID="subnet-0123456789abcdef0"
INSTANCE_TYPE="t3.micro"
TAG_FILTER="Name=DR-Backup,Value=true"
AWS_PROFILE="default"

DATE=$(date +%F-%H-%M)
LOG_FILE="/tmp/ec2_dr_restore_$DATE.log"
mkdir -p /tmp

echo "Starting EC2 DR snapshot and restore at $DATE" | tee -a $LOG_FILE

# Step 1: Get root volume ID
ROOT_VOLUME=$(aws ec2 describe-instances \
  --region "$SOURCE_REGION" \
  --profile "$AWS_PROFILE" \
  --instance-ids "$INSTANCE_ID" \
  --query "Reservations[0].Instances[0].BlockDeviceMappings[?DeviceName=='/dev/xvda'].Ebs.VolumeId" \
  --output text)

echo " Found root volume: $ROOT_VOLUME" | tee -a $LOG_FILE

# Step 2: Create snapshot
SNAPSHOT_ID=$(aws ec2 create-snapshot \
  --region "$SOURCE_REGION" \
  --volume-id "$ROOT_VOLUME" \
  --description "DR snapshot of $INSTANCE_ID on $DATE" \
  --tag-specifications "ResourceType=snapshot,Tags=[{Key=Name,Value=DR-$INSTANCE_ID-$DATE},{Key=DR-Backup,Value=true}]" \
  --profile "$AWS_PROFILE" \
  --query "SnapshotId" \
  --output text)

echo "Snapshot $SNAPSHOT_ID created." | tee -a $LOG_FILE

# Step 3: Wait for snapshot to complete
echo "Waiting for snapshot to complete..."
aws ec2 wait snapshot-completed --snapshot-ids "$SNAPSHOT_ID" --region "$SOURCE_REGION" --profile "$AWS_PROFILE"

# Step 4: Copy snapshot to DR region
COPIED_SNAPSHOT_ID=$(aws ec2 copy-snapshot \
  --source-region "$SOURCE_REGION" \
  --source-snapshot-id "$SNAPSHOT_ID" \
  --description "Copied for DR $INSTANCE_ID" \
  --region "$DR_REGION" \
  --profile "$AWS_PROFILE" \
  --query "SnapshotId" \
  --output text)

echo "Copied snapshot to $DR_REGION: $COPIED_SNAPSHOT_ID" | tee -a $LOG_FILE

# Wait until copy completes
aws ec2 wait snapshot-completed --snapshot-ids "$COPIED_SNAPSHOT_ID" --region "$DR_REGION" --profile "$AWS_PROFILE"

# Step 5: Create volume from snapshot
AVAIL_ZONE="${DR_REGION}a"
VOLUME_ID=$(aws ec2 create-volume \
  --region "$DR_REGION" \
  --availability-zone "$AVAIL_ZONE" \
  --snapshot-id "$COPIED_SNAPSHOT_ID" \
  --volume-type gp3 \
  --tag-specifications "ResourceType=volume,Tags=[{Key=Name,Value=DR-Volume-$DATE}]" \
  --profile "$AWS_PROFILE" \
  --query "VolumeId" \
  --output text)

echo "Created volume: $VOLUME_ID" | tee -a $LOG_FILE

aws ec2 wait volume-available --volume-ids "$VOLUME_ID" --region "$DR_REGION" --profile "$AWS_PROFILE"

# Step 6: Launch EC2 instance in DR region
INSTANCE_AMI="ami-0abcdef1234567890"  # Replace with correct AMI (same OS)

NEW_INSTANCE_ID=$(aws ec2 run-instances \
  --region "$DR_REGION" \
  --profile "$AWS_PROFILE" \
  --image-id "$INSTANCE_AMI" \
  --instance-type "$INSTANCE_TYPE" \
  --key-name "$KEY_NAME" \
  --subnet-id "$SUBNET_ID" \
  --security-group-ids "$SECURITY_GROUP_ID" \
  --block-device-mappings "[{
    \"DeviceName\": \"/dev/xvda\",
    \"Ebs\": {
      \"SnapshotId\": \"$COPIED_SNAPSHOT_ID\",
      \"VolumeSize\": 8,
      \"DeleteOnTermination\": true,
      \"VolumeType\": \"gp3\"
    }
  }]" \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=Restored-DR-Instance-$DATE}]" \
  --query "Instances[0].InstanceId" \
  --output text)

echo " Launched DR instance: $NEW_INSTANCE_ID in $DR_REGION" | tee -a $LOG_FILE
