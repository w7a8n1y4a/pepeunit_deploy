#!/bin/bash

set -o allexport
source ./env/.env.clickhouse
set +o allexport

CONTAINER_NAME=clickhouse

BACKUP_PATH="/var/lib/clickhouse/backups/backup.zip"

docker exec $CONTAINER_NAME clickhouse-client --query="BACKUP DATABASE $CLICKHOUSE_DB TO File('$BACKUP_PATH');"

docker cp $CONTAINER_NAME:$BACKUP_PATH ./backup.zip

chmod 777 backup.zip

echo "Backup saved as ./backup.zip"
