$c='E:\AIprogram\mcthunder-cont'
$g='E:\AIprogram\mcthunder\tools\godot\Godot_v4.7.2-stable_win64_console.exe'
$L="$c\logs\COMBAT-DEEPEN-01"
$T = [char]9

# ---- (1) manager: a contact HE detonates on a WORLD contact too, through the same emitter, with no target
$p="$c\scripts\projectiles\projectile_manager.gd"
$txt = Get-Content $p -Raw -Encoding UTF8
$a = '				var waiting := _rest_for_fuze(st, {}, "impact_world")'
$b = $a + "`r`n" + $T+$T+$T+$T + '# CD07 design point three, second half: a contact HE detonates on a WORLD contact too, not only on armour. The burst' + `
  "`r`n" + $T+$T+$T+$T + '# is emitted with NO target, which leaves the pressure verdict honestly false - the explosion is outside everything and no' + `
  "`r`n" + $T+$T+$T+$T + '# opening or breach can be claimed - while the fragment channel still flies and stays subject to world occlusion.' + `
  "`r`n" + $T+$T+$T+$T + 'if st.effect_policy == "he_blast" and not waiting and st.burst.is_empty():' + `
  "`r`n" + $T+$T+$T+$T + $T + '_emit_internal_burst(st,snapshots,space)'
$n1 = ([regex]::Matches($txt,[regex]::Escape($a))).Count
$txt = $txt.Replace($a,$b)
[IO.File]::WriteAllText($p, $txt, (New-Object Text.UTF8Encoding($false)))
"  world_contact_edit=$n1 ; gate=" + $txt.Contains('st.effect_policy == "he_blast" and not waiting and st.burst.is_empty()')

# ---- (2) probe: add a world-hit leg with a box the round can strike
$q="$c\tests\probe_cd007_he_runtime.gd"
$tv = Get-Content $q -Raw -Encoding UTF8
$anchor = '	world.queue_free(); await _frames(2)'
$add = @'
	# ── R3: a WORLD contact, with a box on the world layer so the round really strikes the environment.
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new(); box.size = Vector3(4,4,1)
	shape.shape = box
	wall.add_child(shape)
	wall.collision_layer = 1   # GameConfig.LAYER_WORLD
	wall.collision_mask = 0
	wall.position = Vector3(0,1.2,0)
	world.add_child(wall)
	await _frames(2)
	var wm := ProjectileManager.new(); wm.presentation_enabled=false
	world.add_child(wm); wm.set_physics_process(false)
	wm.damage_handler = Callable(actor2,"apply_projectile_damage")
	var wspec := {"round_id":SEED+1,"shooter_id":"cd007","shooter_life_id":1,"shot_id":SEED+1,
		"shell_id":str(found.id),"effect_policy":"he_blast","armor_policy":"resolve",
		"impact_profile":found.impact_profile,"post_penetration_profile":found.post_penetration_profile,
		"fuze_policy":{},"caliber_mm":found.caliber_mm,"penetration_curve":found.penetration_curve,
		"seed":2101,"position_world":Vector3(9,1.2,0),"velocity_world":Vector3(-700,0,0),"gravity_world":Vector3.ZERO,
		"max_age_s":0.6,"max_distance_m":90.0}
	var wspawned := wm.try_spawn(wspec)
	check(wspawned.ok,"CD07 landed R3 the world-hit shot launches")
	if wspawned.ok:
		var wstate: ProjectileState = wm.get_projectile_state(wspawned.projectile_id)
		var wspace := world.get_world_3d().direct_space_state
		for i in 400:
			if wstate.is_terminal(): break
			wm.advance_projectile(wstate,1.0/240.0,[],wspace)
		var wburst: Dictionary = wstate.burst if wstate.burst is Dictionary else {}
		var wchan: Dictionary = wburst.get("channels",{})
		var wover: Dictionary = wchan.get("overpressure",{})
		print("[CD07 landed] R3 WORLD OUTCOME terminal=%s burst=%s channels=%s external=%s openings=%d applied=%s" % [
			str(wstate.terminal_reason),("none" if wburst.is_empty() else "present"),str(wchan.keys()),
			str(wburst.get("external","")),int(wover.get("declared_openings",-1)),str(wover.get("applied",""))])
		check(not wburst.is_empty(),
			"CD07 landed R3 the external HE DETONATES on a world contact: terminal=%s" % str(wstate.terminal_reason))
		if not wburst.is_empty():
			check(wchan.size()==3,"CD07 landed R3 the world burst records the same three channels: %s" % str(wchan.keys()))
			check(bool(wburst.get("external",false)),
				"CD07 landed R3 and it is recorded as an EXTERNAL burst with no target: external=%s" % str(wburst.get("external","")))
			check(not bool(wover.get("applied",true)),
				"CD07 landed R3 T01 for the world case: no interior overpressure is invented where there is nothing to be inside: applied=%s" % str(wover.get("applied","")))
	wm.queue_free()
	world.queue_free(); await _frames(2)
'@
$n2 = ([regex]::Matches($tv,[regex]::Escape($anchor))).Count
$tv = $tv.Replace($anchor,$add)
[IO.File]::WriteAllText($q, $tv, (New-Object Text.UTF8Encoding($false)))
"  probe_r3_insert=$n2"

& $g --headless --path $c --check-only --script res://scripts/projectiles/projectile_manager.gd *> "$L\parse-w.log" 2>&1 | Out-Null
"  manager_parse_errors=" + @(Get-Content "$L\parse-w.log" | Select-String 'Parse Error|Compile Error').Count
& $g --headless --path $c --check-only --script res://tests/probe_cd007_he_runtime.gd *> "$L\parse-w2.log" 2>&1 | Out-Null
$e2=@(Get-Content "$L\parse-w2.log" | Select-String 'Parse Error|Compile Error').Count
"  probe_parse_errors=$e2"
if ($e2 -gt 0) { Get-Content "$L\parse-w2.log" | Select-String 'Parse Error|at:' | Select-Object -First 6 | ForEach-Object { "   " + $_.Line.Trim().Substring(0,[Math]::Min(175,$_.Line.Trim().Length)) }; exit 1 }
$j = Start-Job -ScriptBlock { param($g,$c,$L) & $g --headless --path $c --fixed-fps 60 -s res://tests/probe_cd007_he_runtime.gd *> "$L\cd007-w.log" } -ArgumentList $g,$c,$L
$d = Wait-Job $j -Timeout 400
if (-not $d) { Stop-Job $j; "  timeout" } else { "  done" }
Remove-Job $j
Get-Content "$L\cd007-w.log" -Encoding UTF8 -ErrorAction SilentlyContinue | Select-String 'R2 OUTCOME|R3 WORLD|CD07_HE_RUNTIME|=== 结果|^\[FAIL\]' | ForEach-Object { "  " + $_.Line.Trim().Substring(0,[Math]::Min(245,$_.Line.Trim().Length)) }
