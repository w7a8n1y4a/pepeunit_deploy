# Pepeunit Deploy

Развёртывание Pepeunit через `docker compose`: один файл настроек, генерация конфигов, резервные копии и обновление.

Полная инструкция: [документация по развёртыванию](https://pepeunit.com/deployment/docker/deploy.html).

## Быстрый старт

Нужны `docker`, `docker compose`, `python3` и `git`.

```bash
git clone https://git.pepemoss.com/pepe/pepeunit/pepeunit_deploy.git
cd pepeunit_deploy
cp .env.local.example .env.local
```

Откройте `.env.local` (для публичного инстанса с доменом и `https` возьмите `.env.global.example`) и измените:
- `PU_DOMAIN`, `PU_MQTT_HOST` - адрес инстанса
- логины и пароли баз, `PU_MQTT_*`, `PU_GRAFANA_ADMIN_*` - образцы публичные, замените их
- `PU_SECRET_KEY`, `PU_ENCRYPT_KEY` - оставьте `<32-bit-key>`, ключи создадутся сами

```bash
python3 make_env.py
docker compose up -d
```

Откройте `PU_DOMAIN` в браузере и зарегистрируйтесь. Затем станьте владельцем (`POSTGRES_USER` и `POSTGRES_DB` смотрите в `.env`):

```bash
docker exec -it postgres psql -U <POSTGRES_USER> -d <POSTGRES_DB> -c "SELECT uuid, login FROM users;"
docker exec -it backend python scripts/set_owner.py <uuid>
```

Порты `80` и `1883` должны быть доступны для Unit и пользователей. `docker-compose.yml` публикует порты всех сервисов, поэтому на публичном сервере закройте файрволом всё, кроме `80`, `443` и `1883`.

## Что в репозитории

Путь | Назначение
-- | --
`docker-compose.yml` | Все контейнеры, версии образов закреплены
`.env.local.example`, `.env.global.example` | Образцы файла настроек
`.env.local`, `.env.global` | Ваши настройки. **Единственный файл, который нужно править**, в `git` не попадает
`make_env.py` | Собирает `.env` и конфиги в `data/` из файла настроек
`backup.sh` | Резервные копии и восстановление
`data/` | Конфиги сервисов; `*.template` обрабатывает `make_env.py`
`backups/` | Готовые копии, создаётся автоматически

`.env` и конфиги в `data/` создаются заново при каждом запуске `make_env.py`, руками их не правят. Ключи `PU_SECRET_KEY` и `PU_ENCRYPT_KEY` при этом сохраняются, менять их нельзя: все токены и зашифрованные данные станут недействительны.

## Резервные копии

```bash
sudo ./backup.sh backup                              # создать, инстанс должен работать
sudo ./backup.sh restore backups/<имя файла>.tar     # восстановить
```

Архив лежит в `backups/` и содержит ключи и пароли: храните его так же бережно, как сервер. Восстановление **удаляет все тома проекта** и запускает Pepeunit заново.

## Обновление

```bash
sudo ./backup.sh backup
git pull
python3 make_env.py
docker compose up -d --remove-orphans
docker logs -f backend
```

`backend` сам применит миграции баз данных. Если `make_env.py` остановился с ошибкой, сверьте свой файл с актуальным образцом `.example`. Переход с `1.4.0` на `1.5.0` и со старых версий описан в [документации](https://pepeunit.com/deployment/docker/backup-update.html).

## Полезные команды

```bash
docker compose ps                      # состояние контейнеров
docker logs -f backend                 # логи контейнера
docker compose down                    # остановить
curl http://127.0.0.1:5291/pepeunit/api/v1/instances/current   # версия backend
```

Остальные команды: [документация](https://pepeunit.com/deployment/docker/commands.html).
