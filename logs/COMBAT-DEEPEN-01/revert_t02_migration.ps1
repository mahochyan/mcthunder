$c='E:\AIprogram\mcthunder-cont'
$g='E:\AIprogram\mcthunder\tools\godot\Godot_v4.7.2-stable_win64_console.exe'
$L="$c\logs\COMBAT-DEEPEN-01"
'=== revert the whole T02 migration to the committed green state ==='
git -C $c checkout -- scripts/defs/vehicle_runtime_state.gd tests/run_damage_checks.gd tests/run_recovery_checks.gd tests/run_ammo_compartment_checks.gd tests/run_recovery_player_checks.gd tests/run_cd008_scene_checks.gd
Remove-Item "$c\tests\probe_cd008_dup.gd" -Force -ErrorAction SilentlyContinue
'  tracked changes=' + @(git -C $c status --porcelain | Where-Object { $_ -notmatch '^\?\?' }).Count
@(git -C $c status --porcelain | Where-Object { $_ -notmatch '^\?\?' }) | ForEach-Object { '    ' + $_ }
'=== verify the revert is green on the suites that were affected ==='
$tp=0;$tf=0;$bad=@()
foreach ($s in @('run_damage_checks','run_recovery_checks','run_ammo_compartment_checks','run_historical_checks','run_shell_checks')) {
  & $g --headless --path $c --fixed-fps 60 -s ("res://tests/" + $s + ".gd") *> "$L\rv3-$s.log"
  $o = Get-Content "$L\rv3-$s.log" -ErrorAction SilentlyContinue
  $pp=@($o|Select-String '^\[PASS\]').Count; $ff=@($o|Select-String '^\[FAIL\]').Count
  $tp+=$pp;$tf+=$ff; if ($ff -gt 0) { $bad+=$s }
  "  {0,-30} exit={1} PASS={2,4} FAIL={3}" -f $s,$LASTEXITCODE,$pp,$ff
}
"  TOTAL PASS=$tp FAIL=$tf bad=" + ($bad -join ',')
$md = @()
$md += ''
$md += '## 7. The T02 migration carried out, measured correct, and reverted for ONE unreconciled leg'
$md += ''
$md += '### 7.1 What was done'
$md += '```'
$md += 'production: every person gets an identity handed out in station order (person_1..person_N), depending on neither the'
$md += '            role nor the station, with a station occupancy map so both identities stay readable.'
$md += 'delivered legs: SEVEN sites that named a person by a role or station were rewritten to read the person from the state'
$md += '            (run_damage_checks L156/157/185, run_ammo_compartment_checks L104, run_recovery_checks L109/150/151/167,'
$md += '            run_recovery_player_checks L73/74), each one STRONGER than the name it replaced.'
$md += '```'
$md += '### 7.2 Measured result: eleven of thirteen suites exactly at baseline, two strictly better'
$md += '```'
$md += 'run_ai_combat_checks         34 / was 34      run_ai_recovery_checks        16 / was 16'
$md += 'run_ai_tactics_checks        39 / was 39      run_ammo_compartment_checks   62 / was 62'
$md += 'run_damage_checks            59 / was 57  (+2, the two strengthened legs, nothing lost)'
$md += 'run_engineering_damage       25 / was 25      run_engineering_loading       23 / was 23'
$md += 'run_fire_control_checks      59 / was 59      run_historical_checks        192 / was 192'
$md += 'run_loading_checks           62 / was 62      run_modern_candidate_checks   56 / was 56'
$md += 'run_recovery_checks          60 / was 53  (+7, the whole block resumed once the runtime error was removed)'
$md += 'run_recovery_player_checks    0 / was 0   WINDOW_REQUIRED by design: the suite quits headless on purpose'
$md += '```'
$md += '### 7.3 The one leg that is not reconciled'
$md += '```'
$md += 'run_recovery_checks: "[FAIL] one person cannot occupy two roles after replacement"'
$md += '   The leg used to read `crew_assignments.gunner == "commander"`, i.e. it watched a particular NAME. It was rewritten as'
$md += '   the invariant it was always about - no non-empty person may hold two roles - and that invariant reports holders == 1.'
$md += '   So either the replacement path really leaves one person in two roles, or my reading of that leg is wrong.'
$md += '   It is NOT guessed at: the probe written to measure it used a suite member that is a local of the suite, so it aborted'
$md += '   before printing, which is the same mistake recorded earlier and must not be repeated a third time.'
$md += '```'
$md += '### 7.4 Why it is reverted rather than kept'
$md += '```'
$md += 'The rule is that a failing state is rolled back to the last runnable state. The change is measured correct on eleven'
$md += 'suites and strictly stronger on two, but one delivered leg fails and its cause is not yet measured, so the tree returns to'
$md += 'the green commit and the work is re-applied next round together with the measurement of that last leg.'
$md += '```'
$md += '### 7.5 Next step, precisely'
$md += '```'
$md += '1. measure the replacement path directly (a probe that builds its OWN actor, not one borrowed from a suite member): print'
$md += '   the assignments before and after the replace command and say whether any non-empty person holds two roles;'
$md += '2. re-apply the migration (production + the seven legs) as one change;'
$md += '3. run all thirteen suites and compare counts as well as failures;'
$md += '4. record it in the migration table with the before and after, and keep the rollback.'
$md += '```'
[IO.File]::AppendAllText("$c\docs\wt\continuation\COMBAT_DEEPEN01_CD008_EVIDENCE.md", (($md -join "`r`n") + "`r`n"), (New-Object Text.UTF8Encoding($false)))
'  evidence appended'
if ($tf -eq 0) {
  git -C $c add docs/wt/continuation/COMBAT_DEEPEN01_CD008_EVIDENCE.md logs/COMBAT-DEEPEN-01
  git -C $c -c user.name=mcthunder-agent -c user.email=agent@mcthunder.local commit -m "MCT-COMBAT-DEEPEN-01 CD08-T02: the migration was carried out, measured correct on eleven suites and strictly stronger on two, and is reverted because one delivered leg is not yet reconciled. The production change gives every person an identity handed out in station order, independent of role and station, with a station occupancy map keeping both readable. Seven delivered sites that named a person by a role were rewritten to read the person from the state, each stronger than the name it replaced. Measured against the baselines: eleven suites return exactly their previous counts, the damage suite goes from fifty seven to fifty nine because the two rewritten legs are stricter, and the recovery suite goes from fifty three to sixty because a runtime error had been cutting its whole block short - the error was Invalid access to key 'gunner', the same class as the other sites. The recovery player suite reports nothing headless because it quits on purpose demanding a real window, which is by design and now recorded. One leg remains: the replacement invariant reports that a non-empty person holds two roles, where the old leg watched one particular name instead. Whether the replacement path really duplicates a person is not guessed at, because the probe written to measure it borrowed a suite member that is a local and aborted before printing, which is the mistake already recorded once. Under the rule that a failing state returns to the last runnable state, everything is reverted and the work is re-applied next round together with that measurement" 2>&1 | Select-Object -First 2
} else { '  NOT green after revert - investigate' }
'  commits=' + (git -C $c rev-list --count main..HEAD)
git -C $c push origin work/combat-deepen-01 2>&1 | Select-Object -Last 1 | ForEach-Object { '  push: ' + $_.ToString() }
$remote = ((& git -C $c ls-remote origin refs/heads/work/combat-deepen-01 2>$null) -split '\s+' | Select-Object -First 1)
'  remote_synced=' + ($remote -eq (git -C $c rev-parse HEAD))
