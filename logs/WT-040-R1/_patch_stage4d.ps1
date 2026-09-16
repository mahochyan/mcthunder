$c = 'E:\AIprogram\mcthunder-cont'
$enc = New-Object System.Text.UTF8Encoding($false)

# --- A) the matcher: split by TYPE, so a numeric 0 and an empty array both mean "healthy" -----------
$p = Join-Path $c 'tests\candidate_register_match.ps1'
$t = [System.IO.File]::ReadAllText($p, [System.Text.Encoding]::UTF8)
$nl = if ($t.Contains("`r`n")) { "`r`n" } else { "`n" }
$old = @'
            $unexpected = @($ResultRow.unexpected_errors | Where-Object { $null -ne $_ -and "$_" -ne '' })
            if ($unexpected.Count -ne 0) { return @{ ok = $false; reason = "is a registered failure but its run also reported $($unexpected.Count) unexpected script error(s)" } }
'@
$new = @'
            # Split by TYPE: the runner writes an ARRAY of diagnostic lines, but an empty result may serialise
            # as the number 0. Treating every non-null value as one diagnostic rejected healthy runs, which the
            # test caught - and the test now covers both shapes for exactly this reason.
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
Write-Output ("=== candidate_register_match.ps1 filter  x" + $n)
if ($n -eq 1) { $t = $t.Replace($old.Replace("`n", $nl), $new.Replace("`n", $nl)); [System.IO.File]::WriteAllText($p, $t, $enc) }

# --- B) the admission check: also load the engineering vehicles explicitly ------------------------
$p2 = Join-Path $c 'tests\check_engineering_admission.gd'
$t2 = [System.IO.File]::ReadAllText($p2, [System.Text.Encoding]::UTF8)
$nl2 = if ($t2.Contains("`r`n")) { "`r`n" } else { "`n" }
$old2 = 'catalog.load_all(defs)'
$new2 = "catalog.load_all(defs)$nl2`tvar engineering: Dictionary = catalog.load_engineering(defs)$nl2`tfor e in engineering.get(``"errors``",[]): print(``"[admit]   ! ``",str(e))"
$n2 = ([regex]::Matches($t2, [regex]::Escape($old2))).Count
Write-Output ("=== check_engineering_admission.gd load_all  x" + $n2)
if ($n2 -eq 1) { $t2 = $t2.Replace($old2, $new2); [System.IO.File]::WriteAllText($p2, $t2, $enc) }

# --- parse checks ---------------------------------------------------------------------------------
foreach ($f in @('tests\candidate_register_match.ps1','tests\check_candidate_register_match.ps1')) {
    $err = $null
    [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $c $f), [ref]$null, [ref]$err) | Out-Null
    Write-Output ("  {0,-40} parse errors={1}" -f (Split-Path $f -Leaf), $(if ($err) { $err.Count } else { 0 }))
}
Write-Output '=== patch4 done ==='
