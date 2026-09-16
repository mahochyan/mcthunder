$c = 'E:\AIprogram\mcthunder-cont'
$enc = New-Object System.Text.UTF8Encoding($false)

# --- A) the matcher: split by TYPE. Single-quoted here-strings only, so no escaping can break the script.
$p = Join-Path $c 'tests\candidate_register_match.ps1'
$t = [System.IO.File]::ReadAllText($p, [System.Text.Encoding]::UTF8)
$nl = if ($t.Contains("`r`n")) { "`r`n" } else { "`n" }
$old = @'
            $unexpected = @($ResultRow.unexpected_errors | Where-Object { $null -ne $_ -and "$_" -ne '' })
            if ($unexpected.Count -ne 0) { return @{ ok = $false; reason = "is a registered failure but its run also reported $($unexpected.Count) unexpected script error(s)" } }
'@
$new = @'
            # Split by TYPE: the runner writes an ARRAY of diagnostic lines, while an empty result may
            # serialise as the number 0. Treating every non-null value as one diagnostic rejected healthy
            # runs, which the negative test caught - and the test now covers both shapes for that reason.
            $raw = $ResultRow.unexpected_errors
            $unexpected = 0
            if ($null -ne $raw) {
                if ($raw -is [string]) { if ($raw -ne '') { $unexpected = 1 } }
                elseif ($raw -is [System.Collections.IEnumerable]) { $unexpected = @($raw | Where-Object { $null -ne $_ -and "$_" -ne '' }).Count }
                else { $unexpected = [int]$raw }
            }
            if ($unexpected -ne 0) { return @{ ok = $false; reason = "is a registered failure but its run also reported $unexpected unexpected script error(s)" } }
'@
$n = ([regex]::Matches($t, [regex]::Escape($old.Replace("`n", $nl)))).Count
Write-Output ("=== matcher filter  x" + $n)
if ($n -eq 1) { $t = $t.Replace($old.Replace("`n", $nl), $new.Replace("`n", $nl)); [System.IO.File]::WriteAllText($p, $t, $enc) }

# --- B) the admission check must also load the engineering vehicles explicitly.
$p2 = Join-Path $c 'tests\check_engineering_admission.gd'
$t2 = [System.IO.File]::ReadAllText($p2, [System.Text.Encoding]::UTF8)
$nl2 = if ($t2.Contains("`r`n")) { "`r`n" } else { "`n" }
$ins = @'
	var engineering: Dictionary = catalog.load_engineering(defs)
	for e in engineering.get("errors",[]): print("[admit]   ! ",str(e))
'@
$ins = $ins.TrimEnd("`r","`n").Replace("`n", $nl2)
$needle2 = 'catalog.load_all(defs)'
$n2 = ([regex]::Matches($t2, [regex]::Escape($needle2))).Count
Write-Output ("=== admission load_all  x" + $n2)
if ($n2 -eq 1) {
    $eol = $t2.IndexOf("`n", $t2.IndexOf($needle2))
    if ($eol -lt 0) { $eol = $t2.Length - 1 }
    $t2 = $t2.Substring(0, $eol + 1) + $ins + $nl2 + $t2.Substring($eol + 1)
    [System.IO.File]::WriteAllText($p2, $t2, $enc)
}

foreach ($f in @('tests\candidate_register_match.ps1','tests\check_candidate_register_match.ps1')) {
    $err = $null
    [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $c $f), [ref]$null, [ref]$err) | Out-Null
    Write-Output ("  {0,-40} parse errors={1}" -f (Split-Path $f -Leaf), $(if ($err) { $err.Count } else { 0 }))
}
Write-Output '=== patch5 done ==='
