# Compare deux SBOM CycloneDX : ajouts, suppressions, changements de version
# Usage: .\comparer-sbom.ps1 -Baseline rapports/sbom-baseline.json -Actuel rapports/sbom-cyclonedx.json
#        .\comparer-sbom.ps1 -Baseline rapports/sbom-cyclonedx.json -Actuel rapports/sbom-docker-app-exemple-sbom-1.0.json

param(
    [Parameter(Mandatory=$true)][string]$Baseline,
    [Parameter(Mandatory=$true)][string]$Actuel,
    [switch]$SortieMarkdown
)

$ErrorActionPreference = "Stop"
$ProjetRoot = $PSScriptRoot
Set-Location $ProjetRoot

function Get-ComponentsKeyed {
    param([string]$Path)
    if (-not (Test-Path $Path)) { throw "Fichier introuvable: $Path" }
    $bom = Get-Content -Raw -Path $Path | ConvertFrom-Json
    $list = @()
    foreach ($c in $bom.components) {
        $name = $c.name
        $ver = if ($c.version) { $c.version } else { "(sans version)" }
        $purl = if ($c.purl) { $c.purl } else { "pkg:generic/$name@$ver" }
        $list += [PSCustomObject]@{ Name = $name; Version = $ver; Purl = $purl; Key = "${name}@${ver}" }
    }
    return $list
}

$baseList = Get-ComponentsKeyed -Path $Baseline
$currList = Get-ComponentsKeyed -Path $Actuel

$baseByKey = @{}
foreach ($b in $baseList) { $baseByKey[$b.Key] = $b }
$currByKey = @{}
foreach ($c in $currList) { $currByKey[$c.Key] = $c }

$baseByName = @{}
foreach ($b in $baseList) { $baseByName[$b.Name] = $b }
$currByName = @{}
foreach ($c in $currList) { $currByName[$c.Name] = $c }

$added = @()
$removed = @()
$changed = @()

foreach ($c in $currList) {
    if (-not $baseByKey[$c.Key]) {
        if ($baseByName[$c.Name]) {
            $changed += [PSCustomObject]@{ Name = $c.Name; OldVersion = $baseByName[$c.Name].Version; NewVersion = $c.Version }
        } else {
            $added += $c
        }
    }
}
foreach ($b in $baseList) {
    if (-not $currByKey[$b.Key] -and -not ($currByName[$b.Name])) {
        $removed += $b
    }
}

# Sortie console
Write-Host "=== Comparaison SBOM ===" -ForegroundColor Cyan
Write-Host "Baseline: $Baseline ($($baseList.Count) composants)" -ForegroundColor Gray
Write-Host "Actuel:   $Actuel ($($currList.Count) composants)" -ForegroundColor Gray
Write-Host ""

Write-Host "Ajouts ($($added.Count)):" -ForegroundColor Green
foreach ($a in ($added | Sort-Object Name)) { Write-Host "  + $($a.Name) @ $($a.Version)" }
Write-Host ""

Write-Host "Suppressions ($($removed.Count)):" -ForegroundColor Red
foreach ($r in ($removed | Sort-Object Name)) { Write-Host "  - $($r.Name) @ $($r.Version)" }
Write-Host ""

Write-Host "Changements de version ($($changed.Count)):" -ForegroundColor Yellow
foreach ($ch in ($changed | Sort-Object Name)) { Write-Host "  ~ $($ch.Name): $($ch.OldVersion) -> $($ch.NewVersion)" }

if ($SortieMarkdown) {
    $mdPath = "rapports/sbom-diff.md"
    New-Item -ItemType Directory -Force -Path rapports | Out-Null
    $md = @"
# Diff SBOM

- **Baseline:** $Baseline ($($baseList.Count) composants)
- **Actuel:** $Actuel ($($currList.Count) composants)

## Ajouts ($($added.Count))

| Paquet | Version |
|--------|---------|
"@
    foreach ($a in ($added | Sort-Object Name)) { $md += "| $($a.Name) | $($a.Version) |`n" }
    $md += @"

## Suppressions ($($removed.Count))

| Paquet | Version |
|--------|---------|
"@
    foreach ($r in ($removed | Sort-Object Name)) { $md += "| $($r.Name) | $($r.Version) |`n" }
    $md += @"

## Changements de version ($($changed.Count))

| Paquet | Ancienne | Nouvelle |
|--------|----------|----------|
"@
    foreach ($ch in ($changed | Sort-Object Name)) { $md += "| $($ch.Name) | $($ch.OldVersion) | $($ch.NewVersion) |`n" }
    [System.IO.File]::WriteAllText((Join-Path $ProjetRoot $mdPath), $md, [System.Text.UTF8Encoding]::new($false))
    Write-Host "Rapport Markdown: $mdPath" -ForegroundColor Green
}
