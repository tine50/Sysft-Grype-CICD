# Genere un rapport HTML des vulnerabilites Grype a partir de rapports/vulns.json
# Usage: .\generer-rapport-vulns-html.ps1
#        .\generer-rapport-vulns-html.ps1 -VulnsJson "rapports/vulns.json" -Sortie "rapports/vulns-report.html"

param(
    [string]$VulnsJson = "rapports/vulns.json",
    [string]$Sortie = "rapports/vulns-report.html"
)

$ErrorActionPreference = "Stop"
$ProjetRoot = $PSScriptRoot
Set-Location $ProjetRoot

if (-not (Test-Path $VulnsJson)) {
    Write-Host "Fichier introuvable: $VulnsJson. Lancez d'abord le pipeline (syft-grype-pipeline.ps1)." -ForegroundColor Red
    exit 1
}

$data = Get-Content -Raw -Path $VulnsJson | ConvertFrom-Json
$matches = @($data.matches)
$sourceTarget = $data.source.target
$grypeVersion = $data.descriptor.version
$date = Get-Date -Format "yyyy-MM-dd HH:mm"

# Grouper par severite et extraire description / URL
$bySeverity = @{}
foreach ($m in $matches) {
    $v = $m.vulnerability
    $p = if ($m.package) { $m.package } else { $m.artifact }
    $sev = if ($v.severity) { $v.severity } else { "Unknown" }
    $fixVersions = $m.fix.versions
    $fixStr = if ($fixVersions -and $fixVersions.Count -gt 0) { ($fixVersions -join ", ") } else { ""
    $url = $v.url
    if (-not $url -and $v.id -match "^GHSA-") {
        $url = "https://github.com/advisories/$($v.id)"
    }
    if (-not $url -and $v.id -match "^CVE-") {
        $url = "https://nvd.nist.gov/vuln/detail/$($v.id)"
    }
    $desc = if ($v.description) { $v.description } else { "" }
    if (-not $bySeverity[$sev]) { $bySeverity[$sev] = @() }
    $bySeverity[$sev] += [PSCustomObject]@{
        VulnId      = $v.id
        Severity    = $sev
        PkgName     = $p.name
        PkgVersion  = $p.version
        PkgType     = $p.type
        FixedIn     = $fixStr
        Url         = $url
        Description = $desc
    }
}

# Resume par severite (pour le bandeau)
$summaryParts = @()
$orderSeverity = @("Critical", "High", "Medium", "Low", "Negligible", "Unknown")
foreach ($s in $orderSeverity) {
    if ($bySeverity[$s]) { $summaryParts += "$($bySeverity[$s].Count) $s" }
}
$summaryText = if ($summaryParts.Count -gt 0) { $summaryParts -join ", " } else { "aucune" }

$orderSeverity = @("Critical", "High", "Medium", "Low", "Negligible", "Unknown")
$rows = ""
foreach ($sev in $orderSeverity) {
    if (-not $bySeverity[$sev]) { continue }
    $class = $sev.ToLower()
    foreach ($r in $bySeverity[$sev]) {
        $noFixHtml = '<span class="no-fix">— Non corrigée</span>'
        $fix = if ($r.FixedIn) { [System.Net.WebUtility]::HtmlEncode($r.FixedIn) } else { $noFixHtml }
        $titleAttr = 'Ouvrir l''avis de sécurité'
        $urlCell = if ($r.Url) { "<a href=`"$($r.Url)`" target=`"_blank`" rel=`"noopener`" title=`"$titleAttr`">$([System.Net.WebUtility]::HtmlEncode($r.VulnId))</a>" } else { [System.Net.WebUtility]::HtmlEncode($r.VulnId) }
        $descCell = if ($r.Description) { [System.Net.WebUtility]::HtmlEncode($r.Description) } else { "<em>—</em>" }
        $rows += "        <tr class=`"severity-$class`"><td>$([System.Net.WebUtility]::HtmlEncode($r.PkgName))</td><td>$([System.Net.WebUtility]::HtmlEncode($r.PkgVersion))</td><td>$([System.Net.WebUtility]::HtmlEncode($r.PkgType))</td><td>$urlCell</td><td><span class=`"badge $class`">$sev</span></td><td>$fix</td><td class=`"desc`">$descCell</td></tr>`n"
    }
}

if ($rows -eq "") {
    $rows = "        <tr><td colspan=`"7`">Aucune vulnérabilité trouvée.</td></tr>"
}

$html = @"
<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Rapport vulnérabilités – Grype</title>
  <style>
    :root { --critical: #c0392b; --high: #e74c3c; --medium: #f39c12; --low: #3498db; --negligible: #95a5a6; }
    body { font-family: 'Segoe UI', system-ui, sans-serif; margin: 1rem 2rem; background: #f8f9fa; color: #212529; }
    h1 { font-size: 1.5rem; margin-bottom: 0.25rem; }
    .meta { color: #6c757d; font-size: 0.9rem; margin-bottom: 1rem; }
    table { border-collapse: collapse; width: 100%; background: #fff; box-shadow: 0 1px 3px rgba(0,0,0,.08); border-radius: 8px; overflow: hidden; }
    th, td { padding: 0.6rem 0.75rem; text-align: left; border-bottom: 1px solid #dee2e6; }
    th { background: #343a40; color: #fff; font-weight: 600; }
    tr:hover { background: #f1f3f5; }
    .badge { display: inline-block; padding: 0.2rem 0.5rem; border-radius: 4px; font-size: 0.8rem; font-weight: 600; }
    .badge.critical { background: var(--critical); color: #fff; }
    .badge.high { background: var(--high); color: #fff; }
    .badge.medium { background: var(--medium); color: #fff; }
    .badge.low { background: var(--low); color: #fff; }
    .badge.negligible { background: var(--negligible); color: #fff; }
    tr.severity-critical { border-left: 3px solid var(--critical); }
    tr.severity-high { border-left: 3px solid var(--high); }
    a { color: #0d6efd; text-decoration: none; }
    a:hover { text-decoration: underline; }
    .summary { background: #e7f1ff; padding: 0.5rem 0.75rem; border-radius: 6px; margin-bottom: 0.5rem; }
    .help { color: #6c757d; font-size: 0.85rem; margin-bottom: 1rem; }
    .no-fix { color: #856404; font-style: italic; }
    td.desc { max-width: 320px; font-size: 0.9rem; }
  </style>
</head>
<body>
  <h1>Rapport de vuln&#233;rabilit&#233;s (Grype)</h1>
  <p class="meta">Cible: $sourceTarget | Grype $grypeVersion | Généré le $date</p>
  <p class="summary"><strong>$($matches.Count) vulnérabilité(s)</strong> — $summaryText</p>
  <p class="help">Cliquez sur l'identifiant (GHSA-… ou CVE-…) pour ouvrir l'avis de sécurité et les détails.</p>
  <table>
    <thead>
      <tr>
        <th>Paquet</th>
        <th>Version</th>
        <th>Type</th>
        <th>Vulnérabilité</th>
        <th>Sévérité</th>
        <th>Correction (fixed in)</th>
        <th>Description</th>
      </tr>
    </thead>
    <tbody>
$rows    </tbody>
  </table>
</body>
</html>
"@

$outDir = Split-Path -Parent $Sortie
if ($outDir -and -not (Test-Path $outDir)) { New-Item -ItemType Directory -Force -Path $outDir | Out-Null }
[System.IO.File]::WriteAllText((Join-Path $ProjetRoot $Sortie), $html, [System.Text.UTF8Encoding]::new($false))
Write-Host "Rapport genere: $Sortie" -ForegroundColor Green
Write-Host "  Matches: $($matches.Count)" -ForegroundColor Gray
