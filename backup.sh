#!/bin/bash

set -e

CLICKHOUSE_CONTAINER="clickhouse"
POSTGRES_CONTAINER="postgres"

DATA_DIRS=(
  "backend"
  "grafana"
  "nginx"
  "prometheus"
)

ENV_DIR="env"
BACKUP_DIR="./backups"
TMP_BACKUP_DIR="./backups/tmp"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")

get_api_version() {
    local API_URL="http://127.0.0.1:5291/pepeunit"
    local RESPONSE=$(curl -s --max-time 5 "$API_URL")
    local VERSION=$(echo "$RESPONSE" | grep -oP '"version"\s*:\s*"\K[\d.]+' || echo "")

    echo "$VERSION"
}

get_compose_version() {
    grep -oP 'image:\s*w7a8n1y4a/pepeunit-backend:\K[\d.]+' docker-compose.yml | head -n 1 || echo "unknown"
}

VERSION=$(get_api_version)

if [ -z "$VERSION" ]; then
    echo "API did not return a valid version, checking docker-compose.yml..."
    VERSION=$(get_compose_version)
fi

BACKUP_FILE="$BACKUP_DIR/${TIMESTAMP}_v${VERSION}_pepeunit_backup.tar"

create_backup() {
    for dir in "${DATA_DIRS[@]}"; do
        if [ ! -d "data/$dir" ]; then
            echo "Error: Directory data/$dir not found!"
            exit 1
        fi
    done

    if [ ! -d "$ENV_DIR" ]; then
        echo "Error: Directory $ENV_DIR not found!"
        exit 1
    fi

    mkdir -p "$BACKUP_DIR" "$TMP_BACKUP_DIR"

    echo "Run create Postgres backup"
    docker exec -e PGPASSWORD="$POSTGRES_PASSWORD" "$POSTGRES_CONTAINER" pg_dump -U "$POSTGRES_USER" -F c -d "$POSTGRES_DB" -f /tmp/postgres.backup
    docker cp "$POSTGRES_CONTAINER:/tmp/postgres.backup" "$TMP_BACKUP_DIR/postgres.backup"
    
    echo "Run create Clickhouse backup"
    local clickhouse_backup_path="/var/lib/clickhouse/backups/backup.zip"
    docker exec "$CLICKHOUSE_CONTAINER" bash -c "
        mkdir -p /var/lib/clickhouse/backups && 
        chown clickhouse:clickhouse /var/lib/clickhouse/backups &&
        chmod 750 -R /var/lib/clickhouse/backups"
    docker exec "$CLICKHOUSE_CONTAINER" rm -f /var/lib/clickhouse/backups/backup.zip
    docker exec "$CLICKHOUSE_CONTAINER" clickhouse-client --query="BACKUP DATABASE $CLICKHOUSE_DB TO File('$clickhouse_backup_path');"
    docker cp "$CLICKHOUSE_CONTAINER:$clickhouse_backup_path" "$TMP_BACKUP_DIR/clickhouse.zip"
    chmod 644 "$TMP_BACKUP_DIR/clickhouse.zip"

    echo "Creating archive"
    mkdir -p "$TMP_BACKUP_DIR/data"
    for dir in "${DATA_DIRS[@]}"; do
        if [ "$dir" == "grafana" ]; then
            echo "Backing up Grafana from container..."
            mkdir -p "$TMP_BACKUP_DIR/data/grafana"
            docker cp grafana:/var/lib/grafana "$TMP_BACKUP_DIR/data/grafana/data/"
            cp -r "data/$dir/provisioning" "$TMP_BACKUP_DIR/data/grafana/"
            cp "data/$dir/grafana.ini" "$TMP_BACKUP_DIR/data/grafana/"
        else
            cp -r "data/$dir" "$TMP_BACKUP_DIR/data/"
        fi
    done
    cp -r "$ENV_DIR" "$TMP_BACKUP_DIR/"
    tar -cvf "$BACKUP_FILE" -C "$TMP_BACKUP_DIR" .

    echo "Clear tmp dir"
    rm -rf "$TMP_BACKUP_DIR"/*
    
    echo "Clear tmp backup data in containers"
    docker exec "$POSTGRES_CONTAINER" rm -f /tmp/postgres.backup
    docker exec "$CLICKHOUSE_CONTAINER" rm -f /var/lib/clickhouse/backups/backup.zip

    echo "Backup created at $BACKUP_FILE"
}

restore_backup() {

    echo "Stop all containers"
    docker compose down || echo "Error on stop containers"

    if [ -z "$1" ]; then
        echo "Error: Please provide the path to the backup file!"
        exit 1
    fi

    BACKUP_PATH="$1"

    # check backup file
    if [ ! -f "$BACKUP_PATH" ]; then
        echo "Error: File $BACKUP_PATH not found!"
        exit 1
    fi

    echo "Extracting backup archive..."
    mkdir -p "$TMP_BACKUP_DIR"
    tar -xvf "$BACKUP_PATH" -C "$TMP_BACKUP_DIR"

    echo "Restoring data and env directories..."
    sudo rm -rf data/backend
    cp -r "$TMP_BACKUP_DIR/data/"* data/
    rm -rf data/env

    mkdir -p "$TMP_BACKUP_DIR"
    cp -r "$TMP_BACKUP_DIR/$ENV_DIR" .

    sudo chmod 777 -R data/grafana/data

    source ./env/.env.postgres
    source ./env/.env.clickhouse

    echo "Run only database containers"
    docker compose up postgres clickhouse -d
    
    echo "Waiting for PostgreSQL and ClickHouse to become healthy..."

    for SERVICE in postgres clickhouse; do
        echo "Checking $SERVICE..."
        while true; do
            STATUS=$(docker inspect --format='{{.State.Health.Status}}' "$SERVICE" 2>/dev/null)

            if [ "$STATUS" == "healthy" ]; then
            echo "$SERVICE is healthy."
            break
            elif [ "$STATUS" == "unhealthy" ]; then
            echo "$SERVICE became unhealthy. Exiting."
            exit 1
            else
            echo "$SERVICE is not ready yet. Status: $STATUS"
            sleep 2
            fi
        done
    done

    echo "All services are healthy."

    # postgres check
    if [ ! -f "$TMP_BACKUP_DIR/postgres.backup" ]; then
        echo "Error: Postgres backup not found in archive!"
        exit 1
    fi

    echo "Restoring Postgres database..."
    docker cp "$TMP_BACKUP_DIR/postgres.backup" "$POSTGRES_CONTAINER:/tmp/restore.backup"
    docker exec "$POSTGRES_CONTAINER" psql -U "$POSTGRES_USER" -d postgres -c "DROP DATABASE IF EXISTS $POSTGRES_DB;"
    docker exec "$POSTGRES_CONTAINER" psql -U "$POSTGRES_USER" -d postgres -c "CREATE DATABASE $POSTGRES_DB;"
    docker exec "$POSTGRES_CONTAINER" pg_restore -U "$POSTGRES_USER" -d "$POSTGRES_DB" -F c /tmp/restore.backup
    echo "Success restore Postgres"

    # click check
    if [ ! -f "$TMP_BACKUP_DIR/clickhouse.zip" ]; then
        echo "Error: ClickHouse backup not found in archive!"
        exit 1
    fi

    echo "Restoring ClickHouse database..."
    local clickhouse_backup_path="/var/lib/clickhouse/backups/backup.zip"
    docker exec "$CLICKHOUSE_CONTAINER" mkdir -p /var/lib/clickhouse/backups
    docker cp "$TMP_BACKUP_DIR/clickhouse.zip" "$CLICKHOUSE_CONTAINER:$clickhouse_backup_path"
    docker exec "$CLICKHOUSE_CONTAINER" clickhouse-client --query="DROP DATABASE IF EXISTS $CLICKHOUSE_DB;"
    docker exec "$CLICKHOUSE_CONTAINER" clickhouse-client --query="RESTORE DATABASE $CLICKHOUSE_DB FROM File('$clickhouse_backup_path');"
    echo "Success restore Clickhouse"

    # clear
    echo "Clear tmp dir"
    rm -rf "$TMP_BACKUP_DIR"
    echo "Clear tmp backup data in containers"
    docker exec "$POSTGRES_CONTAINER" rm -f /tmp/postgres.backup
    docker exec "$CLICKHOUSE_CONTAINER" rm -f /var/lib/clickhouse/backups/backup.zip

    echo "Restore completed successfully."
}

case "$1" in
    backup)
        source ./env/.env.postgres
        source ./env/.env.clickhouse
        create_backup
        ;;
    restore)
        restore_backup "$2"
        ;;
    *)
        echo "Usage: $0 {backup|restore path_to_backup}"
        exit 1
        ;;
esac
