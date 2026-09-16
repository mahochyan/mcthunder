$c = 'E:\AIprogram\mcthunder-cont'
foreach ($id in 'ussr_t_80b','germ_leopard_2a4') {
    $p = Join-Path $c "assets\reference_data\candidates\$id.json"
    $j = [System.IO.File]::ReadAllText($p, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
    Write-Output ("=== {0} : fields {1} entries ===" -f $id, @($j.fields).Count)
    foreach ($f in @($j.fields)) {
        $cv = $f.candidate_value
        if ($null -eq $cv) { $cvs = '(null)' } else { $cvs = ($cv | ConvertTo-Json -Compress -Depth 2) }
        if ($cvs.Length -gt 70) { $cvs = $cvs.Substring(0, 70) }
        Write-Output ("  {0,-34} cand={1,-38} state={2} adm={3} hist={4}" -f [string]$f.key, $cvs, [string]$f.resolution_state, [string]$f.runtime_admitted, [string]$f.historical_verified)
    }
}
