#!/bin/bash
set -e

source ./env/.env.postgres

BACKUP_NAME="${POSTGRES_DB}_$(date +%F_%H-%M-%S).backup"
CONTAINER_NAME=postgres
BACKUP_PATH="/tmp/$BACKUP_NAME"

docker exec -e PGPASSWORD=$POSTGRES_PASSWORD $CONTAINER_NAME \
  pg_dump -U $POSTGRES_USER -F c -d $POSTGRES_DB -f $BACKUP_PATH

docker cp $CONTAINER_NAME:$BACKUP_PATH ./$BACKUP_NAME

echo "Backup saved as $BACKUP_NAME"