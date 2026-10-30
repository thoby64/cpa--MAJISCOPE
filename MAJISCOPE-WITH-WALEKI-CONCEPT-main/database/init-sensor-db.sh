#!/bin/sh
set -eu

psql \
  --set=ON_ERROR_STOP=1 \
  --username "$POSTGRES_USER" \
  --dbname "$POSTGRES_DB" \
  --set=sensor_db="$SENSOR_POSTGRES_DB" <<'SQL'
SELECT format('CREATE DATABASE %I OWNER %I', :'sensor_db', current_user)
WHERE NOT EXISTS (
    SELECT FROM pg_database WHERE datname = :'sensor_db'
)
\gexec
SQL
