$c='E:\AIprogram\mcthunder-cont'
$g='E:\AIprogram\mcthunder\tools\godot\Godot_v4.7.2-stable_win64_console.exe'
$L="$c\logs\COMBAT-DEEPEN-01"
$p="$c\scripts\projectiles\projectile_manager.gd"
$txt = Get-Content $p -Raw -Encoding UTF8

# (1) the stop branch records the target it stopped on (state only; no emission is possible here)
$a1 = @'
	if result.get("result", "") in ["stopped", "perforated_stop"]:
		waiting = _rest_for_fuze(st, ev, "armor_"+str(result.result))
'@
$b1 = @'
	if result.get("result", "") in ["stopped", "perforated_stop"]:
		waiting = _rest_for_fuze(st, ev, "armor_"+str(result.result))
		# CD07 design point three, first half: a contact HE bursts ON CONTACT instead of being stopped inert. This handler
		# holds neither the snapshot list nor the physics space, so all it can do is RECORD the surface it stopped on; the
		# caller turns that into a root event. Gated on the external blast policy alone.
		if st.effect_policy == "he_blast" and not waiting and st.burst_target.is_empty():
			st.burst_target = ev.duplicate(true)
			st.burst_entry_distance = st.travelled_m
			st.burst_inside_started = false
			st.burst_visited[DamageResolver.target_key(ev)] = true
'@
$n1 = ([regex]::Matches($txt,[regex]::Escape($a1))).Count
$txt = $txt.Replace($a1,$b1)

# (2) the caller emits it where both the snapshot list and the space are in hand, through the existing emitter
$a2 = @'
			if not handle_contact(st, ev):
				return
			if not st.post_penetration_profile.is_empty():
'@
$b2 = @'
			var continuing := handle_contact(st, ev)
			# The emission belongs here rather than in the handler, because only this frame holds the snapshot list and the
			# physics space. It reuses the internal burst emitter, so no second damage path exists, and it is gated on the
			# external blast policy so every other effect behaves exactly as before.
			if st.effect_policy == "he_blast" and not continuing and not st.burst_target.is_empty() and st.burst.is_empty():
				var he_snapshots := TranslationSweep.frame_at(snapshots,float(ev.get("motion_fraction",1.0)))
				_emit_internal_burst(st,he_snapshots,space)
			if not continuing:
				return
			if not st.post_penetration_profile.is_empty():
'@
$n2 = ([regex]::Matches($txt,[regex]::Escape($a2))).Count
$txt = $txt.Replace($a2,$b2)
[IO.File]::WriteAllText($p, $txt, (New-Object Text.UTF8Encoding($false)))
"  stop_branch_edit=$n1 ; caller_edit=$n2"

& $g --headless --path $c --check-only --script res://scripts/projectiles/projectile_manager.gd *> "$L\parse-hec.log" 2>&1 | Out-Null
$err=@(Get-Content "$L\parse-hec.log" | Select-String 'Parse Error|Compile Error').Count
"  manager_parse_errors=$err"
if ($err -gt 0) { Get-Content "$L\parse-hec.log" | Select-String 'Parse Error|at:' | Select-Object -First 5 | ForEach-Object { "   " + $_.Line.Trim().Substring(0,[Math]::Min(175,$_.Line.Trim().Length)) }; exit 1 }
$j = Start-Job -ScriptBlock { param($g,$c,$L) & $g --headless --path $c --fixed-fps 60 -s res://tests/probe_cd007_he_runtime.gd *> "$L\cd007-hert4.log" } -ArgumentList $g,$c,$L
$d = Wait-Job $j -Timeout 400
if (-not $d) { Stop-Job $j; "  timeout" } else { "  done" }
Remove-Job $j
Get-Content "$L\cd007-hert4.log" -Encoding UTF8 -ErrorAction SilentlyContinue | Select-String 'R1 vehicles offering|R2 OUTCOME|CD07_HE_RUNTIME|=== 结果|^\[FAIL\]' | ForEach-Object { "  " + $_.Line.Trim().Substring(0,[Math]::Min(245,$_.Line.Trim().Length)) }
