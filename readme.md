# Развёртывание Pepeunit

[Подробная документация по развёртыванию](https://pepeunit.com/deployment/docker.html)

## Шаги чтобы запустить Pepeunit

0. Установить `docker` и `docker compose`
1. Скачать репозиторий развёртывания и перейти в него
    ```bash
    git clone https://git.pepemoss.com/pepe/pepeunit/pepeunit_deploy.git
    cd pepeunit_deploy
    ```
1. Заполнить файл `.env.local` или `.env.global` своими данными на основе одноимённых файлов с пометкой `.example`
1. Запустить команду генерации окружений для сервисов, все файлы будут сохранены в дирректории `env`:
    ```bash
    python make_env.py
    ```
1. Измените `server_name` в файле `data/nginx/nginx.conf` на локальный `ip` машины на которой запускается `docker-compose.yml`
1. Если требуется дополнительно изменить переменные сервисов, внесите изменения в `env/.env.<service-name>` файлы
1. Выполните запуск `docker-compose.yml`
    ```bash
    docker compose up
    ```

## Бэкапы

0. Запустите `Pepeunit` командой, это требуется для получения корректной версии, `sh` сам выключит контейнеры
    ```bash
    docker compose up -d
    ```
1. Запустите создание backup командой
    ```bash
    sudo ./backup.sh backup
    ```
1. Развернуть версию из backup
    ```bash
    sudo ./backup.sh restore backups/backup_name.tar
    ```

## Полезные команды для дебага

- Остановить `docker compose`
    ```bash
    docker compose down
    ```
- Запустить `docker compose` в фоновом режиме
    ```bash
    docker compose up -d
    ```
- Посмотреть логи конкретного контейнера
    ```bash
    docker logs postgres
    ```
- Зайти во внутрь контейнера, чтобы посмотреть состояние файлов и тд:
    ```bash
    docker exec -it frontend /bin/sh
    docker exec -it backend /bin/bash
    docker exec -it emqx /bin/bash
    docker exec -it postgres /bin/bash
    docker exec -it redis /bin/bash
    docker exec -it nginx /bin/bash
    ```
- Зайти в консоль базы данных, `POSTGRES_USER` и `POSTGRES_DB` можно найти в `env/.env.postgres`
    ```bash
    docker exec -it postgres psql -U <POSTGRES_USER> -d <POSTGRES_DB>
    psql -U <POSTGRES_USER> -d <POSTGRES_DB>
    ```