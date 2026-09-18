$c='E:\AIprogram\mcthunder-cont'
$g='E:\AIprogram\mcthunder\tools\godot\Godot_v4.7.2-stable_win64_console.exe'
$L="$c\logs\COMBAT-DEEPEN-01"
$p="$c\scripts\projectiles\projectile_manager.gd"
$txt = Get-Content $p -Raw -Encoding UTF8
$T = [char]9

# (1) the stop branch records the surface it stopped on (unique substring, so no anchoring is needed)
$a1 = 'waiting = _rest_for_fuze(st, ev, "armor_"+str(result.result))'
$b1 = $a1 + "`r`n" + $T + $T + '# CD07 design point three, first half: a contact HE bursts ON CONTACT instead of being stopped inert. This handler holds' + `
  "`r`n" + $T + $T + '# neither the snapshot list nor the physics space, so it can only RECORD the surface it stopped on; the caller emits.' + `
  "`r`n" + $T + $T + 'if st.effect_policy == "he_blast" and not waiting and st.burst_target.is_empty():' + `
  "`r`n" + $T + $T + $T + 'st.burst_target = ev.duplicate(true)' + `
  "`r`n" + $T + $T + $T + 'st.burst_entry_distance = st.travelled_m' + `
  "`r`n" + $T + $T + $T + 'st.burst_inside_started = false' + `
  "`r`n" + $T + $T + $T + 'st.burst_visited[DamageResolver.target_key(ev)] = true'
$n1 = ([regex]::Matches($txt,[regex]::Escape($a1))).Count
$txt = $txt.Replace($a1,$b1)

# (2) the caller emits it where the snapshot list and the space are in hand
$a2 = 'if not handle_contact(st, ev):'
$b2 = 'var continuing := handle_contact(st, ev)' + `
  "`r`n" + $T + $T + $T + '# The emission belongs here rather than in the handler, because only this frame holds the snapshot list and the' + `
  "`r`n" + $T + $T + $T + '# physics space. It reuses the internal burst emitter, so no second damage path exists, and it is gated on the' + `
  "`r`n" + $T + $T + $T + '# external blast policy so every other effect behaves exactly as before.' + `
  "`r`n" + $T + $T + $T + 'if st.effect_policy == "he_blast" and not continuing and not st.burst_target.is_empty() and st.burst.is_empty():' + `
  "`r`n" + $T + $T + $T + $T + 'var he_snapshots := TranslationSweep.frame_at(snapshots,float(ev.get("motion_fraction",1.0)))' + `
  "`r`n" + $T + $T + $T + $T + '_emit_internal_burst(st,he_snapshots,space)' + `
  "`r`n" + $T + $T + $T + 'if not continuing:'
$n2 = ([regex]::Matches($txt,[regex]::Escape($a2))).Count
$txt = $txt.Replace($a2,$b2)
[IO.File]::WriteAllText($p, $txt, (New-Object Text.UTF8Encoding($false)))
"  stop_branch_hits=$n1 ; caller_hits=$n2 ; gate_present=" + $txt.Contains('st.effect_policy == "he_blast"')

& $g --headless --path $c --check-only --script res://scripts/projectiles/projectile_manager.gd *> "$L\parse-hec3.log" 2>&1 | Out-Null
$err=@(Get-Content "$L\parse-hec3.log" | Select-String 'Parse Error|Compile Error').Count
"  manager_parse_errors=$err"
if ($err -gt 0) { Get-Content "$L\parse-hec3.log" | Select-String 'Parse Error|at:' | Select-Object -First 6 | ForEach-Object { "   " + $_.Line.Trim().Substring(0,[Math]::Min(175,$_.Line.Trim().Length)) }; exit 1 }
$j = Start-Job -ScriptBlock { param($g,$c,$L) & $g --headless --path $c --fixed-fps 60 -s res://tests/probe_cd007_he_runtime.gd *> "$L\cd007-hert6.log" } -ArgumentList $g,$c,$L
$d = Wait-Job $j -Timeout 400
if (-not $d) { Stop-Job $j; "  timeout" } else { "  done" }
Remove-Job $j
Get-Content "$L\cd007-hert6.log" -Encoding UTF8 -ErrorAction SilentlyContinue | Select-String 'R1 vehicles offering|R2 OUTCOME|CD07_HE_RUNTIME|=== 结果|^\[FAIL\]' | ForEach-Object { "  " + $_.Line.Trim().Substring(0,[Math]::Min(245,$_.Line.Trim().Length)) }
