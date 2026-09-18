$c='E:\AIprogram\mcthunder-cont'
$g='E:\AIprogram\mcthunder\tools\godot\Godot_v4.7.2-stable_win64_console.exe'
$L="$c\logs\COMBAT-DEEPEN-01"
$T=[char]9
$p="$c\tests\run_cd009_scene_checks.gd"
$lines = @(Get-Content $p -Encoding UTF8)
$n0 = $lines.Count
$s3 = -1; $s4 = -1
for ($i=0; $i -lt $lines.Count; $i++) {
  if ($lines[$i] -match 'S3 breech failure on one real request') { $s3 = $i }
  if ($s3 -ge 0 -and $lines[$i] -match 'S4 barrel and the two turret axes') { $s4 = $i; break }
}
'  S3 block spans lines ' + ($s3+1) + ' to ' + ($s4) + ' (' + ($s4-$s3) + ' lines)'
if ($s3 -lt 0 -or $s4 -lt 0) { '  ABORT: block not found, nothing changed'; exit 1 }
$new = @(
  ($T+'# ── S3 breech failure judged ONCE at a real fire request, through the production gunner.'),
  ($T+'var cd009_defs := VehicleDefs.new()'),
  ($T+'var cd009_catalog := VehicleCatalog.new()'),
  ($T+'if cd009_defs.load_defaults().ok and cd009_catalog.load_all(cd009_defs).ok:'),
  ($T+$T+'var vid: String = str(VehicleCatalog.IDS[0])'),
  ($T+$T+'var actor := VehicleActor.new(); root.add_child(actor)'),
  ($T+$T+'var packet: Dictionary = cd009_catalog.packages[vid]'),
  ($T+$T+'if actor.setup(cd009_defs,vid,"cd009_fire",1,Transform3D.IDENTITY,2,packet.get("layout",null)).ok:'),
  ($T+$T+$T+'actor.set_physics_process(false); actor.tank.set_physics_process(false)'),
  ($T+$T+$T+'var manager := ProjectileManager.new(); manager.presentation_enabled=false'),
  ($T+$T+$T+'root.add_child(manager); manager.set_physics_process(false)'),
  ($T+$T+$T+'actor.gunner.projectile_manager = manager'),
  ($T+$T+$T+'await _frames(3)'),
  ($T+$T+$T+'# Damage the breech so the declared chance is non zero, then request for real.'),
  ($T+$T+$T+'_damage_module(actor.state,"breech",20.0)'),
  ($T+$T+$T+'var rounds_before: int = actor.gunner.rounds_remaining'),
  ($T+$T+$T+'var jam_seen := 0'),
  ($T+$T+$T+'var same_outcome := true'),
  ($T+$T+$T+'for attempt in 40:'),
  ($T+$T+$T+$T+'var first := actor.gunner.try_fire()'),
  ($T+$T+$T+$T+'var reason_first := actor.gunner.blocked_reason'),
  ($T+$T+$T+$T+'# A repeat of the SAME request must not re-roll: same shot id, same seed, same answer.'),
  ($T+$T+$T+$T+'var second := actor.gunner.try_fire()'),
  ($T+$T+$T+$T+'if first != second or reason_first != actor.gunner.blocked_reason: same_outcome = false'),
  ($T+$T+$T+$T+'if reason_first == "breech_jam": jam_seen += 1'),
  ($T+$T+$T+$T+'actor.gunner.cooldown_left = 0.0'),
  ($T+$T+$T+$T+'if not first and reason_first == "breech_jam":'),
  ($T+$T+$T+$T+$T+'break'),
  ($T+$T+$T+$T+'if first: break'),
  ($T+$T+$T+'var record: Dictionary = actor.state.breech_failure'),
  ($T+$T+$T+'print("[CD09] S3 jam_seen=%d same_outcome=%s record=%s rounds %d -> %d" % ['),
  ($T+$T+$T+$T+'jam_seen,str(same_outcome),str(record),rounds_before,actor.gunner.rounds_remaining])'),
  ($T+$T+$T+'met("CD09-T03", not record.is_empty() and same_outcome and int(record.get("shot_id",-1)) > 0'),
  ($T+$T+$T+$T+'and str(record.get("rule","")) != "" and int(record.get("seed",0)) != 0'),
  ($T+$T+$T+$T+'"a breech failure must be decided once at the correct stage of a real fire request, with a seeded outcome and an inventory result, never re-rolled per frame",'),
  ($T+$T+$T+$T+'"a real fire request produced no committed breech failure record with a seed and a rule")'),
  ($T+$T+$T+'met("CD09-T03", actor.gunner.rounds_remaining == rounds_before'),
  ($T+$T+$T+$T+'or int(record.get("round_consumed",true)) == false,'),
  ($T+$T+$T+$T+'"a jam must consume no round, which is the frozen rule",'),
  ($T+$T+$T+$T+'"a jam consumed a round, so the frozen inventory rule does not hold")'),
  ($T+$T+$T+'manager.queue_free(); actor.queue_free()')
)
$out = @()
for ($i=0; $i -lt $s3; $i++) { $out += $lines[$i] }
$out += $new
for ($i=$s4; $i -lt $lines.Count; $i++) { $out += $lines[$i] }
[IO.File]::WriteAllLines($p, $out, (New-Object Text.UTF8Encoding($false)))
'  scene lines ' + $n0 + ' -> ' + $out.Count + ' (delta = ' + ($out.Count-$n0) + ', new block ' + $new.Count + ' replaced ' + ($s4-$s3) + ')'
'=== SHAPE FIRST ==='
& $g --headless --path $c --check-only --script res://tests/run_cd009_scene_checks.gd *> "$L\s145.log" 2>&1 | Out-Null
'  scene parse_errors=' + @(Get-Content "$L\s145.log" | Select-String 'Parse Error|Compile Error').Count
@(Get-Content "$L\s145.log" | Select-String 'Parse Error|at:') | Select-Object -First 5 | ForEach-Object { '      ' + $_.Line.Trim().Substring(0,[Math]::Min(180,$_.Line.Trim().Length)) }
if (@(Get-Content "$L\s145.log" | Select-String 'Parse Error').Count -gt 0) { '  REVERTING the scene because the shape is wrong'; git -C $c checkout -- tests/run_cd009_scene_checks.gd; exit 1 }
$j = Start-Job -ScriptBlock { param($g,$c,$L) & $g --headless --path $c --fixed-fps 60 -s res://tests/run_cd009_scene_checks.gd *> "$L\c9j.log" } -ArgumentList $g,$c,$L
$d = Wait-Job $j -Timeout 400; if (-not $d) { Stop-Job $j } ; Remove-Job $j
Start-Sleep -Milliseconds 400
$o = Get-Content "$L\c9j.log" -Encoding UTF8 -ErrorAction SilentlyContinue
'  log lines=' + $o.Count + ' ; errors=' + @($o|Select-String 'SCRIPT ERROR').Count
$o | Select-String 'CD09-T0|not_yet_met=|CD09_SCENES|CD09\] S3|^\[FAIL\]' | ForEach-Object { '  ' + $_.Line.Trim().Substring(0,[Math]::Min(225,$_.Line.Trim().Length)) }
