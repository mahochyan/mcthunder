$c='E:\AIprogram\mcthunder-cont'
$g='E:\AIprogram\mcthunder\tools\godot\Godot_v4.7.2-stable_win64_console.exe'
$L="$c\logs\COMBAT-DEEPEN-01"

# ① 新增 HE 族（source/effect 必须成对 ✓ 与既有族同构 ✓）
$p1="$c\scripts\content\vehicle_shell_catalog.gd"
$t1 = Get-Content $p1 -Raw -Encoding UTF8
$a1 = '"APFSDS":{"source":"game_rule_apfsds","effect":"long_rod"},"HEAT":{"source":"heat_fs_tank","effect":"chemical"}}'
$b1 = '"APFSDS":{"source":"game_rule_apfsds","effect":"long_rod"},"HEAT":{"source":"heat_fs_tank","effect":"chemical"},
	# CD07: an external HE blast is its own family, so its source type and effect must be declared as a pair like every
	# other family rather than relabelled from one of them.
	"HE":{"source":"he_tank","effect":"he_blast"}}'
$n1 = ([regex]::Matches($t1,[regex]::Escape($a1))).Count
$t1 = $t1.Replace($a1,$b1)
[IO.File]::WriteAllText($p1, $t1, (New-Object Text.UTF8Encoding($false)))
"  family_edit=$n1 ; HE_family=" + $t1.Contains('"HE":{"source":"he_tank","effect":"he_blast"}')

# ② 弹条目补齐 family / source_bullet_type（并让 effect 与族一致 ✓）
$p2="$c\configs\shells\historical_loadouts.json"
$t2 = Get-Content $p2 -Raw -Encoding UTF8
$a2 = @'
      "caliber_mm": 75,
      "effect_policy": "he_blast",
'@
$b2 = @'
      "caliber_mm": 75,
      "family": "HE",
      "source_bullet_type": "he_tank",
      "effect_policy": "he_blast",
'@
$n2 = ([regex]::Matches($t2,[regex]::Escape($a2))).Count
$t2 = $t2.Replace($a2,$b2)
[IO.File]::WriteAllText($p2, $t2, (New-Object Text.UTF8Encoding($false)))
"  shell_edit=$n2 ; family_field=" + $t2.Contains('"family": "HE"')
$j = Get-Content $p2 -Raw -Encoding UTF8 | ConvertFrom-Json
"  json_ok ; he family=" + [string]$j.shells.he_75_m3_eng.family + " ; source=" + [string]$j.shells.he_75_m3_eng.source_bullet_type + " ; effect=" + [string]$j.shells.he_75_m3_eng.effect_policy

& $g --headless --path $c --check-only --script res://tests/probe_cd007_he_limit.gd *> "$L\parse-hel2.log" 2>&1 | Out-Null
"  parse_errors=" + @(Get-Content "$L\parse-hel2.log" | Select-String 'Parse Error|Compile Error').Count
$job = Start-Job -ScriptBlock { param($g,$c,$L) & $g --headless --path $c --fixed-fps 60 -s res://tests/probe_cd007_he_limit.gd *> "$L\cd007-hel2.log" } -ArgumentList $g,$c,$L
$done = Wait-Job $job -Timeout 400
if (-not $done) { Stop-Job $job; "  timeout" } else { "  done" }
Remove-Job $job
Get-Content "$L\cd007-hel2.log" -Encoding UTF8 -ErrorAction SilentlyContinue | Select-String 'CD07 HE|=== 结果|CD07_HE_LIMIT_AND_FIRE|^\[FAIL\]' | ForEach-Object { "  " + $_.Line.Trim().Substring(0,[Math]::Min(240,$_.Line.Trim().Length)) }
