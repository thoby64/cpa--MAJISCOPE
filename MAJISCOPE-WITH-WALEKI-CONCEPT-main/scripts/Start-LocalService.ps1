param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("backend", "frontend", "storage", "hydraulic", "simulator")]
    [string]$Service
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$serviceDirectoryName = @{
    backend = "Backend"
    frontend = "Frontend"
    storage = "CS3-OBJECT-STORAGE"
    hydraulic = "epanet_service_epytflow"
    simulator = "simulator"
}[$Service]
$serviceDirectory = Join-Path $root $serviceDirectoryName
$environmentFile = Join-Path $serviceDirectory ".env.local"

if (-not (Test-Path -LiteralPath $environmentFile -PathType Leaf)) {
    throw "Missing $environmentFile. Copy that service's .env.example to .env.local and configure it first."
}

foreach ($line in Get-Content -LiteralPath $environmentFile) {
    $trimmedLine = $line.Trim()
    if (-not $trimmedLine -or $trimmedLine.StartsWith("#")) {
        continue
    }

    $separator = $trimmedLine.IndexOf("=")
    if ($separator -lt 1) {
        continue
    }

    $name = $trimmedLine.Substring(0, $separator).Trim()
    $value = $trimmedLine.Substring($separator + 1).Trim()
    if ($value.Length -ge 2 -and
        (($value.StartsWith('"') -and $value.EndsWith('"')) -or
         ($value.StartsWith("'") -and $value.EndsWith("'")))) {
        $value = $value.Substring(1, $value.Length - 2)
    }
    Set-Item -Path "Env:$name" -Value $value
}

$env:PYTHONUTF8 = "1"
Set-Location -LiteralPath $serviceDirectory

switch ($Service) {
    "backend" {
        $python = Join-Path $serviceDirectory ".venv\Scripts\python.exe"
        if (-not (Test-Path -LiteralPath $python -PathType Leaf)) {
            throw "Backend virtual environment not found. Create it and install Backend\requirements.txt first."
        }
        & $python -m uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
    }
    "frontend" {
        if (-not (Test-Path -LiteralPath (Join-Path $serviceDirectory "node_modules") -PathType Container)) {
            throw "Frontend dependencies not found. Run npm.cmd ci in the Frontend folder first."
        }
        if (-not $env:NEXT_PUBLIC_BACKEND_URL) {
            throw "NEXT_PUBLIC_BACKEND_URL is missing from $environmentFile."
        }
        & npm.cmd run dev -- --hostname 127.0.0.1 --port 3000
    }
    "storage" {
        & py -3.12 webui.py
    }
    "hydraulic" {
        $python = Join-Path $serviceDirectory ".venv\Scripts\python.exe"
        if (-not (Test-Path -LiteralPath $python -PathType Leaf)) {
            throw "Hydraulic service virtual environment not found. Create it and install epanet_service_epytflow\requirements.txt first."
        }
        & $python -m uvicorn app.main:app --reload --host 127.0.0.1 --port 8084
    }
    "simulator" {
        & py -3.12 sensor_simulator.py --web --port 8081
    }
}

exit $LASTEXITCODE
