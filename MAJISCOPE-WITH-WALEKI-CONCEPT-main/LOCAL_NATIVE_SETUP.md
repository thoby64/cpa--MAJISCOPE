# Run MajiScope locally without Docker (Windows)

This guide runs each application service as a normal Windows process, in its
own PowerShell window. The existing Docker data has been preserved and copied
into native local services; the original Docker data and `.env` files have not
been overwritten.

## What is already available on this computer

- Node.js 24 and npm are installed; use `npm.cmd` in PowerShell to avoid the
  machine's script-execution-policy issue with `npm.ps1`.
- Native PostgreSQL 18 is installed and its Windows service is running on port
  `5432`.
- Python 3.12 is installed and the backend and hydraulic environments are
  prepared.
- The existing Windows PostgreSQL service is untouched; MajiScope data runs in
  a separate native cluster on `127.0.0.1:5434`.
- The existing MajiScope PostgreSQL data and hydraulic files have been restored
  from verified backups. The app's local environment files already point to
  those restored copies.

## 1. Prepare service-local configuration

Run these commands from the project root. They create ignored `.env.local`
files only if one does not already exist:

```powershell
$services = @(
    "Backend",
    "Frontend",
    "CS3-OBJECT-STORAGE",
    "epanet_service_epytflow",
    "simulator"
)

foreach ($service in $services) {
    $example = Join-Path $service ".env.example"
    $local = Join-Path $service ".env.local"
    if ((Test-Path -LiteralPath $example) -and
        -not (Test-Path -LiteralPath $local)) {
        Copy-Item -LiteralPath $example -Destination $local
    }
}
```

The launcher reads each service's `.env.local` into that process's environment.
It does not print the values. Existing `.env` files are left in place, and the
service-local values take precedence. These files are ignored by Git; do not
commit them. The backend is configured to use the restored PostgreSQL
databases, and the hydraulic service uses a separate copy of the existing
EPANET files. Do not replace these settings with blank SQLite databases if you
want to keep the restored records.

- **Backend:** Local `DATABASE_URL` and `SENSOR_DATABASE_URL` point to the
  restored databases on port `5434`. Keep the local-only secret values private.
- **Frontend:** `NEXT_PUBLIC_BACKEND_URL` in `.env.local` is used by the
  launcher. Restart the frontend after changing it because Next.js embeds the
  value in browser code.
- **Hydraulic service:** Its `.env.local` paths point to
  `D:\majiscope\epanet-native\data`, a copy of the existing GPkg, INP, reports,
  and SQLite data. The original remains at `D:\majiscope\epanet\data`.
- **Simulator:** Set `INGEST_KEY` to the same value as the backend's
  `SENSOR_INGEST_KEY`. Keep the ingest URLs pointed at localhost.
- **CS3 storage:** Give its API key and browser passphrase separate, unique
  values. To use it for report media, also set the backend's
  `MEDIA_STORAGE_BACKEND=http`, `MEDIA_STORAGE_API_URL=http://127.0.0.1:8082`,
  and `MEDIA_STORAGE_API_KEY` to the CS3 API key. Otherwise the backend's local
  media storage works without starting CS3.

The restored user and business data is sensitive. The backend, frontend,
hydraulic, and CS3 launchers bind to localhost; do not expose this development
setup to the public internet. The sensor simulator's management UI does not
require login and binds to all network interfaces; do not start it on a machine
or network exposed to untrusted users.

## 2. Install dependencies

Run once after installing Python 3.12. Use separate virtual environments for
the backend and hydraulic service:

```powershell
Set-Location Backend
py -3.12 -m venv .venv
.\.venv\Scripts\python.exe -m pip install --upgrade pip
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
Set-Location ..

Set-Location epanet_service_epytflow
py -3.12 -m venv .venv
.\.venv\Scripts\python.exe -m pip install --upgrade pip
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
Set-Location ..

Set-Location Frontend
npm.cmd ci
Set-Location ..
```

The CS3 storage service and sensor simulator use the Python standard library
when run normally; the CS3 `requirements.txt` is only for its optional legacy
object-copy tool.

## 3. Start services separately

Start each service in its own PowerShell window from the project root. Start
the native database first, then CS3 storage and the hydraulic service before
the backend. Start the frontend after the backend. Start the simulator only
when you intend to send simulated readings.

These commands use a process-scoped execution-policy override because this
computer blocks direct `.ps1` launches. It does not change the persistent
PowerShell policy:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Start-LocalDatabase.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Start-LocalService.ps1 -Service storage
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Start-LocalService.ps1 -Service hydraulic
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Start-LocalService.ps1 -Service backend
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Start-LocalService.ps1 -Service frontend
```

Add the simulator command only when needed:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Start-LocalService.ps1 -Service simulator
```

The frontend and services are then available at:

| Service | Local address |
|---|---|
| Frontend | `http://localhost:3000` |
| Backend health | `http://127.0.0.1:8000/api/health` |
| Hydraulic model | `http://127.0.0.1:8084/app` |
| CS3 storage (if started) | `http://127.0.0.1:8082` |
| Sensor simulator (if started) | `http://127.0.0.1:8081` |

Use **Ctrl+C** in each service's PowerShell window to stop it. Stop the
MajiScope database with:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Stop-LocalDatabase.ps1
```

This only stops the MajiScope cluster on port `5434`; it does not stop or alter
the existing PostgreSQL Windows service on port `5432`.

The local hydraulic service uses port `8084` because port `8080` cannot be
bound on this computer. The launcher also enables UTF-8 output for Python so
the backend's startup banner works in Windows PowerShell.

The restored databases include the existing users and business records. Use
the same account credentials as the source system. Do not run `init_db.py`,
baseline stamping, or a fresh-database setup against these restored databases.

## Preserved data and backups

- Restored PostgreSQL databases: native cluster at `D:\majiscope\postgres-native`
  on `127.0.0.1:5434`.
- Verified PostgreSQL dumps and a copy of the original hydraulic files:
  `D:\majiscope\backups\local-migration-20261030-104912`.
- Hydraulic service working copy: `D:\majiscope\epanet-native\data`.
- Original hydraulic files and Docker database data remain preserved at their
  original locations. The old PostgreSQL 15 Docker volume was not migrated.
- CS3 storage files were empty during the migration; its service remains
  configured as a local service.

Keep the PostgreSQL administrator password file at
`D:\majiscope\postgres-native\postgres-admin-password.txt` private. The app
uses a separate database login stored in the ignored `Backend\.env.local`.

## Data locations and troubleshooting

- The restored app databases are PostgreSQL, not the fresh SQLite files created
  during earlier smoke tests.
- Hydraulic simulation files and its SQLite database use the preserved copy
  configured in `epanet_service_epytflow\.env.local`.
- If a port is already in use, stop only the process/container using that port
  or choose a different local port and update the corresponding service URL.
- If Python package installation fails, confirm that the environment was
  created with Python 3.12 (`.venv\Scripts\python.exe --version`).
- Service logs appear in each PowerShell window. Use the service's `/health`
  or `/api/health` URL to confirm it started.
