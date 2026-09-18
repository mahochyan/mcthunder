$c='E:\AIprogram\mcthunder-cont'
$g='E:\AIprogram\mcthunder\tools\godot\Godot_v4.7.2-stable_win64_console.exe'
$L="$c\logs\COMBAT-DEEPEN-01"
$p="$c\scripts\projectiles\projectile_manager.gd"
$txt = Get-Content $p -Raw -Encoding UTF8

# (1) stop branch: record the surface, with the indentation captured rather than typed
$pat1 = '(?m)^([ \t]*)waiting = _rest_for_fuze\(st, ev, "armor_"\+str\(result\.result\)\)[ \t]*$'
$rep1 = @'
$1waiting = _rest_for_fuze(st, ev, "armor_"+str(result.result))
$1# CD07 design point three, first half: a contact HE bursts ON CONTACT instead of being stopped inert. This handler holds
$1# neither the snapshot list nor the physics space, so all it can do is RECORD the surface it stopped on; the caller turns
$1# that into a root event. Gated on the external blast policy alone, so every other effect is untouched.
$1if st.effect_policy == "he_blast" and not waiting and st.burst_target.is_empty():
$1	st.burst_target = ev.duplicate(true)
$1	st.burst_entry_distance = st.travelled_m
$1	st.burst_inside_started = false
$1	st.burst_visited[DamageResolver.target_key(ev)] = true
'@
$m1 = [regex]::Matches($txt,$pat1)
$txt = [regex]::Replace($txt,$pat1,$rep1)

# (2) caller: emit through the existing emitter, before the early return, with the indent captured
$pat2 = '(?m)^([ \t]*)if not handle_contact\(st, ev\):[ \t]*$'
$rep2 = @'
$1var continuing := handle_contact(st, ev)
$1# The emission belongs here rather than in the handler, because only this frame holds the snapshot list and the physics
$1# space. It reuses the internal burst emitter, so no second damage path exists, and it is gated on the external blast
$1# policy so every other effect behaves exactly as before.
$1if st.effect_policy == "he_blast" and not continuing and not st.burst_target.is_empty() and st.burst.is_empty():
$1	var he_snapshots := TranslationSweep.frame_at(snapshots,float(ev.get("motion_fraction",1.0)))
$1	_emit_internal_burst(st,he_snapshots,space)
$1if not continuing:
'@
$m2 = [regex]::Matches($txt,$pat2)
$txt = [regex]::Replace($txt,$pat2,$rep2)
[IO.File]::WriteAllText($p, $txt, (New-Object Text.UTF8Encoding($false)))
"  stop_branch_hits=" + $m1.Count + " ; caller_hits=" + $m2.Count
"  he_blast_gate_present=" + $txt.Contains('st.effect_policy == "he_blast"')

& $g --headless --path $c --check-only --script res://scripts/projectiles/projectile_manager.gd *> "$L\parse-hec2.log" 2>&1 | Out-Null
$err=@(Get-Content "$L\parse-hec2.log" | Select-String 'Parse Error|Compile Error').Count
"  manager_parse_errors=$err"
if ($err -gt 0) { Get-Content "$L\parse-hec2.log" | Select-String 'Parse Error|at:' | Select-Object -First 6 | ForEach-Object { "   " + $_.Line.Trim().Substring(0,[Math]::Min(175,$_.Line.Trim().Length)) }; exit 1 }
$j = Start-Job -ScriptBlock { param($g,$c,$L) & $g --headless --path $c --fixed-fps 60 -s res://tests/probe_cd007_he_runtime.gd *> "$L\cd007-hert5.log" } -ArgumentList $g,$c,$L
$d = Wait-Job $j -Timeout 400
if (-not $d) { Stop-Job $j; "  timeout" } else { "  done" }
Remove-Job $j
Get-Content "$L\cd007-hert5.log" -Encoding UTF8 -ErrorAction SilentlyContinue | Select-String 'R1 vehicles offering|R2 OUTCOME|CD07_HE_RUNTIME|=== 结果|^\[FAIL\]' | ForEach-Object { "  " + $_.Line.Trim().Substring(0,[Math]::Min(245,$_.Line.Trim().Length)) }
