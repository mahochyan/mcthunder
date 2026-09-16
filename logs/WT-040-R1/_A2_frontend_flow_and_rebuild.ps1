$c = 'E:\AIprogram\mcthunder-cont'
$enc = New-Object System.Text.UTF8Encoding($false)
function Show($m) { Write-Output $m }

$p = Join-Path $c 'scripts\diagnostics\player_flow_verifier.gd'
$good = & git -C $c show HEAD:scripts/diagnostics/player_flow_verifier.gd
[System.IO.File]::WriteAllText($p, (($good -join "`r`n") + "`r`n"), $enc)
Show ("restored verifier from HEAD, lines=" + @($good).Count)
$t = [System.IO.File]::ReadAllText($p, [System.Text.Encoding]::UTF8)
$nl = if ($t.Contains("`r`n")) { "`r`n" } else { "`n" }
$applied = 0

# --- 1) add a state-driven, bounded wait helper --------------------------------------------------------
$anchor1 = 'func natural_matches() -> void:'
$add1 = @'
func wait_state(predicate: Callable, label: String, maximum_frames := 900) -> bool:
	# WT-040-R1 (2026-09-17 ruling): waits must follow page, dialog, layout and scene state with a bound, instead
	# of piling on fixed frame counts. This returns false and says what it waited for, so a timeout is visible
	# rather than silently absorbed.
	for i in maximum_frames:
		if predicate.call(): return true
		await frames(1)
	print("[wait] timed out after ",maximum_frames," frames waiting for: ",label)
	return false

'@
if ($t.Contains($anchor1)) { $t = $t.Replace($anchor1, $add1.TrimEnd("`r","`n").Replace("`n", $nl) + $nl + $anchor1); $applied++; Show "wait_state inserted" }
else { Show "WAIT ANCHOR MISSING" }

# --- 2) drive the interface the player actually sees ----------------------------------------------------
$old2 = @'
	for map_index in 2:
		if is_instance_valid(app.garage.challenge_selection): await click(app.garage.challenge_selection.close_button)
		await frames(8)
		await choose(app.garage.vehicle_choice,1)
		await choose(app.garage.preparation.mode_choice,1)
		if not app.garage.preparation.details.visible: await click(app.garage.preparation.settings_button)
		await choose(app.garage.preparation.map_choice,map_index)
		# WT-040-R1: report the lookup itself, so a null or hidden start button is named instead of only failing
		# the generic visibility assertion.
		var start_button := find_button(app.garage,LocalizationService.text("ui_56b6b54bb00a"))
		print("[garage] map_index=",map_index," start_button_valid=",is_instance_valid(start_button),
			" visible=",is_instance_valid(start_button) and start_button.is_visible_in_tree(),
			" settings_visible=",app.garage.preparation.details.visible,
			" map_choice_index=",app.garage.preparation.map_choice.selected)
		await click(start_button); await idle()
		var battle:=app.training as TeamRange
		check(battle!=null and battle.team_ready,"normal garage button enters complete map "+str(map_index))
'@
$new2 = @'
	for map_index in 2:
		if is_instance_valid(app.garage.challenge_selection): await click(app.garage.challenge_selection.close_button)
		await frames(8)
		# WT-040-R1 (2026-09-17 ruling): follow the interface the player actually sees. GarageFrontend hides the
		# old GarageControlSource, moves the vehicle selector to its "vehicle systems" page and keeps mode, map and
		# difficulty on the "deployment" page, and exposes the real deploy button. Page changes are made by
		# clicking the frontend's own tabs - never by calling show_page, never by emitting a deploy signal and
		# never by forcing a hidden control visible. Every wait is state driven and bounded.
		var frontend: GarageFrontend = app.garage.frontend
		check(frontend != null and frontend.tabs.size() >= 2,"garage frontend exposes its navigation tabs")
		if frontend == null: return
		var vehicle_index := 1
		check(vehicle_index < frontend.cards.size(),"garage frontend exposes a vehicle card per vehicle")
		await click(frontend.tabs[1])
		check(await wait_state(func() -> bool: return frontend.page_index == 1 and frontend.pages[1].visible,"vehicle systems page becomes active"),"clicking the vehicle tab activates the vehicle systems page")
		var wanted := str(app.garage.vehicle_choice.get_item_metadata(vehicle_index))
		await click(frontend.cards[vehicle_index])
		check(await wait_state(func() -> bool: return app.garage.selected_vehicle_id() == wanted,"clicking a vehicle card selects that vehicle"),"clicking the vehicle card selects it")
		await click(frontend.tabs[0])
		check(await wait_state(func() -> bool: return frontend.page_index == 0 and frontend.pages[0].visible,"deployment page becomes active"),"clicking the deployment tab activates it")
		await choose(app.garage.preparation.mode_choice,1)
		await choose(app.garage.preparation.map_choice,map_index)
		check(await wait_state(func() -> bool: return app.garage.preparation.map_choice.selected == map_index,"map choice commits"),"chosen map is committed by the real control")
		print("[garage] map_index=",map_index," page=",frontend.page_index," tabs=",frontend.tabs.size(),
			" cards=",frontend.cards.size()," selected=",app.garage.selected_vehicle_id(),
			" deploy_visible=",is_instance_valid(frontend.deploy) and frontend.deploy.is_visible_in_tree(),
			" map_choice=",app.garage.preparation.map_choice.selected)
		await click(frontend.deploy)
		check(await wait_state(func() -> bool: return app.training != null,"deploy enters the selected match"),"the real deploy button enters the selected match")
		var battle:=app.training as TeamRange
		check(battle!=null and battle.team_ready,"normal garage button enters complete map "+str(map_index))
