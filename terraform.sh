#!/bin/bash

TARGET_REGION="us-west-2"
TERRAFORM_DIR="/infra/prod"

echo "Switching to recovery region: $TARGET_REGION"
cd "$TERRAFORM_DIR" || exit 1

terraform init
terraform workspace select dr || terraform workspace new dr

terraform apply -var="aws_region=$TARGET_REGION" -auto-approve

echo "Restoring database..."
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier prod-db-dr \
  --db-snapshot-identifier my-db-snapshot-copy \
  --region "$TARGET_REGION"

echo "Disaster recovery deployment complete in $TARGET_REGION"
