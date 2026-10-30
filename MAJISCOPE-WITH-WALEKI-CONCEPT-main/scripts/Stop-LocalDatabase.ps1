$ErrorActionPreference = "Stop"
$pgCtl = "C:\Program Files\PostgreSQL\18\bin\pg_ctl.exe"
$dataDirectory = "D:\majiscope\postgres-native\data"

if (-not (Test-Path -LiteralPath $pgCtl -PathType Leaf)) {
    throw "PostgreSQL 18 pg_ctl.exe was not found at $pgCtl."
}
if (-not (Test-Path -LiteralPath $dataDirectory -PathType Container)) {
    throw "Local PostgreSQL data directory not found."
}

& $pgCtl status -D $dataDirectory *> $null
if ($LASTEXITCODE -ne 0) {
    Write-Output "Local PostgreSQL is already stopped."
    exit 0
}

& $pgCtl stop -D $dataDirectory -m fast
exit $LASTEXITCODE
