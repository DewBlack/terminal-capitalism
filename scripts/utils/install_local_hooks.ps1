param()

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Resolve-Path (Join-Path $scriptDir "..\..")
$hooksDir = Join-Path $projectRoot ".githooks"

function Log([string]$Message) {
    Write-Host "[hooks-install] $Message"
}

function Fail([string]$Message) {
    throw "[hooks-install][ERROR] $Message"
}

if (-not (Test-Path (Join-Path $projectRoot ".git"))) {
    Fail "No se encontro .git en $projectRoot"
}

if (-not (Test-Path $hooksDir)) {
    Fail "No existe carpeta de hooks: $hooksDir"
}

$filesToMarkExecutable = @(
    (Join-Path $hooksDir "post-merge"),
    (Join-Path $hooksDir "post-rewrite"),
    (Join-Path $projectRoot "scripts\utils\auto_deploy_itch_after_pull.sh"),
    (Join-Path $projectRoot "scripts\utils\upload_itch_web.sh"),
    (Join-Path $projectRoot "scripts\utils\export_and_package_itch_web.sh"),
    (Join-Path $projectRoot "scripts\utils\export_to_web.sh")
)

foreach ($file in $filesToMarkExecutable) {
    if (-not (Test-Path $file)) {
        Fail "Falta archivo requerido: $file"
    }
}

git -C $projectRoot config core.hooksPath .githooks | Out-Null

$localDir = Join-Path $projectRoot ".local"
$envExample = Join-Path $projectRoot "scripts\utils\itch_deploy.env.example"
$envTarget = Join-Path $localDir "itch_deploy.env"

if (-not (Test-Path $localDir)) {
    New-Item -ItemType Directory -Path $localDir | Out-Null
}

if (-not (Test-Path $envTarget)) {
    Copy-Item $envExample $envTarget
    Log "Creado archivo base: .local/itch_deploy.env"
}

Log "Hooks instalados."
Log "core.hooksPath -> .githooks"
Log "Edita .local/itch_deploy.env y define ITCH_DEPLOY_MODE=offline o upload"
