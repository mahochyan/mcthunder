$c = 'E:\AIprogram\mcthunder-cont'
$enc = New-Object System.Text.UTF8Encoding($false)

function Patch([string]$rel, $pairs, [string]$label) {
    $p = Join-Path $c $rel
    $t = [System.IO.File]::ReadAllText($p, [System.Text.Encoding]::UTF8)
    $nl = if ($t.Contains("`r`n")) { "`r`n" } else { "`n" }
    Write-Output ("=== " + $label + " (" + $(if ($nl -eq "`r`n") { 'CRLF' } else { 'LF' }) + ")")
    $total = 0
    foreach ($pair in $pairs) {
        $needle = $pair[0].Replace("`n", $nl)
        $repl = $pair[1].Replace("`n", $nl)
        $cnt = ([regex]::Matches($t, [regex]::Escape($needle))).Count
        if ($cnt -ge 1) { $t = $t.Replace($needle, $repl); $total += $cnt }
        $head = ($needle -replace "`r?`n", ' / ')
        if ($head.Length -gt 58) { $head = $head.Substring(0, 58) }
        Write-Output ("  x{0}  {1}" -f $cnt, $head)
    }
    [System.IO.File]::WriteAllText($p, $t, $enc)
    Write-Output ("  applied = " + $total)
}

# --- 1) VehicleCatalog: load_all stays historical-only; engineering gets its own explicit entry -----
$oldLoop = @'
	# The engineering vehicles load through the same register() call, so a rejected one is named, not hidden.
	for eid in ENGINEERING_IDS:
		var efile := FileAccess.open(ENGINEERING_DIR+eid+".json",FileAccess.READ)
		if efile == null: errors.append(eid+": missing engineering packet"); continue
		var eparsed: Variant = JSON.parse_string(efile.get_as_text())
		if not eparsed is Dictionary: errors.append(eid+": malformed JSON"); continue
		var eresult := register(eparsed,defs)
		if not eresult.ok:
			for error in eresult.errors: errors.append(eid+": "+error)
	return {"ok":errors.is_empty(),"errors":errors}
'@
$newLoop = @'
	# WT-040-R1: load_all stays HISTORICAL-ONLY on purpose. Loading the engineering vehicles here changed a
	# historical contract - run_historical_checks asserts exactly four historical configurations - so the
	# engineering vehicles are an explicit, separate admission step, see load_engineering below.
	return {"ok":errors.is_empty(),"errors":errors}

## WT-040-R1: admit the two engineering vehicles from configs/vehicles/engineering. A SEPARATE entry point so
## the historical set stays exactly what it was, while the engineering admission still goes through the same
## register() call: full pipeline validation plus the model binding check against the delivered artefact.
func load_engineering(defs: VehicleDefs) -> Dictionary:
	var errors: Array[String] = []
	for eid in ENGINEERING_IDS:
		var efile := FileAccess.open(ENGINEERING_DIR+eid+".json",FileAccess.READ)
		if efile == null: errors.append(eid+": missing engineering packet"); continue
		var eparsed: Variant = JSON.parse_string(efile.get_as_text())
		if not eparsed is Dictionary: errors.append(eid+": malformed JSON"); continue
		var eresult := register(eparsed,defs)
		if not eresult.ok:
			for error in eresult.errors: errors.append(eid+": "+error)
	return {"ok":errors.is_empty(),"errors":errors}
'@
Patch 'scripts\content\vehicle_catalog.gd' @(, @($oldLoop.TrimEnd("`r","`n"), $newLoop.TrimEnd("`r","`n"))) 'vehicle_catalog.gd'

# --- 2) the three engineering scripts call BOTH loaders -------------------------------------------
$merge = @'
	var historical: Dictionary = catalog.load_all(defs)
	var engineering: Dictionary = catalog.load_engineering(defs)
	var loaded := {"ok": bool(historical.get("ok",false)) and bool(engineering.get("ok",false)),
		"errors": (historical.get("errors",[]) as Array) + (engineering.get("errors",[]) as Array)}
