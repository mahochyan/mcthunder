$c = 'E:\AIprogram\mcthunder-cont'
$enc = New-Object System.Text.UTF8Encoding($false)
function Show($m) { Write-Output $m }
function Patch([string]$rel, [string]$old, [string]$new, [string]$label) {
    $p = Join-Path $c $rel
    $t = [System.IO.File]::ReadAllText($p, [System.Text.Encoding]::UTF8)
    $nl = if ($t.Contains("`r`n")) { "`r`n" } else { "`n" }
    $o = $old.Replace("`n", $nl); $n = $new.TrimEnd("`r","`n").Replace("`n", $nl)
    $cnt = ([regex]::Matches($t, [regex]::Escape($o))).Count
    if ($cnt -eq 1) { [System.IO.File]::WriteAllText($p, $t.Replace($o, $n), $enc); Show ("  OK   " + $label); return $true }
    Show ("  MISS " + $label + " (x" + $cnt + ")"); return $false
}

$f = 'tests/record_river_ai_match.gd'
$p = Join-Path $c $f
$g = & git -C $c show ("HEAD:" + $f)
[System.IO.File]::WriteAllText($p, (($g -join "`r`n") + "`r`n"), $enc)
Show "restored recorder from HEAD"
$all = $true

$r = Patch $f '	var objective_ids: Array = []
	for objective in objectives: objective_ids.append(str(objective.id))' @'
	var objective_ids: Array = []
	for objective in objectives: objective_ids.append(str(objective.id))
	# WT-040-R1 (2026-09-17 ruling): report the five quantities separately instead of collapsing them into one
	# number. fired_slots is how many SLOTS fired at least once - it is NOT a round count; shots_total,
	# contacts_total and damage_events are summed from the real shot records; deaths_total counts the destroyed
	# actors. The old respawn counter stays WITHDRAWN and is never printed as a zero measurement.
	var shots_total := 0
	var contacts_total := 0
	var damage_events := 0
	for shot_index in scene.projectiles.shot_records.count():
		var shot_record: Variant = scene.projectiles.shot_records.get_record(shot_index)
		shots_total += 1
		contacts_total += shot_record.contacts.size()
		damage_events += shot_record.damage.size()
	var deaths_total := 0
	for team_key in deaths.keys(): deaths_total += int(deaths[team_key])
'@ 'recorder: five counters'; $all = $r -and $all

$r = Patch $f '		"fired_slots": shots.keys(),
		"respawns": "WITHDRAWN: life_id is per actor, not per life; the old counter was falsified",' @'
		"fired_slots": shots.keys(),
		"fired_slots_note": "count of SLOTS that fired at least once, not a round count",
		"shots_total": shots_total,
		"contacts_total": contacts_total,
		"damage_events": damage_events,
		"deaths_total": deaths_total,
		"respawns": "WITHDRAWN: life_id is per actor, not per life; the old counter was falsified and must not be read as a zero",
'@ 'recorder: json fields'; $all = $r -and $all

$r = Patch $f '	print("[river-match totals] result=%s elapsed=%.0fs tickets=%s reached=%s fired=%d respawns=%s destroyed=%s max_stationary=%ds" % [
		str(scene.director.state.result.get("outcome","?")), scene.director.state.elapsed,
		str(scene.director.state.tickets), str(reached.keys()), shots.size(), str(respawns), str(deaths), max_still])' @'
	# WT-040-R1 (2026-09-17 ruling): fired_slots is a slot count, the round/contact/damage/death totals are
	# reported separately, and the withdrawn respawn counter is printed as WITHDRAWN rather than as its stale
	# dictionary of zeros, which could otherwise be mistaken for a valid measurement.
	print("[river-match totals] result=%s elapsed=%.0fs tickets=%s reached=%s fired_slots=%d shots_total=%d contacts=%d damage=%d deaths=%d respawns=WITHDRAWN max_stationary=%ds" % [
		str(scene.director.state.result.get("outcome","?")), scene.director.state.elapsed,
		str(scene.director.state.tickets), str(reached.keys()), shots.size(), shots_total, contacts_total, damage_events, deaths_total, max_still])
'@ 'recorder: totals print'; $all = $r -and $all

if (-not $all) { Show "PATCH ANCHORS MISSED - aborting"; exit 1 }

$g2 = 'E:\AIprogram\mcthunder\tools\godot\Godot_v4.7.2-stable_win64_console.exe'
& $g2 --headless --path $c --check-only --script res://tests/record_river_ai_match.gd *> (Join-Path $c 'logs\WT-040-R1\chkC.log') 2>&1 | Out-Null
$perr = @(Get-Content (Join-Path $c 'logs\WT-040-R1\chkC.log') | Select-String 'Parse Error|Compile Error').Count
Show ("parse errors=" + $perr)
if ($perr -gt 0) { Get-Content (Join-Path $c 'logs\WT-040-R1\chkC.log') | Select-String 'Parse Error' | Select-Object -First 3 | ForEach-Object { Show ("    " + $_.Line.Trim()) }; exit 1 }

$lg = Join-Path $c 'logs\WT-040-R1\river-match-C.log'
Show "running one real recorded river match to evidence the five counters"
& $g2 --headless --path $c --fixed-fps 60 -s res://tests/record_river_ai_match.gd *> $lg
Show ("run exit=" + $LASTEXITCODE)
Get-Content $lg | Select-String 'river-match totals|river-match metric|^\[PASS\]|^\[FAIL\]|=== |RIVER_AI' | ForEach-Object { Show ("  " + $_.Line.Trim().Substring(0, [Math]::Min(300, $_.Line.Trim().Length))) }
$json = Join-Path $c 'logs\WT-040-R1\river_ai_match_44001.json'
if (Test-Path $json) {
    $j = [System.IO.File]::ReadAllText($json, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
    Show ("json fields: fired_slots=" + @($j.fired_slots).Count + " shots_total=" + $j.shots_total + " contacts_total=" + $j.contacts_total + " damage_events=" + $j.damage_events + " deaths_total=" + $j.deaths_total + " respawns=" + $j.respawns)
}
$ok = ((Get-Content $lg -Raw) -match 'RIVER_AI_MATCH_PASS') -and ((Get-Content $lg -Raw) -match 'respawns=WITHDRAWN') -and ((Get-Content $lg -Raw) -match 'fired_slots=\d+ shots_total=\d+ contacts=\d+ damage=\d+ deaths=\d+')
Show ("five-counter evidence present=" + $ok)
if (-not $ok) { Show "EVIDENCE INCOMPLETE - not committing"; exit 1 }

git -C $c add tests/record_river_ai_match.gd logs/WT-040-R1
git -C $c -c user.name=mcthunder-agent -c user.email=agent@mcthunder.local commit -m "Report the river record's five quantities separately, and stop printing the withdrawn respawn counter as a zero. fired_slots is the number of slots that fired at least once - it was never a round count, and the previous summary line made it read like one; the record now also carries shots_total, contacts_total and damage_events summed from the real shot records, and deaths_total for the destroyed actors. The respawn counter stays WITHDRAWN in the record and the summary line now prints respawns=WITHDRAWN instead of dumping its stale dictionary of zeros, which could otherwise be taken for a valid measurement of nothing happening. Nothing about tickets, capture speed, damage, reloading or match termination was touched, and the run is labelled as an engineering measurement rather than an admission claim" 2>&1 | Select-Object -First 2
Show ("commits=" + (git -C $c rev-list --count a1bac406..HEAD))
git -C $c push origin work/continuation-20260913 2>&1 | Select-Object -Last 1 | ForEach-Object { Show ("push: " + $_.ToString()) }
Show '=== done ==='
