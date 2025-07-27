#!/bin/bash

DB_NAME="prod_db"
DB_USER="postgres"
BACKUP_DIR="/backups/postgres"
DATE=$(date +%F)

mkdir -p "$BACKUP_DIR"
pg_dump -U "$DB_USER" "$DB_NAME" > "$BACKUP_DIR/${DB_NAME}_$DATE.sql"

# Optional: delete backups older than 7 days
find "$BACKUP_DIR" -type f -mtime +7 -name '*.sql' -delete


#Schedule this script using crontab -e to take backup

#0 2 * * * /usr/local/bin/pg_backup.sh >> /var/log/pg_backup.log 2>&1