'@
Patch 'tests\check_engineering_admission.gd' @(, @("`tvar result: Dictionary = catalog.load_all(defs)", $merge.TrimEnd("`r","`n") + "`n`tvar result: Dictionary = loaded")) 'check_engineering_admission.gd'
Patch 'tests\run_engineering_runtime_checks.gd' @(, @("`tvar loaded: Dictionary = catalog.load_all(defs)", $merge.TrimEnd("`r","`n"))) 'run_engineering_runtime_checks.gd'
Patch 'tests\run_engineering_damage_checks.gd' @(, @("`tvar loaded: Dictionary = catalog.load_all(defs)", $merge.TrimEnd("`r","`n"))) 'run_engineering_damage_checks.gd'

# --- 3) the shared matcher must read the REAL shape of unexpected_errors (an array, not a number) ---
$oldErr = @'
        if ($names -contains 'unexpected_errors') {
            $unexpected = [int]$ResultRow.unexpected_errors
            if ($unexpected -ne 0) { return @{ ok = $false; reason = "is a registered failure but its run also reported $unexpected unexpected script error(s)" } }
        }
'@
$newErr = @'
        if ($names -contains 'unexpected_errors') {
            # The real field is an ARRAY of diagnostic lines, not a number. My first version cast it to int,
            # which passed a negative test that used numbers and would have thrown on real evidence - the
            # test and the data had different shapes, which is the lesson, not a detail.
            $unexpected = @($ResultRow.unexpected_errors | Where-Object { $null -ne $_ -and "$_" -ne '' })
            if ($unexpected.Count -ne 0) { return @{ ok = $false; reason = "is a registered failure but its run also reported $($unexpected.Count) unexpected script error(s)" } }
        }
'@
Patch 'tests\candidate_register_match.ps1' @(, @($oldErr.TrimEnd("`r","`n"), $newErr.TrimEnd("`r","`n"))) 'candidate_register_match.ps1'

# --- 4) the negative test gains the ARRAY shapes, so it exercises what the evidence actually carries ---
$oldCase = @'
$sickRow = [pscustomobject]@{ suite='run_industrial_battle_checks'; checks=16; unexpected_errors=3; timed_out=$false; exit_known=$true; passed=$false }
'@
$newCase = @'
# The real field is an ARRAY of lines; both shapes are asserted so the test cannot pass on a shape that never
# occurs. The numeric form is kept because an empty result may legitimately serialise as 0.
$sickRow = [pscustomobject]@{ suite='run_industrial_battle_checks'; checks=16; unexpected_errors=@('SCRIPT ERROR: sample diagnostic'); timed_out=$false; exit_known=$true; passed=$false }
$sickRowNumeric = [pscustomobject]@{ suite='run_industrial_battle_checks'; checks=16; unexpected_errors=3; timed_out=$false; exit_known=$true; passed=$false }
$cleanArray = [pscustomobject]@{ suite='run_industrial_battle_checks'; checks=16; unexpected_errors=@(); timed_out=$false; exit_known=$true; passed=$false }
'@
Patch 'tests\check_candidate_register_match.ps1' @(, @($oldCase.TrimEnd("`r","`n"), $newCase.TrimEnd("`r","`n"))) 'check_candidate_register_match.ps1'

$tailOld = @'
$v = Test-CandidateFailureSet -Entry $entryBattle -FailLines @($old) -ResultRow $sickRow
Check (-not $v.ok) "COUNTER-EXAMPLE 2a refused: a registered failure whose run also reported script errors (reason: $($v.reason))"
'@
$tailNew = @'
$v = Test-CandidateFailureSet -Entry $entryBattle -FailLines @($old) -ResultRow $sickRow
Check (-not $v.ok) "COUNTER-EXAMPLE 2a refused: a registered failure whose run also reported script errors, ARRAY shape (reason: $($v.reason))"
$v = Test-CandidateFailureSet -Entry $entryBattle -FailLines @($old) -ResultRow $sickRowNumeric
Check (-not $v.ok) "COUNTER-EXAMPLE 2a' refused: the same, numeric shape (reason: $($v.reason))"
$v = Test-CandidateFailureSet -Entry $entryBattle -FailLines @($old) -ResultRow $cleanArray
Check $v.ok "an EMPTY array of diagnostics still accepts a registered failure (reason: $($v.reason))"
'@
Patch 'tests\check_candidate_register_match.ps1' @(, @($tailOld.TrimEnd("`r","`n"), $tailNew.TrimEnd("`r","`n"))) 'check_candidate_register_match.ps1 (cases)'

Write-Output '=== patch3 done ==='
