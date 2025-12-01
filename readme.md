# Развёртывание Pepeunit

[Документация по развёртыванию](https://pepeunit.com/deployment/docker/deploy.html)

## Шаги чтобы запустить Pepeunit

0. Установить `docker` и `docker compose`
1. Скачать репозиторий развёртывания и перейти в него
    ```bash
    git clone https://git.pepemoss.com/pepe/pepeunit/pepeunit_deploy.git
    cd pepeunit_deploy
    ```
1. Установить нужный уровень видимости для data дирректории:
    ```bash
    sudo chmod 777 -R data
    ```
1. Заполнить файл `.env.local` или `.env.global` своими данными на основе одноимённых файлов с пометкой `.example`
1. Запустить команду генерации окружений для сервисов, все файлы будут сохранены в дирректории `env`:
    ```bash
    python make_env.py
    ```
1. Если требуется дополнительно изменить переменные сервисов, внесите изменения в `env/.env.<service-name>` файлы
1. Выполните запуск `docker-compose.yml`
    ```bash
    docker compose up
    ```

## Работа с бэкапами

0. Запустите `Pepeunit` командой, это требуется для получения корректной версии
    ```bash
    docker compose up -d
    ```
1. Запустите создание `backup` командой, бекап делается без прекращения работы контейнеров
    ```bash
    sudo ./backup.sh backup
    ```
1. Развернуть версию из `backup`, инстанс при этом изначально должен быть полностью выключен командой `docker compose down`
    ```bash
    sudo ./backup.sh restore backups/backup_name.tar
    ```

## Обновление

0. Создайте `backup`
    ```bash
    sudo ./backup.sh backup
    ```
1. Выполните обновление репозитория
    ```bash
    git pull
    ```
1. Выполните обновление `env` переменных. Существующие секретные `32 битные ключи` изменены не будут. Остальные переменные будут сгенерированны, как при первой генерации, если вы выполняли ручной ввод данных в `env/.env.<service-name>` файлы, то ваши изменения будут **УДАЛЕНЫ**, поэтому обязательно делайте `backup` перед запуском команды. Если у вас очень тонкая настройка, изменяйте настройки в ручную, напрямую в `env/.env.<service-name>`.
    ```bash
    python make_env.py
    ```
1. Выполните запуск `Pepeunit`
    ```bash
    docker compose up -d

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
    docker exec -it datapipe /bin/sh
    docker exec -it emqx /bin/bash
    docker exec -it postgres /bin/bash
    docker exec -it redis /bin/bash
    docker exec -it nginx /bin/bash
    docker exec -it clickhouse /bin/bash
    ```
- Зайти в консоль базы данных, `POSTGRES_USER` и `POSTGRES_DB` можно найти в `env/.env.postgres`
    ```bash
    docker exec -it postgres psql -U <POSTGRES_USER> -d <POSTGRES_DB>
    psql -U <POSTGRES_USER> -d <POSTGRES_DB>
    ```
- Отправить запрос в clickhouse через curl:
    ```bash
    curl "http://admin:mypassword@127.0.0.1:8123/?query=SHOW+TABLES"
    ```