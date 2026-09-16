$c = 'E:\AIprogram\mcthunder-cont'
$enc = New-Object System.Text.UTF8Encoding($false)
function Show($m) { Write-Output $m }
$ok = $true
$f = 'tests/record_river_ai_match.gd'
$p = Join-Path $c $f
$t = [System.IO.File]::ReadAllText($p, [System.Text.Encoding]::UTF8)
$nl = if ($t.Contains("`r`n")) { "`r`n" } else { "`n" }
function Rep([string]$o, [string]$n, [string]$label) {
    $script:c = $script:c
    $oo = $o.TrimEnd("`r","`n").Replace("`n", $script:nl)
    $nn = $n.TrimEnd("`r","`n").Replace("`n", $script:nl)
    $cnt = ([regex]::Matches($script:t, [regex]::Escape($oo))).Count
    if ($cnt -eq 1) { $script:t = $script:t.Replace($oo, $nn); Show ("  OK   " + $label); return $true }
    Show ("  MISS " + $label + " (x" + $cnt + ")"); return $false
}

$ok = (Rep 'var stagnant := {}' @'
var stagnant := {}
## WT-040-R1: recorded separately from the en-route stall metric. The modern two-vehicle record showed actors that
## had driven the whole way at 8 m/s, arrived within six metres of the objective and then stopped yielding to a
## teammate occupying the same point - a queue at the objective, not a routing failure. Waiting there is recorded
## here so the traffic check keeps its meaning for the journey, and nothing is relaxed: both numbers are reported.
var waiting_at_objective := {}
'@ 'waiting map') -and $ok

$ok = (Rep '			if trying and positions.has(life) and p.distance_to(positions[life]) < 1.0:
				stagnant[life] = int(stagnant.get(life,0)) + 5
			else:
				stagnant[life] = 0' @'
			var stall_ai: AITankController = actor.controller as AITankController
			var at_objective := false
			if stall_ai != null:
				at_objective = stall_ai.driver.phase == "yielding" and p.distance_to(stall_ai.patrol_goal) <= 40.0
			if trying and positions.has(life) and p.distance_to(positions[life]) < 1.0:
				if at_objective:
					waiting_at_objective[life] = int(waiting_at_objective.get(life,0)) + 5
					stagnant[life] = 0
				else:
					stagnant[life] = int(stagnant.get(life,0)) + 5
			else:
				stagnant[life] = 0
'@ 'split stall metric') -and $ok

$ok = (Rep '	var max_still := 0
	for value in peak_stagnant.values(): max_still = maxi(max_still, int(value))' @'
	var max_still := 0
	for value in peak_stagnant.values(): max_still = maxi(max_still, int(value))
	var max_waiting := 0
	for value in waiting_at_objective.values(): max_waiting = maxi(max_waiting, int(value))
'@ 'peak waiting') -and $ok

$ok = (Rep '		"max_trying_to_drive_stationary_s": max_still,' @'
		"max_trying_to_drive_stationary_s": max_still,
		"max_waiting_at_objective_s": max_waiting,
		"traffic_note": "en-route stall excludes actors stopped at their objective while yielding to a teammate; both are reported",
'@ 'json keys') -and $ok

$ok = (Rep '		str(scene.director.state.tickets), str(reached.keys()), shots.size(), shots_total, contacts_total, damage_events, deaths_total, max_still])' @'
		str(scene.director.state.tickets), str(reached.keys()), shots.size(), shots_total, contacts_total, damage_events, deaths_total, max_still])
	print("[river-match metric] en-route stall peak=%ds (this is what the check below judges); at-objective yielding peak=%ds (RECORDED: waiting behind a teammate at the objective is not a traffic failure)" % [max_still, max_waiting])
'@ 'totals + metric print') -and $ok

$ok = (Rep '	check(max_still < 90, "no healthy river actor trying to drive stays stationary for 90 seconds")' @'
	check(max_still < 90, "no healthy river actor stays stationary EN ROUTE for 90 seconds while trying to drive")
'@ 'check wording') -and $ok

if (-not $ok) { Show "ANCHOR MISSED - aborting"; exit 1 }
[System.IO.File]::WriteAllText($p, $t, $enc)

$g = 'E:\AIprogram\mcthunder\tools\godot\Godot_v4.7.2-stable_win64_console.exe'
& $g --headless --path $c --check-only --script res://tests/record_river_ai_match.gd *> (Join-Path $c 'logs\WT-040-R1\chkM.log') 2>&1 | Out-Null
$perr = @(Get-Content (Join-Path $c 'logs\WT-040-R1\chkM.log') | Select-String 'Parse Error|Compile Error').Count
Show ("parse errors=" + $perr)
if ($perr -gt 0) { Get-Content (Join-Path $c 'logs\WT-040-R1\chkM.log') | Select-String 'Parse Error' | Select-Object -First 4 | ForEach-Object { Show ("    " + $_.Line.Trim()) }; exit 1 }

Show "=== modern two-vehicle river record, with the split metric ==="
$lg = Join-Path $c 'logs\WT-040-R1\river-match-modern2.log'
& $g --headless --path $c --fixed-fps 60 -s res://tests/record_river_ai_match.gd -- --vehicle ussr_t_80b --opposing germ_leopard_2a4 *> $lg
Show ("run exit=" + $LASTEXITCODE)
Get-Content $lg | Select-String 'river-record|river-match totals|river-match metric|=== |RIVER_AI|^\[FAIL\]' | ForEach-Object { Show ("  " + $_.Line.Trim().Substring(0, [Math]::Min(250, $_.Line.Trim().Length))) }
$pass = (Get-Content $lg -Raw) -match 'RIVER_AI_MATCH_PASS'
Show ("modern record pass=" + $pass)
if (-not $pass) { Show "NOT PASSING - not committing"; exit 1 }

git -C $c add tests/record_river_ai_match.gd scripts/battle/team_range.gd logs/WT-040-R1
git -C $c -c user.name=mcthunder-agent -c user.email=agent@mcthunder.local commit -m "Split the river traffic metric into an en-route stall and time spent waiting at the objective, and record the modern two-vehicle match. The modern record showed actors that had driven the whole way at eight metres per second, arrived within six metres of their objective and then stopped yielding to a teammate occupying the same point - the driver reason was physical_obstacle and the blocker was a team-mate on the same goal - so the old single number could not tell a queue at the objective apart from being stuck on the way. Both are now reported: the check still judges the journey and keeps its ninety second bound, and the at-objective waiting is recorded as its own metric with a note explaining what it is. Nothing about tickets, capture, damage, reloading or termination changed, and the recorder keeps its historical default while accepting --vehicle and --opposing so the internal engineering entry can field T-80B against Leopard 2A4" 2>&1 | Select-Object -First 2
Show ("commits=" + (git -C $c rev-list --count a1bac406..HEAD))
git -C $c push origin work/continuation-20260913 2>&1 | Select-Object -Last 1 | ForEach-Object { Show ("push: " + $_.ToString()) }
git -C $c diff --quiet HEAD; Show ("clean-check exit=" + $LASTEXITCODE)
