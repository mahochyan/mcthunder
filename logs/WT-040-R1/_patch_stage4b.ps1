$c = 'E:\AIprogram\mcthunder-cont'
$enc = New-Object System.Text.UTF8Encoding($false)
$fb = Join-Path $c 'tests\build_release.ps1'
$t = [System.IO.File]::ReadAllText($fb, [System.Text.Encoding]::UTF8)
$nl = if ($t.Contains("`r`n")) { "`r`n" } else { "`n" }
Write-Output ("=== build_release.ps1 (line endings: " + $(if ($nl -eq "`r`n") { 'CRLF' } else { 'LF' }) + ")")

# 1) dot-source the shared matcher, so the build runs exactly the function its test asserts against.
$anchor = '$projectRoot = Split-Path -Parent $PSScriptRoot'
$dot = '. (Join-Path $PSScriptRoot ''candidate_register_match.ps1'')   # WT-040-R1: the shared, tested matcher'
$n = ([regex]::Matches($t, [regex]::Escape($anchor))).Count
if ($n -eq 1) {
    $t = $t.Replace($anchor, $dot + $nl + $anchor)
    Write-Output "  dot-source inserted"
} else { Write-Output ("  dot-source anchor matched x" + $n) }

# 2) replace the inline guard block with a call to that function.
$startMark = '        # WT-040-R1 (user ruling): the register used to accept the whole failure set when the COUNT matched'
$endMark = '        if ($errField -and [int]$errField.Value -ne 0) { throw "Candidate build: $($f.suite) is a registered failure but its run also reported $($errField.Value) unexpected script error(s)" }'
$si = $t.IndexOf($startMark)
$ei = $t.IndexOf($endMark)
Write-Output ("  inline block start=" + ($si -ge 0) + " end=" + ($ei -ge 0))
if ($si -ge 0 -and $ei -gt $si) {
    $endOfLine = $t.IndexOf("`n", $ei)
    if ($endOfLine -lt 0) { $endOfLine = $t.Length }
    $call = @'
        # The match itself lives in tests/candidate_register_match.ps1 so the build runs the very same logic
        # that its negative test asserts against. A copy would prove nothing.
        $verdict = Test-CandidateFailureSet -Entry $entry[0] -FailLines $failLines -ResultRow $f
        if (-not $verdict.ok) { throw ("Candidate build: " + $f.suite + " " + $verdict.reason) }
'@
    $call = $call.TrimEnd("`r","`n").Replace("`n", $nl)
    $t = $t.Substring(0, $si) + $call + $t.Substring($endOfLine + 1)
    Write-Output "  inline block replaced by the shared call"
}
[System.IO.File]::WriteAllText($fb, $t, $enc)

$err = $null
[System.Management.Automation.Language.Parser]::ParseFile($fb, [ref]$null, [ref]$err) | Out-Null
Write-Output ("  build_release.ps1 parse errors = " + $(if ($err) { $err.Count } else { 0 }))
if ($err) { $err | Select-Object -First 4 | ForEach-Object { Write-Output ("      " + $_.Message) } }
Write-Output '=== patch2 done ==='
