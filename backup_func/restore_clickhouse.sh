#!/bin/bash

set -o allexport
source ./env/.env.clickhouse
set +o allexport

CONTAINER_NAME=clickhouse

BACKUP_PATH="/var/lib/clickhouse/backups/backup.zip"

docker cp ./backup.zip $CONTAINER_NAME:$BACKUP_PATH

docker exec $CONTAINER_NAME clickhouse-client --query="DROP DATABASE IF EXISTS $CLICKHOUSE_DB;"

docker exec $CONTAINER_NAME --query="RESTORE DATABASE $CLICKHOUSE_DB FROM File('$BACKUP_PATH');"

echo "Restore success"
