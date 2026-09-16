$c = 'E:\AIprogram\mcthunder-cont'
$enc = New-Object System.Text.UTF8Encoding($false)
function Show($m) { Write-Output $m }
$ok = $true

# --- 1) TeamRange: an explicit, default-off scenario hook for the opposing team's type ---------------------
$f1 = 'scripts/battle/team_range.gd'
$p1 = Join-Path $c $f1
$t1 = [System.IO.File]::ReadAllText($p1, [System.Text.Encoding]::UTF8)
$nl1 = if ($t1.Contains("`r`n")) { "`r`n" } else { "`n" }
$old1 = 'var respawn_vehicle_id := ""'
$new1 = @'
var respawn_vehicle_id := ""
## WT-040-R1 (2026-09-17 ruling, work order D/C): an explicit ENGINEERING SCENARIO hook, empty by default so
## nothing changes unless a test or an internal engineering entry sets it. It assigns the OPPOSING team's vehicle
## type so one internal match can field T-80B against Leopard 2A4, which is what the ruling asks the modern river
## record to show. It changes team composition only - no ticket, capture, damage, reload or termination rule is
## touched, and an unknown id is still refused by the readiness gate.
var opposing_engineering_id := ""
'@
$n1 = ([regex]::Matches($t1, [regex]::Escape($old1))).Count
Show ("  scenario hook anchor x" + $n1)
if ($n1 -eq 1) { $t1 = $t1.Replace($old1, $new1.TrimEnd("`r","`n").Replace("`n",$nl1)) } else { $ok = $false }

$old2 = @'
		else:
			requested = selected_vehicle_id
'@
$new2 = @'
		else:
			requested = selected_vehicle_id
		# The engineering scenario hook, when set, gives the opposing team the other modern type. It is applied
		# AFTER the rotation decision and only for AI slots, and the readiness gate still decides whether that id
		# may fight at all.
		if not opposing_engineering_id.is_empty() and id != "A":
			requested = opposing_engineering_id
'@
$n2 = ([regex]::Matches($t1, [regex]::Escape($old2.TrimEnd("`r","`n").Replace("`n",$nl1)))).Count
Show ("  opposing hook anchor x" + $n2)
if ($n2 -eq 1) { $t1 = $t1.Replace($old2.TrimEnd("`r","`n").Replace("`n",$nl1), $new2.TrimEnd("`r","`n").Replace("`n",$nl1)) } else { $ok = $false }
[System.IO.File]::WriteAllText($p1, $t1, $enc)

# --- 2) the recorder: accept a vehicle id and an opposing id, and record them -------------------------------
$f2 = 'tests/record_river_ai_match.gd'
$p2 = Join-Path $c $f2
$t2 = [System.IO.File]::ReadAllText($p2, [System.Text.Encoding]::UTF8)
$nl2 = if ($t2.Contains("`r`n")) { "`r`n" } else { "`n" }
$old3 = '	scene.selected_vehicle_id = VehicleCatalog.IDS[0]'
$new3 = @'
	# WT-040-R1 (2026-09-17 ruling): the original historical record is preserved by default; a vehicle id (and an
	# optional opposing id) may be passed on the command line so the same recorder can produce the modern
	# two-vehicle record that the ruling asks for after the engineering wiring was completed.
	var wanted := "res://tests/record_river_ai_match.gd"
	var args := OS.get_cmdline_user_args()
	var chosen := VehicleCatalog.IDS[0]
	var opposing := ""
	for i in args.size():
		if args[i] == "--vehicle" and i + 1 < args.size(): chosen = str(args[i+1])
		if args[i] == "--opposing" and i + 1 < args.size(): opposing = str(args[i+1])
	scene.selected_vehicle_id = chosen
	scene.opposing_engineering_id = opposing
	print("[river-record] selected vehicle=", chosen, " opposing=", (opposing if not opposing.is_empty() else "(same as selected)"))
'@
$n3 = ([regex]::Matches($t2, [regex]::Escape($old3))).Count
Show ("  recorder vehicle anchor x" + $n3)
if ($n3 -eq 1) { $t2 = $t2.Replace($old3, $new3.TrimEnd("`r","`n").Replace("`n",$nl2)) } else { $ok = $false }

