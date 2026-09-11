function Read-SuiteLog {
    param([Parameter(Mandatory)][string]$Path)
    $stream = $null
    $reader = $null
    try {
        # Redirected output can still have a writer handle after process exit.
        $stream = [IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, ([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))
        $reader = [IO.StreamReader]::new($stream)
        return @{Text=$reader.ReadToEnd(); Error=$null}
    } catch {
        # Preserve a failing result row even if the partial log cannot be read.
        return @{Text=''; Error=$_.Exception.Message}
    } finally {
        if ($null -ne $reader) { $reader.Dispose() }
        elseif ($null -ne $stream) { $stream.Dispose() }
    }
}
