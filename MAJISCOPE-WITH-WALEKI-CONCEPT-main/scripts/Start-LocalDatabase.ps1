$ErrorActionPreference = "Stop"
$pgCtl = "C:\Program Files\PostgreSQL\18\bin\pg_ctl.exe"
$dataDirectory = "D:\majiscope\postgres-native\data"
$logFile = Join-Path $dataDirectory "postgres.log"

if (-not (Test-Path -LiteralPath $pgCtl -PathType Leaf)) {
    throw "PostgreSQL 18 pg_ctl.exe was not found at $pgCtl."
}
if (-not (Test-Path -LiteralPath $dataDirectory -PathType Container)) {
    throw "Local PostgreSQL data directory not found. See LOCAL_NATIVE_SETUP.md."
}

& $pgCtl status -D $dataDirectory *> $null
if ($LASTEXITCODE -eq 0) {
    Write-Output "Local PostgreSQL is already running."
    exit 0
}

& $pgCtl start -D $dataDirectory -l $logFile -o "-h 127.0.0.1 -p 5434"
exit $LASTEXITCODE
