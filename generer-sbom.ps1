# Script de generation SBOM avec Syft - Cas pratique Security M2
# Usage: .\generer-sbom.ps1  ou  .\generer-sbom.ps1 -Cible "app-exemple"

param(
    [string]$Cible = "app-exemple",
    [string]$RapportsDir = "rapports"
)

$ProjetRoot = $PSScriptRoot
Set-Location $ProjetRoot

if (-not (Get-Command syft -ErrorAction SilentlyContinue)) {
    Write-Host "Syft n'est pas installe. Installez-le avec: winget install Anchore.syft" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $Cible)) {
    Write-Host "La cible '$Cible' n'existe pas." -ForegroundColor Red
    exit 1
}

New-Item -ItemType Directory -Force -Path $RapportsDir | Out-Null

Write-Host "=== Generation SBOM avec Syft ===" -ForegroundColor Cyan
Write-Host "Cible: $Cible" -ForegroundColor Gray
Write-Host ""

# CycloneDX
$cdx = Join-Path $RapportsDir "sbom-cyclonedx.json"
Write-Host "-> CycloneDX JSON: $cdx"
syft $Cible -o "cyclonedx-json=$cdx"
if ($LASTEXITCODE -ne 0) { Write-Host "Erreur CycloneDX" -ForegroundColor Red }

# SPDX
$spdx = Join-Path $RapportsDir "sbom-spdx.json"
Write-Host "-> SPDX JSON: $spdx"
syft $Cible -o "spdx-json=$spdx"
if ($LASTEXITCODE -ne 0) { Write-Host "Erreur SPDX" -ForegroundColor Red }

# Syft JSON
$syft = Join-Path $RapportsDir "sbom-syft.json"
Write-Host "-> Syft JSON: $syft"
syft $Cible -o "syft-json=$syft"
if ($LASTEXITCODE -ne 0) { Write-Host "Erreur Syft JSON" -ForegroundColor Red }

Write-Host ""
Write-Host "Termine. Fichiers dans: $RapportsDir" -ForegroundColor Green
Get-ChildItem $RapportsDir | Format-Table Name, Length, LastWriteTime -AutoSize
