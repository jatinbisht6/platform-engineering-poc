#!/bin/bash

# Config
DB_NAME="Skaven_DW"
BACKUP_DIR="D:/Repos/platform-engineering-lab/data-platform/sqlserver/backups"
DATE=$(date +%Y%m%d_%H%M)

# Ensure backup directory exists
mkdir -p $BACKUP_DIR

# Backup command
if sqlcmd -S localhost -E \
  -Q "BACKUP DATABASE [$DB_NAME] 
      TO DISK='${BACKUP_DIR}/db_${DATE}.bak'
      WITH FORMAT, INIT, NAME='Full Backup';"
then
  echo "Backup completed: ${BACKUP_DIR}/db_${DATE}.bak"
else
  echo "❌ Backup FAILED"
  exit 1
fi