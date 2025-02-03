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
