$c = 'E:\AIprogram\mcthunder-cont'
$enc = New-Object System.Text.UTF8Encoding($false)
$p = Join-Path $c 'tests\build_release.ps1'

# Restore my own uncommitted damage (this file is committed; the corruption was mine and is seconds old).
$good = & git -C $c show HEAD:tests/build_release.ps1
[System.IO.File]::WriteAllText($p, ($good -join "`r`n") + "`r`n", $enc)
Write-Output ("restored from HEAD, lines = " + @($good).Count)

# Line-based rewrite using ASCII-ONLY prefixes, because a Chinese needle inside THIS script would be mangled
# exactly the way it was in the target - which is how the first attempt failed to match anything.
$lines = [System.IO.File]::ReadAllLines($p, [System.Text.Encoding]::UTF8)
$out = New-Object System.Collections.Generic.List[string]
$replaced = 0
foreach ($ln in $lines) {
    if ($ln -like '$outside = Join-Path ([IO.Path]::GetTempPath())*') {
        $out.Add('$outside = Join-Path ([IO.Path]::GetTempPath()) ("PixelArmor " + $pkgNames.temp_dir_suffix + " " + $stamp)')
        $replaced++
    }
    elseif ($ln -like "*docs/DATA_RECOVERY_029.md*") {
        $out.Add("Copy-Item -LiteralPath (Join-Path `$source 'docs/DATA_RECOVERY_029.md') -Destination (Join-Path `$package `$pkgNames.doc_data_recovery)")
        $replaced++
    }
    elseif ($ln -like "*docs/RELEASE_README_031.txt*") {
        $out.Add("Copy-Item -LiteralPath (Join-Path `$source 'docs/RELEASE_README_031.txt') -Destination (Join-Path `$package `$pkgNames.doc_start_here)")
        $replaced++
    }
    elseif ($ln -like "*docs/RELEASE_LICENSES_031.md*") {
        $out.Add("Copy-Item -LiteralPath (Join-Path `$source 'docs/RELEASE_LICENSES_031.md') -Destination (Join-Path `$package `$pkgNames.doc_licenses)")
        $replaced++
    }
    else {
        $out.Add($ln)
    }
}
Write-Output ("  line rewrites applied = " + $replaced)
$t = ($out -join "`r`n") + "`r`n"

# Circled digits in comments -> ASCII, with a STRING argument (a char argument cannot take a multi-char value)
$circles = 0
foreach ($code in 0x2460..0x2463) {
    $ch = [string][char]$code
    if ($t.Contains($ch)) { $t = $t.Replace($ch, '[' + ($code - 0x245F) + ']'); $circles++ }
}
Write-Output ("  circled-digit kinds replaced = " + $circles)

# The UTF-8 names loader, inserted once
$anchor = '$projectRoot = Split-Path -Parent $PSScriptRoot'
$loader = @'
# WT-040-R1: the package's Chinese names are read from a UTF-8 data file. A Chinese literal inside this .ps1 is
# read as ANSI by Windows PowerShell and mangled, which already broke packaging once with "Illegal characters
# in path". This keeps the script itself pure ASCII while the shipped document names stay Chinese.
$pkgNames = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'package_doc_names.json') -Raw -Encoding UTF8 | ConvertFrom-Json
'@
$loader = $loader.TrimEnd("`r","`n").Replace("`n", "`r`n") + "`r`n"
$n = ([regex]::Matches($t, [regex]::Escape($anchor))).Count
Write-Output ("  loader anchor x" + $n)
if ($n -eq 1) { $t = $t.Replace($anchor, $loader + $anchor) }

[System.IO.File]::WriteAllText($p, $t, $enc)

# Verify: zero non-ASCII, clean parse, and both a loader and the names in use
$after = [System.IO.File]::ReadAllLines($p, [System.Text.Encoding]::UTF8)
$bad = @(); $i = 0
foreach ($ln in $after) { $i++; if ($ln -match '[^\x00-\x7F]') { $bad += ($i.ToString() + ': ' + $ln.Trim()) } }
Write-Output ("  non-ASCII lines remaining = " + $bad.Count)
$bad | ForEach-Object { Write-Output ("      " + $_) }
$err = $null
[System.Management.Automation.Language.Parser]::ParseFile($p, [ref]$null, [ref]$err) | Out-Null
Write-Output ("  parse errors = " + $(if ($err) { $err.Count } else { 0 }))
if ($err) { $err | Select-Object -First 4 | ForEach-Object { Write-Output ("      " + $_.Message) } }
Write-Output ("  pkgNames uses = " + ([regex]::Matches($t, 'pkgNames\.').Count))
Write-Output '=== patch8 done ==='
