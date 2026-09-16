# WT-040-R1 (user ruling): the ONE implementation of the candidate failure-set match, shared by the build
# and by its own test, so the thing that is tested is the thing that runs. A copy would prove nothing.
#
# The rule the ruling asked for: the actual failure set must EQUAL the registered set, item by item. The
# previous rule accepted the set when the COUNT matched and ONE line matched, which let a new failure replace
# an old one without changing the total.
#
# Returns @{ ok = <bool>; reason = <string> }.

function Test-CandidateFailureSet {
    param(
        [Parameter(Mandatory=$true)] $Entry,
        [Parameter(Mandatory=$true)] [AllowEmptyCollection()] [string[]] $FailLines,
        $ResultRow = $null
    )

    if ($null -eq $Entry) { return @{ ok = $false; reason = 'no register entry was supplied' } }
    $sigs = @($Entry.signatures)
    if ($sigs.Count -eq 0) { return @{ ok = $false; reason = 'the register entry carries no signatures' } }

    $expected = 0
    foreach ($sig in $sigs) { $expected += [int]$sig.count }

    # 1) the total must be exactly what the register accounts for
    if ($FailLines.Count -ne $expected) {
        return @{ ok = $false; reason = "failed $($FailLines.Count) check(s) but its registered signatures account for exactly $expected" }
    }

    # 2) each signature must match exactly its own expected count - no substituting one failure for another
    foreach ($sig in $sigs) {
        $hits = @($FailLines | Where-Object { $_ -match $sig.match })
        if ($hits.Count -ne [int]$sig.count) {
            return @{ ok = $false; reason = "signature '$($sig.match)' matched $($hits.Count) failure(s); the register expects exactly $($sig.count)" }
        }
    }

    # 3) EVERY failing line must be claimed by some signature. This is the guard that refuses the first
    #    counter-example: one old failure plus one new failure, with the total unchanged.
    $unclaimed = @($FailLines | Where-Object {
        $line = $_
        @($sigs | Where-Object { $line -match $_.match }).Count -eq 0
    })
    if ($unclaimed.Count -gt 0) {
        return @{ ok = $false; reason = "carries UNREGISTERED failure(s) no signature claims: $($unclaimed -join ' | ')" }
    }

    # 4) a registered failure may not travel with an unhealthy run. This refuses the second counter-example:
    #    a registered failure accompanied by script errors, a timeout or an incomplete result.
    if ($null -ne $ResultRow) {
        $names = @($ResultRow.PSObject.Properties.Name)
        if ($names -contains 'unexpected_errors') {
            $unexpected = [int]$ResultRow.unexpected_errors
            if ($unexpected -ne 0) { return @{ ok = $false; reason = "is a registered failure but its run also reported $unexpected unexpected script error(s)" } }
        }
        if ($names -contains 'timed_out' -and [bool]$ResultRow.timed_out) {
            return @{ ok = $false; reason = 'is a registered failure but its run timed out' }
        }
        if ($names -contains 'exit_known' -and -not [bool]$ResultRow.exit_known) {
            return @{ ok = $false; reason = 'is a registered failure but its exit code was never observed' }
        }
    }

    return @{ ok = $true; reason = 'the failure set matches the register exactly' }
}
