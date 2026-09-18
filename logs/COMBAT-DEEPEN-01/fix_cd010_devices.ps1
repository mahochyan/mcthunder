$c='E:\AIprogram\mcthunder-cont'
$g='E:\AIprogram\mcthunder\tools\godot\Godot_v4.7.2-stable_win64_console.exe'
$L="$c\logs\COMBAT-DEEPEN-01"
$T=[char]9
$p="$c\tests\run_cd010_scene_checks.gd"
$t = Get-Content $p -Raw -Encoding UTF8

'=== S3 device: reference the class directly and check module KINDS, not module ids ==='
$a3 = @'
	var has_protection := (aleo.state.module_states.has("ammo_partition") and aleo.state.module_states.has("blowout_panel"))
	print("[CD10] S3 Leopard has partition=%s vent=%s ; reaction profile implemented=%s" % [
		str(aleo.state.module_states.has("bustle_partition")),str(aleo.state.module_states.has("bustle_vent")),
		str(ClassDB.class_exists("AmmoReactionProfile"))])
	met("CD10-T03", ClassDB.class_exists("AmmoReactionProfile") and has_protection,
'@
$b3 = @'
	var kinds: Array = []
	for mid in aleo.state.module_states:
		kinds.append(str((aleo.state.module_states[mid] as Dictionary).get("kind","")))
	var has_barrier := "ammo_partition" in kinds
	var has_vent := "blowout_panel" in kinds
	var profile_version := AmmoReactionProfile.VERSION
	print("[CD10] S3 Leopard kinds=%s ; barrier=%s vent=%s ; reaction profile version=%s" % [
		str(kinds),str(has_barrier),str(has_vent),profile_version])
	met("CD10-T03", profile_version != "" and has_barrier and has_vent,
'@
$n3 = ([regex]::Matches($t,[regex]::Escape($a3))).Count
$t = $t.Replace($a3,$b3)

'=== S4 device: actually judge a reaction before and after the partition is lost ==='
$a4 = @'
	var intact_loss := aleo.gunner.inventory.total_available()
	_damage_module(aleo.state,"ammo_partition",0.0,"cd010_partition")
	var perforated_loss := aleo.gunner.inventory.total_available()
	print("[CD10] S4 inventory total intact=%d after partition loss=%d ; vent integrity=%s" % [
		intact_loss,perforated_loss,str((aleo.state.module_states.get("bustle_vent",{}) as Dictionary).get("integrity",""))])
	met("CD10-T04", intact_loss != perforated_loss or ClassDB.class_exists("AmmoReactionProfile"),
'@
$b4 = @'
	var stock := int(aleo.gunner.inventory.racks.get("ammo_ready",0))
	var intact := aleo.state.judge_ammo_reaction("ammo_ready","chemical",stock,4242)
	_damage_module(aleo.state,"ammo_partition",0.0,"cd010_partition")
	var perforated := aleo.state.judge_ammo_reaction("ammo_ready","chemical",stock,4242)
	print("[CD10] S4 stock=%d ; intact compartment=%s outcome=%s loss=%d ; perforated=%s outcome=%s loss=%d" % [
		stock,str(intact.get("compartment","")),str(intact.get("outcome","")),int(intact.get("loss",0)),
		str(perforated.get("compartment","")),str(perforated.get("outcome","")),int(perforated.get("loss",0))])
	met("CD10-T04", str(intact.get("compartment","")) != str(perforated.get("compartment",""))
		and (int(perforated.get("loss",0)) >= int(intact.get("loss",0))),
'@
$n4 = ([regex]::Matches($t,[regex]::Escape($a4))).Count
$t = $t.Replace($a4,$b4)
[IO.File]::WriteAllText($p, $t, (New-Object Text.UTF8Encoding($false)))
"  s3_device=$n3 ; s4_device=$n4 ; lines=" + @(Get-Content $p -Encoding UTF8).Count
& $g --headless --path $c --check-only --script res://tests/run_cd010_scene_checks.gd *> "$L\pc10c.log" 2>&1 | Out-Null
$e = @(Get-Content "$L\pc10c.log" | Select-String 'Parse Error|Compile Error').Count
"  parse_errors=$e"
if ($e -gt 0) { Get-Content "$L\pc10c.log" | Select-String 'Parse Error|at:' | Select-Object -First 5 | ForEach-Object { "      " + $_.Line.Trim().Substring(0,[Math]::Min(180,$_.Line.Trim().Length)) }; exit 1 }
$j = Start-Job -ScriptBlock { param($g,$c,$L) & $g --headless --path $c --fixed-fps 60 -s res://tests/run_cd010_scene_checks.gd *> "$L\c10w.log" } -ArgumentList $g,$c,$L
$d = Wait-Job $j -Timeout 400; if (-not $d) { Stop-Job $j } ; Remove-Job $j
Start-Sleep -Milliseconds 400
$o = Get-Content "$L\c10w.log" -Encoding UTF8 -ErrorAction SilentlyContinue
"  errors=" + @($o|Select-String 'SCRIPT ERROR').Count
$o | Select-String 'CD10\] S3|CD10\] S4|CD10-T0|not_yet_met=|CD10_SCENES|^\[FAIL\]' | ForEach-Object { "  " + $_.Line.Trim().Substring(0,[Math]::Min(235,$_.Line.Trim().Length)) }
