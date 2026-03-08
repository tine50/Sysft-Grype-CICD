# Pipeline complet Syft + Grype - Cas pratique Security M2
# 1) Génère le SBOM (répertoire ou image Docker)
# 2) Lance Grype sur le SBOM
# 3) Produit rapport table + JSON
# 4) Option : fait échouer le script si vulnérabilités critical/high
#
# Usage:
#   .\syft-grype-pipeline.ps1
#   .\syft-grype-pipeline.ps1 -Cible "app-exemple"
#   .\syft-grype-pipeline.ps1 -CibleImage "app-exemple-sbom:1.0" -ConstruireImage
#   .\syft-grype-pipeline.ps1 -FailOnSeverity critical

param(
    [string]$Cible = "app-exemple",
    [string]$CibleImage = "",
    [switch]$ConstruireImage,
    [string]$RapportsDir = "rapports",
    [string]$FailOnSeverity = ""   # "critical" ou "high" pour faire échouer le script
)

$ErrorActionPreference = "Stop"
$ProjetRoot = $PSScriptRoot
Set-Location $ProjetRoot

# --- Vérifications ---
if (-not (Get-Command syft -ErrorAction SilentlyContinue)) {
    Write-Host "Syft n'est pas installe. Installez-le avec: winget install Anchore.syft" -ForegroundColor Red
    exit 1
}
if (-not (Get-Command grype -ErrorAction SilentlyContinue)) {
    Write-Host "Grype n'est pas installe. Installez-le avec: winget install Anchore.grype" -ForegroundColor Red
    exit 1
}

New-Item -ItemType Directory -Force -Path $RapportsDir | Out-Null

$sbomPath = ""
$scanTarget = ""

# --- Construire image si demandé ---
if ($ConstruireImage) {
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        Write-Host "Docker n'est pas installe ou pas dans le PATH." -ForegroundColor Red
        exit 1
    }
    if (-not $CibleImage) { $CibleImage = "app-exemple-sbom:1.0" }
    Write-Host "=== Construction image Docker: $CibleImage ===" -ForegroundColor Cyan
    docker build -t $CibleImage -f app-exemple/Dockerfile app-exemple
    if ($LASTEXITCODE -ne 0) { exit 1 }
}

# --- Choix cible : image ou répertoire ---
if ($CibleImage) {
    $scanTarget = $CibleImage
    $baseName = $CibleImage -replace "[:/]", "-"
    $sbomPath = Join-Path $RapportsDir "sbom-docker-$baseName.json"
} else {
    if (-not (Test-Path $Cible)) {
        Write-Host "La cible '$Cible' n'existe pas." -ForegroundColor Red
        exit 1
    }
    $scanTarget = $Cible
    $sbomPath = Join-Path $RapportsDir "sbom-cyclonedx.json"
}

# --- 1) Syft : génération SBOM ---
Write-Host ""
Write-Host "=== 1) Syft - Generation SBOM ===" -ForegroundColor Cyan
Write-Host "Cible: $scanTarget" -ForegroundColor Gray
Write-Host "SBOM: $sbomPath"
syft $scanTarget -o "cyclonedx-json=$sbomPath"
if ($LASTEXITCODE -ne 0) {
    Write-Host "Erreur Syft." -ForegroundColor Red
    exit 1
}

# --- 2) Grype : scan vulnérabilités ---
$vulnsJson = Join-Path $RapportsDir "vulns.json"
$vulnsTable = Join-Path $RapportsDir "vulns-table.txt"
Write-Host ""
Write-Host "=== 2) Grype - Scan vulnerabilites ===" -ForegroundColor Cyan
grype "sbom:$sbomPath" -o table 2>&1 | Tee-Object -FilePath $vulnsTable
# Grype : -f = --fail-on (sévérité), donc utiliser --file pour écrire le rapport JSON
grype "sbom:$sbomPath" -o json --file $vulnsJson
if ($LASTEXITCODE -ne 0) {
    Write-Host "Erreur Grype (generation rapport)." -ForegroundColor Red
    exit 1
}

# --- 3) Option : fail-on severity ---
if ($FailOnSeverity) {
    Write-Host ""
    Write-Host "=== 3) Controle severite (fail-on $FailOnSeverity) ===" -ForegroundColor Cyan
    grype "sbom:$sbomPath" --fail-on $FailOnSeverity
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Echec : vulnerabilites $FailOnSeverity detectees. Pipeline en echec." -ForegroundColor Red
        exit 1
    }
    Write-Host "Aucune vulnerabilite $FailOnSeverity. OK." -ForegroundColor Green
}

Write-Host ""
Write-Host "Termine. Fichiers dans: $RapportsDir" -ForegroundColor Green
Write-Host "  SBOM:       $sbomPath" -ForegroundColor Gray
Write-Host "  Vulns JSON: $vulnsJson" -ForegroundColor Gray
Write-Host "  Vulns table: $vulnsTable" -ForegroundColor Gray
