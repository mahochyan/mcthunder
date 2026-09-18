$c='E:\AIprogram\mcthunder-cont'
$g='E:\AIprogram\mcthunder\tools\godot\Godot_v4.7.2-stable_win64_console.exe'
$L="$c\logs\COMBAT-DEEPEN-01"
$T=[char]9
$p="$c\scripts\projectiles\fragment_system.gd"
$txt = Get-Content $p -Raw -Encoding UTF8

# TEMPORARY CD07 instrumentation, filtered to the external blast and capped, removed in the same round.
$a1 = '	var count: int=int(spall.profile.count) if directional else ShellEffectPolicy.MAX_FRAGMENTS'
$b1 = $a1 + "`r`n" + $T + 'var _cd07_trace := 0  # TEMPORARY' + "`r`n" + `
  $T + 'if external_blast:' + "`r`n" + `
  $T+$T + 'print("[CD07 frag] setup eligible=%d target_empty=%s delayed=%s dir=%s range=%.2f budget=%.2f" % [' + "`r`n" + `
  $T+$T+$T + 'eligible.size(),str(target.is_empty()),str(delayed),str(directional),remaining if false else ShellEffectPolicy.FRAGMENT_RANGE_M,ShellEffectPolicy.FRAGMENT_BUDGET_MM])'
$n1 = ([regex]::Matches($txt,[regex]::Escape($a1))).Count
$txt = $txt.Replace($a1,$b1)

$a2 = '			if not qr.get("ok",false) or not qr.get("complete",false): fragment.reason = "unresolved_geometry"; break'
$b2 = '			if external_blast and _cd07_trace < 4:' + "`r`n" + `
  $T+$T+$T + '_cd07_trace += 1' + "`r`n" + `
  $T+$T+$T + 'print("[CD07 frag] qr ok=%s complete=%s events=%d from=%s dir=%s" % [str(qr.get("ok",false)),str(qr.get("complete",false)),qr.get("events",[]).size(),str(point),str(direction)])' + "`r`n" + `
  $T + $a2
$n2 = ([regex]::Matches($txt,[regex]::Escape($a2))).Count
$txt = $txt.Replace($a2,$b2)

$a3 = '			if budget <= 0.00001: fragment.reason = "budget_exhausted"; break'
$b3 = $a3 + "`r`n" + $T+$T+$T + 'if external_blast: print("[CD07 frag] end id=%d reason=%s queries=%d contacts=%d path=%d" % [fragment_id,str(fragment.reason),int(fragment.queries),fragment.contacts.size(),fragment.path.size()])'
$n3 = ([regex]::Matches($txt,[regex]::Escape($a3))).Count
$txt = $txt.Replace($a3,$b3)
[IO.File]::WriteAllText($p, $txt, (New-Object Text.UTF8Encoding($false)))
"  traces: setup=$n1 qr=$n2 end=$n3"

& $g --headless --path $c --check-only --script res://scripts/projectiles/fragment_system.gd *> "$L\parse-tr.log" 2>&1 | Out-Null
$err=@(Get-Content "$L\parse-tr.log" | Select-String 'Parse Error|Compile Error').Count
"  parse_errors=$err"
if ($err -gt 0) { Get-Content "$L\parse-tr.log" | Select-String 'Parse Error|at:' | Select-Object -First 6 | ForEach-Object { "   " + $_.Line.Trim().Substring(0,[Math]::Min(175,$_.Line.Trim().Length)) }; exit 1 }
$j = Start-Job -ScriptBlock { param($g,$c,$L) & $g --headless --path $c --fixed-fps 60 -s res://tests/probe_cd007_wall_occlusion.gd *> "$L\cd007-tr.log" } -ArgumentList $g,$c,$L
$d = Wait-Job $j -Timeout 420
if (-not $d) { Stop-Job $j; "  timeout" } else { "  done" }
Remove-Job $j
Get-Content "$L\cd007-tr.log" -Encoding UTF8 -ErrorAction SilentlyContinue | Select-String 'CD07 frag|CD07 occl\]|CD07_WALL_OCCLUSION' | Select-Object -First 22 | ForEach-Object { "  " + $_.Line.Trim().Substring(0,[Math]::Min(240,$_.Line.Trim().Length)) }
