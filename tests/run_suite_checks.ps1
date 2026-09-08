param(
    [string[]]$Suites = @('run_checks','run_layout_checks','run_query_checks','run_projectile_checks','run_armor_checks','run_damage_checks','run_recovery_checks','run_replay_checks','run_core_checks','run_drive_checks','run_ai_drive_checks','run_ai_combat_checks','run_duel_checks','run_team_checks','run_hud_checks','run_map_checks','run_village_battle_checks'),
    [int]$TimeoutSeconds = 240,
    [string]$Order = '007'
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$engine = Join-Path $projectRoot 'tools/godot/Godot_v4.7.2-stable_win64_console.exe'
if (-not (Test-Path -LiteralPath $engine)) { throw "Fixed Godot missing: $engine" }
$sourceSha = (& git -C $projectRoot rev-parse HEAD).Trim()
$runPath = Join-Path $projectRoot ("logs/$Order/$sourceSha/" + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Force -Path $runPath | Out-Null
$engineVersion = (& $engine --version).Trim()
$summary = [System.Collections.Generic.List[object]]::new()
$steps = @(@{Name='import'; Args='--headless --path "' + $projectRoot + '" --editor --import'})
foreach ($suite in $Suites) {
    $simulationClock = if ($suite -in @('run_ai_drive_checks','run_ai_combat_checks','run_duel_checks','run_team_checks','run_hud_checks','run_map_checks','run_village_battle_checks')) { ' --fixed-fps 60' } else { '' }
    $steps += @{Name=$suite; Args='--headless --path "' + $projectRoot + '"' + $simulationClock + ' -s "res://tests/' + $suite + '.gd"'}
}
foreach ($step in $steps) {
    $stdout = Join-Path $runPath ($step.Name + '_stdout.log')
    $stderr = Join-Path $runPath ($step.Name + '_stderr.log')
    $command = '"' + $engine + '" ' + $step.Args
    $process = Start-Process -FilePath $engine -ArgumentList $step.Args -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    $timedOut = -not $process.WaitForExit($TimeoutSeconds * 1000)
    if ($timedOut) { Stop-Process -Id $process.Id -Force }
    $process.WaitForExit()
    $output = [IO.File]::ReadAllText($stdout)
    $errors = [IO.File]::ReadAllText($stderr)
    $errorLines = @([regex]::Matches($errors, '(?m)^ERROR:.*') | ForEach-Object { $_.Value.Trim() })
    $allowedErrors = @()
    if ($step.Name -eq 'run_layout_checks') {
        $allowedErrors = @(
            'ERROR: ArmorPatchMesh: triangles: winding disagrees with outward normal; triangles: winding disagrees with outward normal',
            'ERROR: LayoutCatalog: layout not found: nonexistent_layout (res://configs/layouts/nonexistent_layout.tres)',
            'ERROR: LayoutCatalog: empty layout_id'
        )
    }
    $unexpected = @($errorLines | Where-Object { $_ -notin $allowedErrors })
    foreach ($expected in $allowedErrors) {
        if (@($errorLines | Where-Object { $_ -eq $expected }).Count -ne 1) { $unexpected += "Expected exactly one negative-fixture error: $expected" }
    }
    $scriptError = ($errors + $output) -match 'SCRIPT ERROR:|Parse Error:'
    $checkMatch = [regex]::Match($output, '=== 结果: (\d+) 项检查, (\d+) 失败 ===')
    $assertionsPass = $step.Name -eq 'import' -or ($checkMatch.Success -and [int]$checkMatch.Groups[2].Value -eq 0 -and $output -match '(?m)^[A-Z_]*CHECKS_PASS\s*$')
    $passed = -not $timedOut -and $process.ExitCode -eq 0 -and -not $scriptError -and $unexpected.Count -eq 0 -and $assertionsPass
    $row = [pscustomobject]@{suite=$step.Name; source_sha=$sourceSha; engine=$engineVersion; command=$command; exit_code=$process.ExitCode; timed_out=$timedOut; checks=if($checkMatch.Success){[int]$checkMatch.Groups[1].Value}else{0}; passed=$passed; script_error=$scriptError; unexpected_errors=$unexpected; expected_error_count=$allowedErrors.Count}
    $summary.Add($row)
    $summary | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $runPath 'RESULTS.json') -Encoding utf8
    Write-Output ("{0}: checks={1} exit={2} passed={3} unexpected_errors={4}" -f $step.Name,$row.checks,$row.exit_code,$passed,$unexpected.Count)
    if ($step.Name -eq 'import' -and -not $passed) { break }
}
Write-Output ("EVIDENCE=" + $runPath)
if (@($summary | Where-Object { -not $_.passed }).Count -gt 0) { exit 1 }
exit 0
