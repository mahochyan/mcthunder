$c='E:\AIprogram\mcthunder-cont'
$p="$c\tests\probe_cd007_he_runtime.gd"
$txt = Get-Content $p -Raw -Encoding UTF8
# do NOT rename delivered engineering packets: their sources and admission gates are bound to their real identity
$a1 = @'
		var tag := "test_cd007_landed_"+str(vid)
		eng.id = tag
		for source in eng.sources.values(): source.applies_to_identity_ids=[eng.id]
		var eng_sources := fixture_asset(eng,1.0)
		var registered := VehicleCatalog.new(eng_sources).register(eng,defs)
		check(registered.ok,"CD07 landed R1 %s registers" % str(vid))
		if not registered.ok: continue
		var actor := VehicleActor.new(); world.add_child(actor)
		var installed := actor.setup(defs,tag,tag,index,Transform3D.IDENTITY,2,null)
'@
$b1 = @'
		# The identity is left alone: renaming a delivered engineering packet invalidates its sources and its delivered
		# artefact gates, which is exactly the mistake recorded in the previous rounds.
		var eng_sources := fixture_asset(eng,1.0)
		var registered := VehicleCatalog.new(eng_sources).register(eng,defs)
		check(registered.ok,"CD07 landed R1 %s registers" % str(vid))
		if not registered.ok: continue
		var actor := VehicleActor.new(); world.add_child(actor)
		var installed := actor.setup(defs,str(vid),str(vid),index,Transform3D.IDENTITY,2,null)
'@
$n1 = ([regex]::Matches($txt,[regex]::Escape($a1))).Count
$txt = $txt.Replace($a1,$b1)
$a2 = @'
		var tag2 := "test_cd007_landed_fire_"+vid
		eng.id = tag2
		for source in eng.sources.values(): source.applies_to_identity_ids=[eng.id]
		var eng_sources2 := fixture_asset(eng,1.0)
		var defs2 := VehicleDefs.new()
		var reg2 := VehicleCatalog.new(eng_sources2).register(eng,defs2)
		check(reg2.ok,"CD07 landed R2 the firing vehicle registers")
		var actor2 := VehicleActor.new(); world.add_child(actor2)
		var installed2 := actor2.setup(defs2,tag2,tag2,7,Transform3D.IDENTITY,2,null)
'@
$b2 = @'
		var eng_sources2 := fixture_asset(eng,1.0)
		var defs2 := VehicleDefs.new()
		var reg2 := VehicleCatalog.new(eng_sources2).register(eng,defs2)
		check(reg2.ok,"CD07 landed R2 the firing vehicle registers")
		var actor2 := VehicleActor.new(); world.add_child(actor2)
		var installed2 := actor2.setup(defs2,str(vid),str(vid),7,Transform3D.IDENTITY,2,null)
'@
$n2 = ([regex]::Matches($txt,[regex]::Escape($a2))).Count
$txt = $txt.Replace($a2,$b2)
[IO.File]::WriteAllText($p, $txt, (New-Object Text.UTF8Encoding($false)))
"  r1_fix=$n1 r2_fix=$n2 ; renames_left=" + ([regex]::Matches($txt,'eng\.id = ')).Count
$g='E:\AIprogram\mcthunder\tools\godot\Godot_v4.7.2-stable_win64_console.exe'
$L="$c\logs\COMBAT-DEEPEN-01"
& $g --headless --path $c --check-only --script res://tests/probe_cd007_he_runtime.gd *> "$L\parse-hert2.log" 2>&1 | Out-Null
$err=@(Get-Content "$L\parse-hert2.log" | Select-String 'Parse Error|Compile Error').Count
"  parse_errors=$err"
if ($err -gt 0) { Get-Content "$L\parse-hert2.log" | Select-String 'Parse Error|at:' | Select-Object -First 5 | ForEach-Object { "   " + $_.Line.Trim().Substring(0,[Math]::Min(175,$_.Line.Trim().Length)) }; exit 1 }
$j = Start-Job -ScriptBlock { param($g,$c,$L) & $g --headless --path $c --fixed-fps 60 -s res://tests/probe_cd007_he_runtime.gd *> "$L\cd007-hert2.log" } -ArgumentList $g,$c,$L
$d = Wait-Job $j -Timeout 400
if (-not $d) { Stop-Job $j; "  timeout" } else { "  done" }
Remove-Job $j
Get-Content "$L\cd007-hert2.log" -Encoding UTF8 -ErrorAction SilentlyContinue | Select-String 'CD07 landed|=== 结果|CD07_HE_RUNTIME|^\[FAIL\]' | ForEach-Object { "  " + $_.Line.Trim().Substring(0,[Math]::Min(245,$_.Line.Trim().Length)) }
