# Local database setup

The backend uses `majiscope_db` for application records and a separate
`sensor_platform` database for sensor registries and readings. This initial
Docker setup creates only `majiscope_db`; `sensor_platform` is intentionally
deferred. The hydraulic simulation service has its own SQLite database, and
CS3 object storage keeps file bytes separately from PostgreSQL.

## Start a fresh PostgreSQL server

1. Copy `.env.example` to `.env` in the project root and replace the example
   password with a long, random value.
2. Start only the database service:

   ```powershell
   docker compose -f compose.database.yaml up -d
   docker compose -f compose.database.yaml ps
   ```

   The first startup creates `majiscope_db`. PostgreSQL 18 stores its live data
   under `D:\majiscope\postgres-data`, which is mounted into the container. The
   published host port is `5433`; PostgreSQL still listens on `5432` inside the
   container. `POSTGRES_HOST_PORT` can override the host port.

## Create the current application schemas

Install the backend requirements into the Python environment used for backend
development, then run the backend's documented fresh-database bootstrap. For
PowerShell, set the connection URLs from the same values in the root `.env`:

```powershell
cd Backend
$env:DATABASE_URL = "postgresql+psycopg://majiscope:<password>@localhost:5433/majiscope_db"
python init_db.py
python scripts/stamp_baseline.py main
```

Replace `<password>` with the local password from `.env`, URL-encoding it if it
contains reserved URL characters. `init_db.py` creates the current main-store
tables from the backend's SQLAlchemy models. The stamp command first verifies
that the database matches its models; it refuses to stamp a mismatched schema.
Do not run sensor-platform commands until that database has been provisioned.

This creates an empty database with the current application schema, not sample
users, reports, or sensor readings. A PostgreSQL dump from Supabase may contain
provider-managed schemas, roles, and extensions; do not restore such a dump
directly into the standard PostgreSQL container. Keep the database credentials
local; do not commit `.env`. The source dump should remain unchanged during any
selective data import.

## Supabase application-data imports

For an application-only import into standard PostgreSQL, restore the
application-owned `public` schema and its rows only. Do not import Supabase
`auth`, `storage`, `realtime`, `vault`, extension, role, or access-control
objects. Supabase Storage object bytes are not part of a PostgreSQL dump and
must be migrated separately if they are needed.

An imported application schema may predate the current SQLAlchemy models. Do
not run the fresh-database bootstrap or stamp the baseline on it. Verify the
schema and apply the reviewed main Alembic upgrades before starting the
backend. The sensor database is separate and must also be provisioned before
starting backend code that uses sensor-platform storage.

The local `majiscope_db` was rebuilt from all application tables and rows in
the `public` schema of `majiscope_db_backup.sql`, then upgraded to main
revision `0006_storage_facility_key_field`. Supabase-managed schemas were not
imported. Current model tables absent from that dump are created empty; they
do not contain data unless it was present in the source application schema.
