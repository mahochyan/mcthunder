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
        $ResultRow = $null,
        [string] $SuiteLogPath = ''
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
            # The real field is an ARRAY of diagnostic lines, not a number. My first version cast it to int,
            # which passed a negative test that used numbers and would have thrown on real evidence - the
            # test and the data had different shapes, which is the lesson, not a detail.
            # Split by TYPE: the runner writes an ARRAY of diagnostic lines, while an empty result may
            # serialise as the number 0. Treating every non-null value as one diagnostic rejected healthy
            # runs, which the negative test caught - and the test now covers both shapes for that reason.
            $raw = $ResultRow.unexpected_errors
            $unexpected = 0
            if ($null -ne $raw) {
                if ($raw -is [string]) { if ($raw -ne '') { $unexpected = 1 } }
                elseif ($raw -is [System.Collections.IEnumerable]) { $unexpected = @($raw | Where-Object { $null -ne $_ -and "$_" -ne '' }).Count }
                else { $unexpected = [int]$raw }
            }
            if ($unexpected -ne 0) { return @{ ok = $false; reason = "is a registered failure but its run also reported $unexpected unexpected script error(s)" } }
        }
        if ($names -contains 'timed_out' -and [bool]$ResultRow.timed_out) {
            return @{ ok = $false; reason = 'is a registered failure but its run timed out' }
        }
        if ($names -contains 'exit_known' -and -not [bool]$ResultRow.exit_known) {
            return @{ ok = $false; reason = 'is a registered failure but its exit code was never observed' }
        }
    }

    # 5) the suite's OWN log must be healthy. The regression summary does not carry the diagnostic list in
    #    every shape - the field is simply absent in the file this build writes - so the health of a run is
    #    read from the suite's stdout log, which is the same evidence the player-flow check uses and is
    #    always present. A registered failure may not travel with script errors.
    if (-not [string]::IsNullOrWhiteSpace($SuiteLogPath)) {
        if (-not (Test-Path -LiteralPath $SuiteLogPath)) {
            return @{ ok = $false; reason = "is a registered failure but its suite log is missing ($SuiteLogPath)" }
        }
        $bad = @(Select-String -LiteralPath $SuiteLogPath -Pattern 'SCRIPT ERROR|^ERROR:|Parse Error' -ErrorAction SilentlyContinue)
        if ($bad.Count -gt 0) {
            $sample = ($bad | Select-Object -First 1).Line.Trim()
            return @{ ok = $false; reason = "is a registered failure but its suite log carries $($bad.Count) script error line(s), e.g. $sample" }
        }
    }

    return @{ ok = $true; reason = 'the failure set matches the register exactly' }
}
