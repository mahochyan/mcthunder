$c='E:\AIprogram\mcthunder-cont'
$g='E:\AIprogram\mcthunder\tools\Godot_v4.7.2-stable_win64_console.exe'
$L="$c\logs\COMBAT-DEEPEN-01"
'=== a REAL green slice at the committed state (engine path set BEFORE use) ==='
'  engine exists=' + (Test-Path $g)
foreach ($p in @(@('run_damage_checks','gd-damage'),@('run_recovery_checks','gd-recovery'),@('run_cd008_scene_checks','gd-scenes'),@('run_historical_checks','gd-hist'))) {
  & $g --headless --path $c --fixed-fps 60 -s ("res://tests/" + $p[0] + ".gd") *> "$L\$($p[1]).log"
  $o = Get-Content "$L\$($p[1]).log" -ErrorAction SilentlyContinue
  '  {0,-28} exit={1} PASS={2,4} FAIL={3} ERR={4}' -f $p[0],$LASTEXITCODE,@($o|Select-String '^\[PASS\]').Count,@($o|Select-String '^\[FAIL\]').Count,@($o|Select-String '^\s*SCRIPT ERROR').Count
  @($o|Select-String 'CD08_SCENES|^\[FAIL\]') | Select-Object -First 2 | ForEach-Object { '      ' + $_.Line.Trim().Substring(0,[Math]::Min(150,$_.Line.Trim().Length)) }
}
'=== CD09 stage 0: the order definition and its six cases, quoted ==='
$o2="$c\docs\wt\combat-deepen-01\original"
$wo = Get-Content "$o2\07_WORK_ORDERS.json" -Raw -Encoding UTF8 | ConvertFrom-Json
$w9 = @($wo.items) | Where-Object { [string]$_.id -eq 'WT-CD-009' } | Select-Object -First 1
if ($w9) {
  $w9.PSObject.Properties | ForEach-Object {
    $v = ($_.Value | Out-String).Trim() -replace "`r?`n",' / '
    '  ' + $_.Name.PadRight(24) + ' = ' + $v.Substring(0,[Math]::Min(240,$v.Length))
  }
}
$ac = Get-Content "$o2\08_ACCEPTANCE_CASES.json" -Raw -Encoding UTF8 | ConvertFrom-Json
@($ac.cases | Where-Object { [string]$_.id -like 'CD09-*' }) | ForEach-Object {
  '  --- ' + [string]$_.id + ' | ' + [string]$_.title
  '      action   : ' + [string]$_.action
  '      expected : ' + [string]$_.expected
}
