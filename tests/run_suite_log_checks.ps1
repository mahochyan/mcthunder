$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'read_suite_log.ps1')
$fixture = Join-Path ([IO.Path]::GetTempPath()) ('mcthunder-suite-log-'+[guid]::NewGuid()+'.log')
$writer = $null
try {
    $writer = [IO.File]::Open($fixture,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::Read)
    $bytes = [Text.Encoding]::UTF8.GetBytes("partial test output`n")
    $writer.Write($bytes,0,$bytes.Length); $writer.Flush()
    $read = Read-SuiteLog -Path $fixture
    if ($read.Error -or $read.Text -ne "partial test output`n") { throw 'Active writer log was not readable' }
    Write-Output '[PASS] partial log readable while redirect writer remains open'
    $writer.Dispose(); $writer=$null
    $missing = Read-SuiteLog -Path ($fixture+'.missing')
    if (-not $missing.Error -or $missing.Text -ne '') { throw 'Missing evidence must be an explicit failure' }
    Write-Output '[PASS] unreadable evidence returns explicit error instead of aborting result recording'
} finally {
    if ($null -ne $writer) { $writer.Dispose() }
    if (Test-Path -LiteralPath $fixture) { Remove-Item -LiteralPath $fixture }
}
