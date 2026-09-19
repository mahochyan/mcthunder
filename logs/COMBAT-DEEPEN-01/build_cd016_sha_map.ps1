# CD16 stage one: bind every sub-order to the commit that last touched its evidence and its result document.
# Written as a file rather than an inline command because the inline form hit two PowerShell 5.1 traps at once:
# `if` is not an expression, and Set-Content -Encoding UTF8 writes a BOM that JSON.parse refuses.
param([string]$ProjectRoot = 'E:\AIprogram\mcthunder-cont')
$ErrorActionPreference = 'Stop'
Set-Location $ProjectRoot
$map = [ordered]@{}
for ($i = 1; $i -le 16; $i++) {
    $d = '{0:d3}' -f $i
    $sub = 'CD' + ('{0:d2}' -f $i)
    $ev = "docs/wt/continuation/COMBAT_DEEPEN01_CD$d`_EVIDENCE.md"
    $re = "docs/wt/continuation/COMBAT_DEEPEN01_CD$d`_RESULTS.json"
    $evidenceSha = (git log -1 --format='%H' -- $ev)
    $resultsSha = $null
    if (Test-Path -LiteralPath $re) { $resultsSha = (git log -1 --format='%H' -- $re) }
    $entry = [ordered]@{
        sub_order    = $sub
        evidence     = $ev
        evidence_sha = $evidenceSha
        results      = $re
        results_sha  = $resultsSha
    }
    $map[$sub] = $entry
}
$json = $map | ConvertTo-Json -Depth 5
[System.IO.File]::WriteAllText((Join-Path $ProjectRoot 'logs/COMBAT-DEEPEN-01/cd016_evidence_shas.json'), $json, (New-Object System.Text.UTF8Encoding($false)))
foreach ($k in $map.Keys) {
    $e = $map[$k]
    $rs = '-'
    if ($e.results_sha) { $rs = $e.results_sha.Substring(0, 8) }
    Write-Output ($k + ' ev=' + $e.evidence_sha.Substring(0, 8) + ' res=' + $rs)
}
Write-Output ('ORDERS=' + $map.Count)
