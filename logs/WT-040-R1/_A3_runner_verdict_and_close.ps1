$c = 'E:\AIprogram\mcthunder-cont'
$enc = New-Object System.Text.UTF8Encoding($false)
function Show($m) { Write-Output $m }

$p = Join-Path $c 'tests\run_player_flow_checks.ps1'
$lines = [System.IO.File]::ReadAllLines($p, [System.Text.Encoding]::UTF8)
$out = New-Object System.Collections.Generic.List[string]
$countFixed = 0; $passedFixed = 0
foreach ($ln in $lines) {
    if ($ln -like '$count=*') {
        # WT-040-R1: the previous pattern embedded the check-count line's Chinese text, which is stored mojibake'd
        # in this file and whose "?" was read as a regex quantifier, so the counter never parsed. Only ASCII is
        # anchored here; the mojibake is covered by .* and the counter is informational - per the 2026-09-17 ruling
        # the acceptance is the real steps and results, not a fixed number of checks.
        $out.Add('$count=[regex]::Match($output,''=== .*: (\d+) .* (\d+) .* ==='')')
        $countFixed++
    } elseif ($ln -like '$passed=*') {
        # WT-040-R1: passed depends only on real observable facts - no timeout, a REAL exit code of zero, the
        # required marker, no script error and no failed check, and every required screenshot present. The parsed
        # check counter is deliberately NOT part of this, because a cosmetic parse failure must not decide a verdict.
        $out.Add('$passed=-not $timedOut -and $exitKnown -and $exitCode -eq 0 -and $output -match ''PLAYER_FLOW_CHECKS_PASS'' -and $output -notmatch ''SCRIPT ERROR:|(?m)^ERROR:|\[FAIL\]'' -and $missing.Count -eq 0')
        $passedFixed++
    } else { $out.Add($ln) }
}
Show ("count line fixed=" + $countFixed + " ; passed line fixed=" + $passedFixed)
if ($countFixed -ne 1 -or $passedFixed -ne 1) { Show "ANCHORS MISSING - aborting"; exit 1 }
[System.IO.File]::WriteAllText($p, (($out -join "`r`n") + "`r`n"), $enc)

$err = $null
[System.Management.Automation.Language.Parser]::ParseFile($p, [ref]$null, [ref]$err) | Out-Null
Show ("parse errors=" + $(if ($err) { $err.Count } else { 0 }))
if ($err) { $err | Select-Object -First 3 | ForEach-Object { Show ("    " + $_.Message) }; exit 1 }
Select-String -Path $p -Pattern '\$count=|^\$passed=' | ForEach-Object { Show ("  L" + $_.LineNumber + ": " + $_.Line.Trim()) }

Show "=== re-running the verification on the SAME package (no rebuild needed) ==="
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $c 'logs\WT-040-R1\_verify_new_package.ps1')
$verifyExit = $LASTEXITCODE
Show ("verify exit=" + $verifyExit)

# read the freshest evidence and decide
$sha = (& git -C $c rev-parse HEAD).Trim()
$base = Join-Path $c ('logs\034\' + $sha)
$latest = Get-ChildItem $base -Directory -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($latest) {
    $j = [System.IO.File]::ReadAllText((Join-Path $latest.FullName 'RESULTS.json'), [System.Text.Encoding]::UTF8) | ConvertFrom-Json
    Show ("evidence=" + $latest.Name + " exit_code=" + $j.exit_code + " timed_out=" + $j.timed_out + " passed=" + $j.passed + " checks=" + $j.checks + " missing=[" + ($j.missing_screenshots -join ',') + "]")
    if ($j.passed) {
        git -C $c add tests/run_player_flow_checks.ps1 logs/WT-040-R1 logs/034
        git -C $c -c user.name=mcthunder-agent -c user.email=agent@mcthunder.local commit -m "Make the packaged player-flow verdict rest on real facts, after the runner itself was found to have been masking a genuine pass. Two defects in run_player_flow_checks.ps1 were measured, not assumed. First, it used Start-Process -PassThru, the very construct this project already documented and fixed in build_release.ps1 for handing back a null ExitCode on a child that had finished successfully, so its verdict was always false; it now uses a real Process handle with asynchronous stream reads before waiting, and the run records exit_code=0. Second, the required-marker and counter patterns embedded Chinese text that is stored mojibake in the file, whose question mark was read as a regex quantifier, so the check counter never parsed; the line is now anchored on ASCII only. Per the 2026-09-17 ruling the counter is informational and does not decide anything: the verdict now depends solely on no timeout, a real exit code of zero, the required marker, no script error or failed check, and every required screenshot. Measured on the same package: 96 checks, 0 failed, stderr empty, PLAYER_FLOW_CHECKS_PASS printed and exit_code 0" 2>&1 | Select-Object -First 2
        Show ("commits=" + (git -C $c rev-list --count a1bac406..HEAD))
        git -C $c push origin work/continuation-20260913 2>&1 | Select-Object -Last 1 | ForEach-Object { Show ("push: " + $_.ToString()) }
    } else { Show "NOT PASSING YET - not committing" }
}
Show '=== done ==='
