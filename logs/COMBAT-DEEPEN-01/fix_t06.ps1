$c='E:\AIprogram\mcthunder-cont'
$g='E:\AIprogram\mcthunder\tools\godot\Godot_v4.7.2-stable_win64_console.exe'
$L="$c\logs\COMBAT-DEEPEN-01"
$p="$c\tests\probe_cd007_finality.gd"
$txt = Get-Content $p -Raw -Encoding UTF8

# (a) find the real object field instead of guessing: print the record's own keys once
$a1 = '	var keys: Array = []'
$b1 = '	if st.damage_records.size()>=1: print("[CD07 T06] M1 record keys=%s" % str((st.damage_records[0] as Dictionary).keys()))' + "`r`n" + `
  '	var keys: Array = []'
$n1 = ([regex]::Matches($txt,[regex]::Escape($a1))).Count
$txt = $txt.Replace($a1,$b1)

# (b) M2 must measure from a FRESH layout, because M1 already broke this module - that is my rig's fault, not the product's
$a2 = '	var before: float = float(target.state.module_states.jet_component.integrity)'
$b2 = '	# The previous leg already destroyed this module, so the baseline has to be a fresh layout; comparing against a' + "`r`n" + `
  '	# damaged starting point would have measured the earlier shot rather than this one.' + "`r`n" + `
  '	target.set_damage_layout(compartment())' + "`r`n" + `
  '	var before: float = float(target.state.module_states.jet_component.integrity)'
$n2 = ([regex]::Matches($txt,[regex]::Escape($a2))).Count
$txt = $txt.Replace($a2,$b2)

# (c) the verdict line must depend on the checks rather than being printed unconditionally
$a3 = '	print("CD07_MULTI_TARGET_FINALITY PASS")'
$b3 = '	print("CD07_MULTI_TARGET_FINALITY_%s" % ("PASS" if failures==0 else "FAIL"))'
$n3 = ([regex]::Matches($txt,[regex]::Escape($a3))).Count
$txt = $txt.Replace($a3,$b3)
[IO.File]::WriteAllText($p, $txt, (New-Object Text.UTF8Encoding($false)))
"  key_diag=$n1 fresh_baseline=$n2 conditional_verdict=$n3"

& $g --headless --path $c --check-only --script res://tests/probe_cd007_finality.gd *> "$L\parse-t06b.log" 2>&1 | Out-Null
$err=@(Get-Content "$L\parse-t06b.log" | Select-String 'Parse Error|Compile Error').Count
"  parse_errors=$err"
if ($err -gt 0) { Get-Content "$L\parse-t06b.log" | Select-String 'Parse Error|at:' | Select-Object -First 5 | ForEach-Object { "   " + $_.Line.Trim().Substring(0,[Math]::Min(175,$_.Line.Trim().Length)) }; exit 1 }
$j = Start-Job -ScriptBlock { param($g,$c,$L) & $g --headless --path $c --fixed-fps 60 -s res://tests/probe_cd007_finality.gd *> "$L\cd007-t06b.log" } -ArgumentList $g,$c,$L
$d = Wait-Job $j -Timeout 400
if (-not $d) { Stop-Job $j; "  timeout" } else { "  done" }
Remove-Job $j
Get-Content "$L\cd007-t06b.log" -Encoding UTF8 -ErrorAction SilentlyContinue | Select-String 'CD07 T06|CD07_MULTI_TARGET_FINALITY|^\[FAIL\]' | ForEach-Object { "  " + $_.Line.Trim().Substring(0,[Math]::Min(250,$_.Line.Trim().Length)) }
