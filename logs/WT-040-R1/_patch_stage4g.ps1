$c = 'E:\AIprogram\mcthunder-cont'
$enc = New-Object System.Text.UTF8Encoding($false)
$p = Join-Path $c 'tests\build_release.ps1'
$t = [System.IO.File]::ReadAllText($p, [System.Text.Encoding]::UTF8)
$nl = if ($t.Contains("`r`n")) { "`r`n" } else { "`n" }
Write-Output ("=== build_release.ps1 (" + $(if ($nl -eq "`r`n") { 'CRLF' } else { 'LF' }) + ")")

# 1) load the UTF-8 names file once, near the other constants
$anchor = '$projectRoot = Split-Path -Parent $PSScriptRoot'
$ins = @'
# WT-040-R1: the package's Chinese names are read from a UTF-8 data file. A Chinese literal in this .ps1 is
# read as ANSI by Windows PowerShell and mangled, which already broke packaging once with "Illegal characters
# in path"; this keeps the script itself pure ASCII while the shipped document names stay Chinese.
$pkgNames = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'package_doc_names.json') -Raw -Encoding UTF8 | ConvertFrom-Json
"# TEMPLATE="
'@
$ins = $ins.TrimEnd("`r","`n").Replace("`n", $nl)
$ins = $ins.Replace('"# TEMPLATE="' + $nl, '')
$n1 = ([regex]::Matches($t, [regex]::Escape($anchor))).Count
Write-Output ("  names-file load  x" + $n1)
if ($n1 -eq 1) { $t = $t.Replace($anchor, $ins + $anchor) }

# 2) the temp directory suffix
$pair2 = @('"PixelArmor 独立测试 $stamp"', '("PixelArmor " + $pkgNames.temp_dir_suffix + " " + $stamp)')
$n2 = ([regex]::Matches($t, [regex]::Escape($pair2[0]))).Count
Write-Output ("  temp suffix  x" + $n2)
if ($n2 -eq 1) { $t = $t.Replace($pair2[0], $pair2[1]) }

# 3) the three Chinese destination names
$pairs = @(
    @("'数据与恢复说明.md'", '$pkgNames.doc_data_recovery'),
    @("'开始游戏.txt'", '$pkgNames.doc_start_here'),
    @("'素材与许可.md'", '$pkgNames.doc_licenses')
)
foreach ($pair in $pairs) {
    $n = ([regex]::Matches($t, [regex]::Escape($pair[0]))).Count
    Write-Output ("  doc name  x" + $n + "  " + $pair[0])
    if ($n -ge 1) { $t = $t.Replace($pair[0], $pair[1]) }
}

# 4) the circled digits in comments, so the script carries NO non-ASCII at all
$n4 = 0
foreach ($ch in @([char]0x2463, [char]0x2460, [char]0x2461, [char]0x2462)) {
    if ($t.Contains($ch)) { $t = $t.Replace($ch, '[' + ([int]$ch - 0x245F) + ']'); $n4++ }
}
Write-Output ("  circled digits replaced in " + $n4 + " kinds")

[System.IO.File]::WriteAllText($p, $t, $enc)

# 5) prove there is no non-ASCII left in the script
$lines = [System.IO.File]::ReadAllLines($p, [System.Text.Encoding]::UTF8)
$bad = @()
$i = 0
foreach ($ln in $lines) { $i++; if ($ln -match '[^\x00-\x7F]') { $bad += ($i.ToString() + ': ' + $ln.Trim()) } }
Write-Output ("  non-ASCII lines remaining = " + $bad.Count)
$bad | ForEach-Object { Write-Output ("      " + $_) }

$err = $null
[System.Management.Automation.Language.Parser]::ParseFile($p, [ref]$null, [ref]$err) | Out-Null
Write-Output ("  parse errors = " + $(if ($err) { $err.Count } else { 0 }))
if ($err) { $err | Select-Object -First 4 | ForEach-Object { Write-Output ("      " + $_.Message) } }
Write-Output '=== patch7 done ==='
