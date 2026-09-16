$c = 'E:\AIprogram\mcthunder-cont'
$enc = New-Object System.Text.UTF8Encoding($false)

function Patch-File([string]$path, $pairs, [string]$label) {
    $t = [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)
    $nl = if ($t.Contains("`r`n")) { "`r`n" } else { "`n" }
    Write-Output ("=== " + $label + "  (line endings: " + $(if ($nl -eq "`r`n") { 'CRLF' } else { 'LF' }) + ")")
    $total = 0
    foreach ($pair in $pairs) {
        $needle = $pair[0].Replace("`n", $nl)
        $repl = $pair[1].Replace("`n", $nl)
        $cnt = ([regex]::Matches($t, [regex]::Escape($needle))).Count
        if ($cnt -ge 1) { $t = $t.Replace($needle, $repl); $total += $cnt }
        $head = $needle -replace "`r?`n", ' / '
        if ($head.Length -gt 60) { $head = $head.Substring(0, 60) }
        Write-Output ("  x{0}  {1}" -f $cnt, $head)
    }
    [System.IO.File]::WriteAllText($path, $t, $enc)
    Write-Output ("  applied = " + $total)
}

# --- 1) admission check: per-item result lines ------------------------------------------------
$fa = Join-Path $c 'tests\check_engineering_admission.gd'
$oldA = @'
	print("[admit] rejected: ",catalog.rejected.keys())
	print("ENGINEERING_ADMISSION_PASS" if failed == 0 else "ENGINEERING_ADMISSION_FAIL")
	quit(0 if failed == 0 else 1)
'@
$newA = @'
	print("[admit] rejected: ",catalog.rejected.keys())
	# WT-040-R1: per-vehicle result lines, so the runner reports a real check count for this suite instead of
	# zero. The marker and the exit code already made it a valid gate; this removes the reporting gap.
	var named := 0
	var named_failed := 0
	for id in VehicleCatalog.ENGINEERING_IDS:
		named += 1
		var ok: bool = defs.vehicles.has(id) and not catalog.rejected.has(id)
		if not ok: named_failed += 1
		print(("[PASS] " if ok else "[FAIL] ")+id+" admitted through the production catalog with its binding and model source")
	print("=== result: %d checks, %d failed ===" % [named,named_failed])
	print("ENGINEERING_ADMISSION_PASS" if (failed == 0 and named_failed == 0) else "ENGINEERING_ADMISSION_FAIL")
	quit(0 if (failed == 0 and named_failed == 0) else 1)
'@
Patch-File $fa @(, @($oldA.TrimEnd("`r","`n"), $newA.TrimEnd("`r","`n"))) 'check_engineering_admission.gd'

# --- 2) build register: per-signature expectations --------------------------------------------
$fb = Join-Path $c 'tests\build_release.ps1'
$tb = [System.IO.File]::ReadAllText($fb, [System.Text.Encoding]::UTF8)
$nl = if ($tb.Contains("`r`n")) { "`r`n" } else { "`n" }
$sig1 = "signatures=@([pscustomobject]@{match='at least three actual slots from each team physically reach central approaches';count=1}); "
$sig2 = "signatures=@([pscustomobject]@{match='real defense script pilot completes finite waves with opponent AI untouched';count=2}); "
$n1 = ([regex]::Matches($tb, [regex]::Escape("must_match='physically reach central approaches'"))).Count
$n2 = ([regex]::Matches($tb, [regex]::Escape("must_match='finite waves with opponent AI untouched'"))).Count
Write-Output "=== build_release.ps1 register"
Write-Output ("  register entry 1 matched x" + $n1)
Write-Output ("  register entry 2 matched x" + $n2)
if ($n1 -eq 1) { $tb = $tb.Replace("must_match='physically reach central approaches'", $sig1 + "must_match='physically reach central approaches'") }
if ($n2 -eq 1) { $tb = $tb.Replace("must_match='finite waves with opponent AI untouched'", $sig2 + "must_match='finite waves with opponent AI untouched'") }

$strict = @'
        # WT-040-R1 (user ruling): the register used to accept the whole failure set when the COUNT matched
        # and ONE line matched, so a new failure could replace an old one without changing the total. Every
        # failing line must now be CLAIMED by a registered signature at exactly its expected count, and a
        # registered failure may not travel with an unhealthy run. Both counter-examples the ruling named
        # are therefore refused.
        $expected = 0
        foreach ($sig in $entry[0].signatures) { $expected += [int]$sig.count }
        if ($failLines.Count -ne $expected) { throw "Candidate build: $($f.suite) failed $($failLines.Count) check(s) but its registered signatures account for exactly $expected" }
        foreach ($sig in $entry[0].signatures) {
            $hits = @($failLines | Where-Object { $_ -match $sig.match })
            if ($hits.Count -ne [int]$sig.count) { throw "Candidate build: $($f.suite) signature '$($sig.match)' matched $($hits.Count) failure(s); the register expects exactly $($sig.count)" }
        }
        $unclaimed = @($failLines | Where-Object { $line = $_; @($entry[0].signatures | Where-Object { $line -match $_.match }).Count -eq 0 })
        if ($unclaimed.Count -gt 0) { throw "Candidate build: $($f.suite) carries UNREGISTERED failure(s) no signature claims: $($unclaimed -join ' | ')" }
        $errField = $f.PSObject.Properties['unexpected_errors']
        if ($errField -and [int]$errField.Value -ne 0) { throw "Candidate build: $($f.suite) is a registered failure but its run also reported $($errField.Value) unexpected script error(s)" }
'@
$strict = $strict.TrimEnd("`r","`n").Replace("`n", $nl)
$marker = 'if ($entry[0].must_match -and'
$idx = $tb.IndexOf($marker)
if ($idx -ge 0) {
    $lineEnd = $tb.IndexOf("`n", $idx)
    if ($lineEnd -ge 0) {
        $tb = $tb.Substring(0, $lineEnd + 1) + $strict + $nl + $tb.Substring($lineEnd + 1)
        Write-Output "  strict per-signature guards inserted after the existing guard"
    }
}
[System.IO.File]::WriteAllText($fb, $tb, $enc)

# --- syntax check both files ------------------------------------------------------------------
foreach ($f in @($fb, $fa)) {
    if ($f -like '*.ps1') {
        $err = $null
        [System.Management.Automation.Language.Parser]::ParseFile($f, [ref]$null, [ref]$err) | Out-Null
        Write-Output ("  " + (Split-Path $f -Leaf) + ": parse errors = " + $(if ($err) { $err.Count } else { 0 }))
        if ($err) { $err | Select-Object -First 3 | ForEach-Object { Write-Output ("      " + $_.Message) } }
    }
}
Write-Output '=== patch done ==='