'@
if ($t.Contains($old2.Replace("`n", $nl))) { $t = $t.Replace($old2.Replace("`n", $nl), $new2.TrimEnd("`r","`n").Replace("`n", $nl)); $applied++; Show "natural_matches rewritten" }
else { Show "NATURAL_MATCHES ANCHOR MISSING" }

# --- 3) respawn through the real UI control -------------------------------------------------------------
$old3 = '			if battle.actor.state.destroyed: battle.request_respawn()'
$new3 = @'
			if battle.actor.state.destroyed:
				# WT-040-R1 (2026-09-17 ruling): the player's manual respawn must go through the real control.
				# Calling request_respawn directly is method-level integration only and cannot stand as evidence
				# that normal-UI respawn works, so the actual button is clicked when it is visible.
				if is_instance_valid(battle.respawn_button) and battle.respawn_button.is_visible_in_tree():
					await click(battle.respawn_button)
'@
if ($t.Contains($old3)) { $t = $t.Replace($old3, $new3.TrimEnd("`r","`n").Replace("`n", $nl)); $applied++; Show "respawn uses the real button" }
else { Show "RESPAWN ANCHOR MISSING" }

if ($applied -ne 3) { Show ("only " + $applied + " of 3 applied - aborting"); exit 1 }
[System.IO.File]::WriteAllText($p, $t, $enc)

$g = 'E:\AIprogram\mcthunder\tools\godot\Godot_v4.7.2-stable_win64_console.exe'
Show ("engine exists=" + (Test-Path $g))
& $g --headless --path $c --check-only --script res://scripts/diagnostics/player_flow_verifier.gd *> (Join-Path $c 'logs\WT-040-R1\chk-verifier9.log') 2>&1 | Out-Null
$perr = @(Get-Content (Join-Path $c 'logs\WT-040-R1\chk-verifier9.log') | Select-String 'Parse Error|Compile Error').Count
Show ("parse errors=" + $perr)
if ($perr -gt 0) { Get-Content (Join-Path $c 'logs\WT-040-R1\chk-verifier9.log') | Select-String 'Parse Error' | Select-Object -First 4 | ForEach-Object { Show ("    " + $_.Line.Trim()) }; exit 1 }

$lg = Join-Path $c 'logs\WT-040-R1\devtree-player-flow11.log'
Show ("dev-tree guard run; log=" + $lg)
& $g --path $c --resolution 1280x720 -- --verify-player-flow *> $lg
Show ("flow exit=" + $LASTEXITCODE)
$verdict = @(Get-Content $lg | Select-String '^\[PASS\] normal keyboard and mouse session completes flank challenge|^\[PASS\] result backed by actual side penetration')
Show ("flank pass lines=" + $verdict.Count)
Get-Content $lg | Select-String '^\[FAIL\]|\[garage\]|\[wait\]' | Select-Object -First 8 | ForEach-Object { Show ("  " + $_.Line.Trim().Substring(0, [Math]::Min(200, $_.Line.Trim().Length))) }
if ($verdict.Count -lt 2) { Show "DEV-TREE GUARD FAILED - not committing, not rebuilding"; exit 1 }

git -C $c add scripts/diagnostics/player_flow_verifier.gd scripts/diagnostics/window_input_driver.gd logs/WT-040-R1
git -C $c -c user.name=mcthunder-agent -c user.email=agent@mcthunder.local commit -m "Drive the packaged player flow through the interface the player actually sees, and stop clicking hidden controls. GarageFrontend hides the old GarageControlSource, keeps mode, map and difficulty on its deployment page, moves the vehicle selector to its vehicle systems page and hides the old settings button outright, so the previous section was operating controls that are no longer part of the visible interface - which is why four checks saw visible=false on a button that exists and is not disabled. The section now clicks the frontend's own navigation tabs, picks a vehicle through the frontend's card buttons, returns to the deployment page, sets mode and map through the real controls and deploys with frontend.deploy; no hidden control is forced visible, show_page is never called directly and no deploy signal is emitted. Waits are state driven and bounded by a new wait_state helper that reports what it timed out on. The shared click helper now stops the click when the visibility assertion fails or the control is disabled, instead of computing a centre point and sending a mouse event anyway, which could land on whatever is really there. Finally the player respawn goes through battle.respawn_button, because calling request_respawn directly is method-level integration and cannot evidence normal-UI respawn" 2>&1 | Select-Object -First 2
Show ("commits=" + (git -C $c rev-list --count a1bac406..HEAD))
git -C $c push origin work/continuation-20260913 2>&1 | Select-Object -Last 1 | ForEach-Object { Show ("push: " + $_.ToString()) }
git -C $c diff --quiet HEAD; Show ("clean-check exit=" + $LASTEXITCODE)

Show "=== candidate build ==="
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $c 'tests\build_release.ps1') -Candidate
Show ("build exit=" + $LASTEXITCODE)
