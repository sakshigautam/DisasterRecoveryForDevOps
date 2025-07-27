# 🚨 Disaster Recovery Automation for AWS EC2 & Infrastructure

This repository contains scripts and workflows to enable **automated disaster recovery (DR)** for EC2-based workloads in AWS, including:

- 📦 Taking EBS snapshots of EC2 instances
- 🌍 Copying snapshots to a disaster recovery (DR) region
- 🚀 Restoring EC2 instances from snapshots in a different region
- 🛠️ Optional pipeline support with Terraform or GitHub Actions

├── snapshot_ec2_all_regions.sh # Snapshot all EC2 instances across regions
├── restore_ec2_from_snapshot.sh # Restore instance from copied snapshot in DR region
├── dr_pipeline_trigger.sh # Trigger DR pipeline (manual or automated)
├── terraform/ # IaC for infrastructure provisioning in both regions
│ └── main.tf # Multi-region DR Terraform template
├── .github/workflows/dr-pipeline.yml # GitHub Actions workflow (optional)
└── README.md
