#!/bin/bash
set -e

if [ -z "$1" ]; then
  echo "Укажите .backup файл как аргумент!"
  echo "Пример: ./restore_postgres_in_container.sh pepeunit_2025-07-31_10-30-00.backup"
  exit 1
fi

BACKUP_FILE="$1"
CONTAINER_NAME=postgres

source ./env/.env.postgres

echo "Копируем $BACKUP_FILE в контейнер..."
docker cp "$BACKUP_FILE" $CONTAINER_NAME:/tmp/restore.backup

# echo "Удаляем старую базу данных (если есть)..."
# docker exec $CONTAINER_NAME psql -U $POSTGRES_USER -c "DROP DATABASE IF EXISTS $POSTGRES_DB;"

# echo "Создаём базу данных заново..."
# docker exec $CONTAINER_NAME psql -U $POSTGRES_USER -c "CREATE DATABASE $POSTGRES_DB;"

echo "Восстанавливаем из backup-файла..."
docker exec $CONTAINER_NAME pg_restore -U $POSTGRES_USER -d $POSTGRES_DB -F c /tmp/restore.backup

echo "Восстановление завершено!"
