$c = 'E:\AIprogram\mcthunder-cont'
$enc = New-Object System.Text.UTF8Encoding($false)
function Show($m) { Write-Output $m }

$f = 'tests/run_suite_checks.ps1'
$p = Join-Path $c $f
$g = & git -C $c show ("HEAD:" + $f)
[System.IO.File]::WriteAllText($p, (($g -join "`r`n") + "`r`n"), $enc)
Show "restored run_suite_checks.ps1 from HEAD"
$t = [System.IO.File]::ReadAllText($p, [System.Text.Encoding]::UTF8)
$nl = if ($t.Contains("`r`n")) { "`r`n" } else { "`n" }
$ok = $true

$oldA = @'
    $process = Start-Process -FilePath $engine -ArgumentList $step.Args -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
'@
$newA = @'
    # WT-040-R1: a real Process handle with redirected streams, read asynchronously before waiting, so every
    # suite's exit_code is the child's own status instead of the $null that Start-Process -PassThru can hand
    # back - the same defect this project already documented and fixed in build_release.ps1. The verdict itself
    # is unchanged: $passed below never consulted $exitCode, so this only makes the recorded exit code real.
    $psi=[System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName=$engine
    $psi.Arguments=$step.Args
    $psi.WorkingDirectory=$projectRoot
    $psi.UseShellExecute=$false
    $psi.RedirectStandardOutput=$true
    $psi.RedirectStandardError=$true
    $psi.CreateNoWindow=$true
    $process=[System.Diagnostics.Process]::new()
    $process.StartInfo=$psi
    [void]$process.Start()
    $outTask=$process.StandardOutput.ReadToEndAsync()
    $errTask=$process.StandardError.ReadToEndAsync()
'@
$nA = ([regex]::Matches($t, [regex]::Escape($oldA.TrimEnd("`r","`n").Replace("`n",$nl)))).Count
Show ("  A process start x" + $nA)
if ($nA -eq 1) { $t = $t.Replace($oldA.TrimEnd("`r","`n").Replace("`n",$nl), $newA.TrimEnd("`r","`n").Replace("`n",$nl)) } else { $ok = $false }

$oldB = @'
    $process.WaitForExit()
    $outputRead = Read-SuiteLog -Path $stdout
'@
$newB = @'
    $process.WaitForExit()
    [IO.File]::WriteAllText($stdout,$outTask.GetAwaiter().GetResult())
    [IO.File]::WriteAllText($stderr,$errTask.GetAwaiter().GetResult())
    $outputRead = Read-SuiteLog -Path $stdout
'@
$nB = ([regex]::Matches($t, [regex]::Escape($oldB.TrimEnd("`r","`n").Replace("`n",$nl)))).Count
Show ("  B log write x" + $nB)
if ($nB -eq 1) { $t = $t.Replace($oldB.TrimEnd("`r","`n").Replace("`n",$nl), $newB.TrimEnd("`r","`n").Replace("`n",$nl)) } else { $ok = $false }

$oldC = '    $exitCode = $process.ExitCode'
$newC = @'
    # WT-040-R1: a null status is named instead of being written silently as an empty field.
    try { $exitCode = $process.ExitCode } catch { $exitCode = $null }
    if ($null -eq $exitCode) { Write-Output ("{0}: exit_code=UNKNOWN (the child did not report one)" -f $step.Name) }
'@
$nC = ([regex]::Matches($t, [regex]::Escape($oldC))).Count
Show ("  C exit code x" + $nC)
if ($nC -eq 1) { $t = $t.Replace($oldC, $newC.TrimEnd("`r","`n").Replace("`n",$nl)) } else { $ok = $false }

[System.IO.File]::WriteAllText($p, $t, $enc)
if (-not $ok) { Show "ANCHOR MISSED - aborting"; exit 1 }
$err=$null
[System.Management.Automation.Language.Parser]::ParseFile($p, [ref]$null, [ref]$err) | Out-Null
Show ("parse errors=" + $(if ($err) { $err.Count } else { 0 }))
if ($err) { $err | Select-Object -First 3 | ForEach-Object { Show ("    " + $_.Message) }; exit 1 }

Show "=== verify on one suite: exit code must now be real, and the verdict must be unchanged ==="
$sl = Join-Path $c 'logs\WT-040-R1\exitcode-verify.log'
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $c 'tests\run_suite_checks.ps1') -Suites run_checks *> $sl
Get-Content $sl | Select-String 'run_checks:|UNKNOWN' | ForEach-Object { Show ("  " + $_.Line.Trim()) }
$line = (Get-Content $sl | Select-String 'run_checks:').Line
$realExit = $line -match 'run_checks: checks=\d+ exit=\d+ passed='
$passOk = $line -match 'passed=True'
Show ("real exit code present=" + $realExit + " ; passed=True=" + $passOk)
if (-not $realExit -or -not $passOk) { Show "NOT VERIFIED - not committing"; exit 1 }

git -C $c add tests/run_suite_checks.ps1 logs/WT-040-R1
git -C $c -c user.name=mcthunder-agent -c user.email=agent@mcthunder.local commit -m "Record a real exit code for every suite, which the user-facing standard requires, without changing any verdict. run_suite_checks.ps1 still used Start-Process -PassThru, the construct this project already documented and fixed in build_release.ps1 for handing back a null ExitCode on a child that had finished successfully, so RESULTS.json carried an empty exit_code for every suite even though 217 checks passed. It now uses a real Process handle with redirected streams read asynchronously before waiting, writes the captured streams to the same log paths, and names a null status instead of writing it silently. The verdict is untouched: the pass condition never consulted the exit code, and this was verified before committing - the suite records a real exit code and still reports passed=True" 2>&1 | Select-Object -First 2
Show ("commits=" + (git -C $c rev-list --count a1bac406..HEAD))
git -C $c push origin work/continuation-20260913 2>&1 | Select-Object -Last 1 | ForEach-Object { Show ("push: " + $_.ToString()) }
git -C $c diff --quiet HEAD; Show ("clean-check exit=" + $LASTEXITCODE)

Show "=== candidate build (run_checks is now stable, so the register should pass) ==="
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $c 'tests\build_release.ps1') -Candidate
Show ("build exit=" + $LASTEXITCODE)
