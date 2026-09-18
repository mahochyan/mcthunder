$c='E:\AIprogram\mcthunder-cont'
$g='E:\AIprogram\mcthunder\tools\godot\Godot_v4.7.2-stable_win64_console.exe'
$L="$c\logs\COMBAT-DEEPEN-01"
$T = [char]9
$p="$c\scripts\projectiles\projectile_manager.gd"
$txt = Get-Content $p -Raw -Encoding UTF8

# (1) the "external" verdict belongs to EVERY burst, not only to a fuzed one: a contact HE has no fuze and still needs it.
$a1 = '		st.burst["external"] = target.is_empty() or not ShellEffectPolicy.inside(target, st.position_world)'
$n1 = ([regex]::Matches($txt,[regex]::Escape($a1))).Count
$txt = $txt.Replace($a1,'')
$a2 = '	var legacy_channels := ShellEffectPolicy.legacy_template()'
$b2 = '	# The external verdict belongs to EVERY burst, not only to a fuzed one: a contact HE carries no fuze and its burst must' + `
  "`r`n" + $T + '# still say whether the explosion happened outside the hull.' + `
  "`r`n" + $T + 'st.burst["external"] = target.is_empty() or not ShellEffectPolicy.inside(target, st.position_world)' + `
  "`r`n" + $T + 'var legacy_channels := ShellEffectPolicy.legacy_template()'
$n2 = ([regex]::Matches($txt,[regex]::Escape($a2))).Count
$txt = $txt.Replace($a2,$b2)

# (2) a world contact records that fact, because the emitter owns the terminal reason and it will say internal_burst.
$a3 = '					_emit_internal_burst(st,snapshots,space)'
$b3 = '					_emit_internal_burst(st,snapshots,space)' + `
  "`r`n" + $T+$T+$T+$T+$T + '# The emitter owns the terminal reason, so the world contact is recorded on the burst itself.' + `
  "`r`n" + $T+$T+$T+$T+$T + 'if st.burst is Dictionary: st.burst["contact_kind"] = "world_contact"'
$n3 = ([regex]::Matches($txt,[regex]::Escape($a3))).Count
$txt = $txt.Replace($a3,$b3)
[IO.File]::WriteAllText($p, $txt, (New-Object Text.UTF8Encoding($false)))
"  external_moved=$n1 to=$n2 ; contact_kind=$n3"

# (3) the probe's two mis-stated judgments, corrected and STRENGTHENED with the recorded contact kind
$q="$c\tests\probe_cd007_world_burst.gd"
$tv = Get-Content $q -Raw -Encoding UTF8
$a4 = @'
	check(str(state.terminal_reason)=="impact_world",
		"CD07 world W1 the terminal state names a WORLD contact rather than a vehicle or nothing: %s" % str(state.terminal_reason))
'@
$b4 = @'
	# The emitter owns the terminal reason, so requiring the terminal to say impact_world was my invention; what must hold is
	# that the WORLD contact is RECORDED, which is a stronger statement than the constant I first wrote.
	var kind := str(burst.get("contact_kind",""))
	print("[CD07 world] W1 recorded contact kind=%s (terminal is owned by the emitter: %s)" % [kind,str(state.terminal_reason)])
	check(kind=="world_contact",
		"CD07 world W1 the burst RECORDS that this was a world contact rather than a vehicle: %s" % kind)
'@
$n4 = ([regex]::Matches($tv,[regex]::Escape($a4))).Count
$tv = $tv.Replace($a4,$b4)
$tv = $tv.Replace('check(bool(burst.get("external",false)),
		"CD07 world W3 it is recorded as an external burst with no target: external=%s" % str(burst.get("external","")))','check(bool(burst.get("external",false)),
		"CD07 world W3 it is recorded as an external burst with no target, which a fuzeless contact HE previously failed to record at all: external=%s" % str(burst.get("external","")))')
[IO.File]::WriteAllText($q, $tv, (New-Object Text.UTF8Encoding($false)))
"  probe_judgment_fix=$n4"

& $g --headless --path $c --check-only --script res://scripts/projectiles/projectile_manager.gd *> "$L\parse-w3.log" 2>&1 | Out-Null
"  manager_parse_errors=" + @(Get-Content "$L\parse-w3.log" | Select-String 'Parse Error|Compile Error').Count
& $g --headless --path $c --check-only --script res://tests/probe_cd007_world_burst.gd *> "$L\parse-w4.log" 2>&1 | Out-Null
$e=@(Get-Content "$L\parse-w4.log" | Select-String 'Parse Error|Compile Error').Count
"  probe_parse_errors=$e"
if ($e -gt 0) { Get-Content "$L\parse-w4.log" | Select-String 'Parse Error|at:' | Select-Object -First 5 | ForEach-Object { "   " + $_.Line.Trim().Substring(0,[Math]::Min(175,$_.Line.Trim().Length)) }; exit 1 }
$j = Start-Job -ScriptBlock { param($g,$c,$L) & $g --headless --path $c --fixed-fps 60 -s res://tests/probe_cd007_world_burst.gd *> "$L\cd007-wb2.log" } -ArgumentList $g,$c,$L
$d = Wait-Job $j -Timeout 400
if (-not $d) { Stop-Job $j; "  timeout" } else { "  done" }
Remove-Job $j
Get-Content "$L\cd007-wb2.log" -Encoding UTF8 -ErrorAction SilentlyContinue | Select-String 'CD07 world\]|=== 结果|CD07_WORLD_BURST|^\[FAIL\]' | ForEach-Object { "  " + $_.Line.Trim().Substring(0,[Math]::Min(250,$_.Line.Trim().Length)) }
