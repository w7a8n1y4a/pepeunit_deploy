#!/bin/bash

BACKUP_DIR="./backups"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")

# Function to get version from backend API
get_api_version() {
    local API_URL="http://127.0.0.1:5291/pepeunit"
    local RESPONSE=$(curl -s --max-time 5 "$API_URL")

    # Extract "version" field from JSON response
    local VERSION=$(echo "$RESPONSE" | grep -oP '"version"\s*:\s*"\K[\d.]+' || echo "")

    echo "$VERSION"
}

# Function to get version from docker-compose.yml
get_compose_version() {
    grep -oP 'image:\s*w7a8n1y4a/pepeunit-backend:\K[\d.]+' docker-compose.yml | head -n 1 || echo "unknown"
}

# First, try to get version from API
VERSION=$(get_api_version)

# If API failed, fallback to docker-compose
if [ -z "$VERSION" ]; then
    echo "API did not return a valid version, checking docker-compose.yml..."
    VERSION=$(get_compose_version)
fi

BACKUP_FILE="$BACKUP_DIR/${TIMESTAMP}_v${VERSION}_pepeunit_backup.tar"
DATA_DIRS=("data" "env")

# Function to create a backup
create_backup() {
    echo "Stopping docker-compose..."
    docker compose down

    # Check if required directories exist
    for dir in "${DATA_DIRS[@]}"; do
        if [ ! -d "$dir" ]; then
            echo "Error: Directory $dir not found!"
            exit 1
        fi
    done

    mkdir -p "$BACKUP_DIR"
    echo "Creating backup at $BACKUP_FILE..."
    tar -cvf "$BACKUP_FILE" "${DATA_DIRS[@]}"

    echo "Backup created: $BACKUP_FILE"
}

# Function to restore a backup
restore_backup() {
    if [ -z "$1" ]; then
        echo "Error: Please provide the path to the backup file!"
        exit 1
    fi

    BACKUP_PATH="$1"

    if [ ! -f "$BACKUP_PATH" ]; then
        echo "Error: File $BACKUP_PATH not found!"
        exit 1
    fi

    echo "Extracting backup..."
    tar -xvf "$BACKUP_PATH"

    echo "Backup successfully restored!"
}

# Argument handling
case "$1" in
    backup)
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