$old4 = '		"map_id": MAP_ID,'
$new4 = @'
		"map_id": MAP_ID,
		"selected_vehicle_id": chosen,
		"opposing_vehicle_id": opposing,
		"scenario": "internal engineering entry (engineering_candidate / combat_admitted=false); team composition only, no rule change",
'@
$n4 = ([regex]::Matches($t2, [regex]::Escape($old4))).Count
Show ("  record fields anchor x" + $n4)
if ($n4 -eq 1) { $t2 = $t2.Replace($old4, $new4.TrimEnd("`r","`n").Replace("`n",$nl2)) } else { $ok = $false }
[System.IO.File]::WriteAllText($p2, $t2, $enc)

if (-not $ok) { Show "ANCHOR MISSED - aborting"; exit 1 }

$g = 'E:\AIprogram\mcthunder\tools\godot\Godot_v4.7.2-stable_win64_console.exe'
foreach ($pair in @(@($f1,'team_range.gd'), @($f2,'record_river_ai_match.gd'))) {
    & $g --headless --path $c --check-only --script ('res://' + $pair[0]) *> (Join-Path $c 'logs\WT-040-R1\chkR.log') 2>&1 | Out-Null
    $perr = @(Get-Content (Join-Path $c 'logs\WT-040-R1\chkR.log') | Select-String 'Parse Error|Compile Error').Count
    Show ("  parse " + $pair[1] + " errors=" + $perr)
    if ($perr -gt 0) { Get-Content (Join-Path $c 'logs\WT-040-R1\chkR.log') | Select-String 'Parse Error' | Select-Object -First 3 | ForEach-Object { Show ("      " + $_.Line.Trim()) }; exit 1 }
}

Show "=== modern two-vehicle river record: T-80B (player team) vs Leopard 2A4 (opposing) ==="
$lg = Join-Path $c 'logs\WT-040-R1\river-match-modern.log'
& $g --headless --path $c --fixed-fps 60 -s res://tests/record_river_ai_match.gd -- --vehicle ussr_t_80b --opposing germ_leopard_2a4 *> $lg
Show ("run exit=" + $LASTEXITCODE)
Get-Content $lg | Select-String 'river-record|river-match totals|river-match metric|=== |RIVER_AI' | ForEach-Object { Show ("  " + $_.Line.Trim().Substring(0, [Math]::Min(240, $_.Line.Trim().Length))) }
$pass = (Get-Content $lg -Raw) -match 'RIVER_AI_MATCH_PASS'
Show ("modern river record pass=" + $pass)
if (Test-Path (Join-Path $c 'logs\WT-040-R1\river_ai_match_44001.json')) {
    $j = [System.IO.File]::ReadAllText((Join-Path $c 'logs\WT-040-R1\river_ai_match_44001.json'), [System.Text.Encoding]::UTF8) | ConvertFrom-Json
    Show ("json: selected=" + $j.selected_vehicle_id + " opposing=" + $j.opposing_vehicle_id + " result=" + $j.result.outcome + " elapsed=" + $j.elapsed_s + " fired_slots=" + @($j.fired_slots).Count + " shots_total=" + $j.shots_total + " contacts=" + $j.contacts_total + " damage=" + $j.damage_events + " deaths=" + $j.deaths_total)
}
if (-not $pass) { Show "MODERN RECORD NOT PASSING - not committing"; exit 1 }

git -C $c add scripts/battle/team_range.gd tests/record_river_ai_match.gd logs/WT-040-R1
git -C $c -c user.name=mcthunder-agent -c user.email=agent@mcthunder.local commit -m "Let the internal engineering entry field one modern type against the other, and record the modern river match. The recorder gained --vehicle and --opposing arguments and keeps its historical default, so the original record is not rewritten; TeamRange gained an explicit opposing_engineering_id that is empty by default and only assigns the AI team's type, which changes team composition and nothing else - no ticket, capture, damage, reload or termination rule is touched, and the readiness gate still refuses anything not admitted. The recorded run fields T-80B on the player team against Leopard 2A4 on the opposing team and carries the five separated counters plus the scenario label that marks it as the internal engineering entry rather than a release admission" 2>&1 | Select-Object -First 2
Show ("commits=" + (git -C $c rev-list --count a1bac406..HEAD))
git -C $c push origin work/continuation-20260913 2>&1 | Select-Object -Last 1 | ForEach-Object { Show ("push: " + $_.ToString()) }
git -C $c diff --quiet HEAD; Show ("clean-check exit=" + $LASTEXITCODE)
