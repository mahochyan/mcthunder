$c = 'E:\AIprogram\mcthunder-cont'
$enc = New-Object System.Text.UTF8Encoding($false)

# --- A) the shared matcher gains a SUITE LOG health check -----------------------------------------
$p = Join-Path $c 'tests\candidate_register_match.ps1'
$t = [System.IO.File]::ReadAllText($p, [System.Text.Encoding]::UTF8)
$nl = if ($t.Contains("`r`n")) { "`r`n" } else { "`n" }

$oldParam = @'
        $ResultRow = $null
    )
'@
$newParam = @'
        $ResultRow = $null,
        [string] $SuiteLogPath = ''
    )
'@
$nA = ([regex]::Matches($t, [regex]::Escape($oldParam.Replace("`n", $nl)))).Count
Write-Output ("=== matcher param  x" + $nA)
if ($nA -eq 1) { $t = $t.Replace($oldParam.Replace("`n", $nl), $newParam.Replace("`n", $nl)) }

$oldRet = @'
    return @{ ok = $true; reason = 'the failure set matches the register exactly' }
'@
$newRet = @'
    # 5) the suite's OWN log must be healthy. The regression summary does not carry the diagnostic list in
    #    every shape - the field is simply absent in the file this build writes - so the health of a run is
    #    read from the suite's stdout log, which is the same evidence the player-flow check uses and is
    #    always present. A registered failure may not travel with script errors.
    if (-not [string]::IsNullOrWhiteSpace($SuiteLogPath)) {
        if (-not (Test-Path -LiteralPath $SuiteLogPath)) {
            return @{ ok = $false; reason = "is a registered failure but its suite log is missing ($SuiteLogPath)" }
        }
        $bad = @(Select-String -LiteralPath $SuiteLogPath -Pattern 'SCRIPT ERROR|^ERROR:|Parse Error' -ErrorAction SilentlyContinue)
        if ($bad.Count -gt 0) {
            $sample = ($bad | Select-Object -First 1).Line.Trim()
            return @{ ok = $false; reason = "is a registered failure but its suite log carries $($bad.Count) script error line(s), e.g. $sample" }
        }
    }

    return @{ ok = $true; reason = 'the failure set matches the register exactly' }
'@
$nB = ([regex]::Matches($t, [regex]::Escape($oldRet.Replace("`n", $nl)))).Count
Write-Output ("=== matcher return  x" + $nB)
if ($nB -eq 1) { $t = $t.Replace($oldRet.Replace("`n", $nl), $newRet.Replace("`n", $nl)) }
[System.IO.File]::WriteAllText($p, $t, $enc)

# --- B) the build passes the suite log it already located ------------------------------------------
$pb = Join-Path $c 'tests\build_release.ps1'
$tb = [System.IO.File]::ReadAllText($pb, [System.Text.Encoding]::UTF8)
$nlb = if ($tb.Contains("`r`n")) { "`r`n" } else { "`n" }
$oldCall = '        $verdict = Test-CandidateFailureSet -Entry $entry[0] -FailLines $failLines -ResultRow $f'
$newCall = @'
        # The suite log is the evidence the build actually has for run health, so it is passed in; the log
        # lookup above already located it.
        $logPath = ''
        if ($suiteLog) { $logPath = $suiteLog.FullName }
        $verdict = Test-CandidateFailureSet -Entry $entry[0] -FailLines $failLines -ResultRow $f -SuiteLogPath $logPath
'@
$nC = ([regex]::Matches($tb, [regex]::Escape($oldCall.Replace("`n", $nlb)))).Count
Write-Output ("=== build call  x" + $nC)
if ($nC -eq 1) { $tb = $tb.Replace($oldCall.Replace("`n", $nlb), $newCall.TrimEnd("`r","`n").Replace("`n", $nlb)) }
[System.IO.File]::WriteAllText($pb, $tb, $enc)

# --- C) the negative test proves the log clause, using real temporary logs -------------------------
$pt = Join-Path $c 'tests\check_candidate_register_match.ps1'
$tt = [System.IO.File]::ReadAllText($pt, [System.Text.Encoding]::UTF8)
$nlt = if ($tt.Contains("`r`n")) { "`r`n" } else { "`n" }
$anchor = 'Write-Output ("=== result: " + $checks + " checks, " + $failed + " failed ===")'
$cases = @'
# --- the SUITE LOG clause, using real temporary files -------------------------------------------
$cleanLog = Join-Path ([IO.Path]::GetTempPath()) 'candidate_register_clean.log'
$dirtyLog = Join-Path ([IO.Path]::GetTempPath()) 'candidate_register_dirty.log'
$missingLog = Join-Path ([IO.Path]::GetTempPath()) 'candidate_register_absent.log'
Set-Content -LiteralPath $cleanLog -Value @('=== result: 16 checks, 1 failed ===','[FAIL] at least three actual slots from each team physically reach central approaches') -Encoding utf8
Set-Content -LiteralPath $dirtyLog -Value @('=== result: 16 checks, 1 failed ===','SCRIPT ERROR: Invalid access to property or key x on a base object') -Encoding utf8
if (Test-Path -LiteralPath $missingLog) { Remove-Item -LiteralPath $missingLog -Force }
$v = Test-CandidateFailureSet -Entry $entryBattle -FailLines @($old) -ResultRow $healthy -SuiteLogPath $cleanLog
Check $v.ok "a CLEAN suite log still accepts the registered failure (reason: $($v.reason))"
$v = Test-CandidateFailureSet -Entry $entryBattle -FailLines @($old) -ResultRow $healthy -SuiteLogPath $dirtyLog
Check (-not $v.ok) "COUNTER-EXAMPLE 2d refused: a registered failure whose SUITE LOG carries a script error (reason: $($v.reason))"
$v = Test-CandidateFailureSet -Entry $entryBattle -FailLines @($old) -ResultRow $healthy -SuiteLogPath $missingLog
Check (-not $v.ok) "a MISSING suite log refuses the registered failure instead of assuming health (reason: $($v.reason))"

Write-Output ("=== result: " + $checks + " checks, " + $failed + " failed ===")
'@
$nD = ([regex]::Matches($tt, [regex]::Escape($anchor.Replace("`n", $nlt)))).Count
Write-Output ("=== test cases  x" + $nD)
if ($nD -eq 1) { $tt = $tt.Replace($anchor.Replace("`n", $nlt), $cases.TrimEnd("`r","`n").Replace("`n", $nlt)) }
[System.IO.File]::WriteAllText($pt, $tt, $enc)

foreach ($f in @('tests\candidate_register_match.ps1','tests\check_candidate_register_match.ps1','tests\build_release.ps1')) {
    $err = $null
    [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $c $f), [ref]$null, [ref]$err) | Out-Null
    Write-Output ("  {0,-40} parse errors={1}" -f (Split-Path $f -Leaf), $(if ($err) { $err.Count } else { 0 }))
    if ($err) { $err | Select-Object -First 3 | ForEach-Object { Write-Output ("      " + $_.Message) } }
}
Write-Output '=== patch6 done ==='
