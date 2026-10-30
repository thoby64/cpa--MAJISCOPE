# Local Docker services

For a Windows setup that runs each service as a normal process without Docker,
see [LOCAL_NATIVE_SETUP.md](./LOCAL_NATIVE_SETUP.md).

Start the services from the project root in PowerShell. PostgreSQL keeps its
data under `D:\majiscope\postgres-data`; CS3 objects, EPANET files, backend
media, and simulator settings persist under `D:\majiscope`.

The local `.env` files contain credentials and are ignored by Git. The backend
and simulator environment files have been created for this installation; do
not replace them with committed examples.

## Start

The `majiscope-app` Docker network is shared by the application containers.
Create it once if it does not exist:

```powershell
docker network inspect majiscope-app *> $null
if ($LASTEXITCODE -ne 0) { docker network create majiscope-app }
```

Start the database, then services in dependency order:

```powershell
docker compose -f compose.database.yaml up -d
docker compose -f CS3-OBJECT-STORAGE\docker-compose.yml up -d --build
docker compose -f epanet_service_epytflow\docker-compose.yml up -d --build
docker compose -f Backend\docker-compose.yml up -d --build
docker compose -f Frontend\docker-compose.yml up -d --build
docker compose -f simulator\docker-compose.yml up -d --build
```

The backend Compose command applies the sensor database migrations before
starting FastAPI. The database bootstrap script creates `sensor_platform` on a
new PostgreSQL data directory; for this existing installation, that database
was created without changing the main `majiscope_db`.

To run the backend in the foreground so **Ctrl+C stops it** and rerunning the
same command rebuilds and starts it again, use this in a separate PowerShell
window from the project root:

```powershell
docker compose -f Backend\docker-compose.yml up --build
```

The simulator resumes the four sample devices in
`D:\majiscope\sensor-simulator\sensors.json` and sends synthetic readings to
the backend every 30 seconds. These unregistered samples are buffered as
pending readings. To pause generated readings while keeping the other
services running:

```powershell
docker compose -f simulator\docker-compose.yml stop
```

## Local URLs

| Service | URL |
| --- | --- |
| Frontend | http://127.0.0.1:3000 |
| Backend API and docs | http://127.0.0.1:8000/docs |
| PostgreSQL | `localhost:5433` |
| EPANET | http://localhost:8080/app |
| CS3 storage | http://127.0.0.1:8082 |
| Sensor simulator | http://127.0.0.1:8083 |

Host ports are bound to loopback. Container-to-container connections use the
`majiscope-app` network; the frontend's browser API URL remains
`http://localhost:8000`.
Backend hydraulic API requests use `http://dma_sim:8080` over the shared
`majiscope-app` Docker network. Open the standalone model locally at
`http://localhost:8080/app`; MajiScope launch links use the configured public
`HYDRAULIC_MODEL_PUBLIC_URL`.

## Cloudflare Quick Tunnel presentation URLs

The current Quick Tunnel URLs are temporary and work only while their
`cloudflared` processes are running. If Cloudflare issues new URLs, update the
frontend backend URL, backend `FRONTEND_URL` and `CORS_ORIGINS`, backend
`HYDRAULIC_MODEL_PUBLIC_URL`, and EPANET `MAJISCOPE_RETURN_URL`, then rebuild
the frontend and recreate the backend and EPANET containers.

The sensor simulator can be opened publicly, but its management UI does not
currently require authentication. Do not share that URL beyond the
presentation audience. Keep PostgreSQL private; it should not have a public
Quick Tunnel.

## Logs and status

```powershell
docker compose -f Backend\docker-compose.yml logs -f
docker compose -f Frontend\docker-compose.yml logs -f
docker compose -f simulator\docker-compose.yml logs -f
docker ps
```

Each service can be stopped independently with `docker compose -f <compose
file> stop`. Stopping the PostgreSQL container does not delete its persistent
data.
