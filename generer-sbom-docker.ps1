# Generation SBOM a partir d'images Docker - Cas pratique Syft
# Usage: .\generer-sbom-docker.ps1
#        .\generer-sbom-docker.ps1 -Image "node:20-alpine"
#        .\generer-sbom-docker.ps1 -ConstruireAppExemple

param(
    [string]$Image = "",
    [switch]$ConstruireAppExemple,
    [string]$RapportsDir = "rapports"
)

$ProjetRoot = $PSScriptRoot
Set-Location $ProjetRoot

if (-not (Get-Command syft -ErrorAction SilentlyContinue)) {
    Write-Host "Syft n'est pas installe. Installez-le avec: winget install Anchore.syft" -ForegroundColor Red
    exit 1
}

New-Item -ItemType Directory -Force -Path $RapportsDir | Out-Null

# Option: construire l'image app-exemple puis la scanner
if ($ConstruireAppExemple) {
    Write-Host "=== Construction image Docker app-exemple ===" -ForegroundColor Cyan
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        Write-Host "Docker n'est pas installe ou pas dans le PATH." -ForegroundColor Red
        exit 1
    }
    docker build -t app-exemple-sbom:1.0 -f app-exemple/Dockerfile app-exemple
    if ($LASTEXITCODE -ne 0) { exit 1 }
    $Image = "app-exemple-sbom:1.0"
}

# Si aucune image specifice, utiliser node:20-alpine par defaut
if (-not $Image) {
    $Image = "node:20-alpine"
}

Write-Host ""
Write-Host "=== SBOM pour image Docker: $Image ===" -ForegroundColor Cyan

$baseName = $Image -replace "[:/]", "-"
$cdx = Join-Path $RapportsDir "sbom-docker-$baseName-cyclonedx.json"
$spdx = Join-Path $RapportsDir "sbom-docker-$baseName-spdx.json"

Write-Host "-> CycloneDX: $cdx"
syft $Image -o "cyclonedx-json=$cdx"
Write-Host "-> SPDX: $spdx"
syft $Image -o "spdx-json=$spdx"

Write-Host ""
Write-Host "Termine. Fichiers dans: $RapportsDir" -ForegroundColor Green
