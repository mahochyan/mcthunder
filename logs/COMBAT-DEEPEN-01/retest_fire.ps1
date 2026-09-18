$c='E:\AIprogram\mcthunder-cont'
$p="$c\tests\probe_cd007_he_runtime.gd"
$txt = Get-Content $p -Raw -Encoding UTF8
$a = @'
		var manager := ProjectileManager.new(); manager.presentation_enabled=false
		world.add_child(manager); manager.set_physics_process(false)
		manager.damage_handler = Callable(actor2,"apply_projectile_damage")
'@
$b = @'
		var manager := ProjectileManager.new(); manager.presentation_enabled=false
		world.add_child(manager); manager.set_physics_process(false)
		manager.damage_handler = Callable(actor2,"apply_projectile_damage")
		# The target's own rebuilt layout, so the round actually MEETS the vehicle this time: the previous leg passed an
		# empty snapshot list and the round met nothing at all, which is why its outcome said nothing about contact.
		var target_layout: VehicleLayoutDefinition = actor2.state._damage_layout
		var target_snapshot := QuerySnapshotBuilder.build_from_vehicle(actor2.tank,target_layout)
		target_snapshot["entity_id"] = str(vid); target_snapshot["life_id"] = 7
		print("[CD07 landed] R2 target layout=%s armour_patches=%d" % [
			str(target_layout.id) if target_layout != null else "<none>",
			target_layout.armor_patches.size() if target_layout != null else -1])
'@
$n1 = ([regex]::Matches($txt,[regex]::Escape($a))).Count
$txt = $txt.Replace($a,$b)
$n2 = ([regex]::Matches($txt,'manager\.advance_projectile\(state,1\.0/240\.0,\[\],space\)')).Count
$txt = $txt.Replace('manager.advance_projectile(state,1.0/240.0,[],space)','manager.advance_projectile(state,1.0/240.0,[target_snapshot],space)')
[IO.File]::WriteAllText($p, $txt, (New-Object Text.UTF8Encoding($false)))
"  snapshot_added=$n1 ; advance_with_snapshot=$n2"
$g='E:\AIprogram\mcthunder\tools\godot\Godot_v4.7.2-stable_win64_console.exe'
$L="$c\logs\COMBAT-DEEPEN-01"
& $g --headless --path $c --check-only --script res://tests/probe_cd007_he_runtime.gd *> "$L\parse-hert3.log" 2>&1 | Out-Null
$err=@(Get-Content "$L\parse-hert3.log" | Select-String 'Parse Error|Compile Error').Count
"  parse_errors=$err"
if ($err -gt 0) { Get-Content "$L\parse-hert3.log" | Select-String 'Parse Error|at:' | Select-Object -First 5 | ForEach-Object { "   " + $_.Line.Trim().Substring(0,[Math]::Min(175,$_.Line.Trim().Length)) }; exit 1 }
$j = Start-Job -ScriptBlock { param($g,$c,$L) & $g --headless --path $c --fixed-fps 60 -s res://tests/probe_cd007_he_runtime.gd *> "$L\cd007-hert3.log" } -ArgumentList $g,$c,$L
$d = Wait-Job $j -Timeout 400
if (-not $d) { Stop-Job $j; "  timeout" } else { "  done" }
Remove-Job $j
Get-Content "$L\cd007-hert3.log" -Encoding UTF8 -ErrorAction SilentlyContinue | Select-String 'R2 target layout|R2 OUTCOME|CD07_HE_RUNTIME|=== 结果|^\[FAIL\]' | ForEach-Object { "  " + $_.Line.Trim().Substring(0,[Math]::Min(245,$_.Line.Trim().Length)) }
