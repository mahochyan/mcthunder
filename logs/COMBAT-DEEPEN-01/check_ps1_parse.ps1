# Assert a PowerShell script PARSES before any run is believed. This exists because a parse error in a bisect test
# is indistinguishable from a verdict: the interpreter exits non-zero, and `git bisect` reads a non-zero exit as
# "this commit is bad", which is exactly how a DOCUMENTATION-ONLY commit was named the first bad one.
param([Parameter(Mandatory = $true)][string]$Path)
$errors = $null
$tokens = $null
[void][System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$errors)
if ($errors.Count -gt 0) {
    $errors | ForEach-Object { Write-Output ('PARSE_ERROR ' + $_.Message) }
    exit 1
}
Write-Output ('PARSE_OK ' + $Path)
exit 0
