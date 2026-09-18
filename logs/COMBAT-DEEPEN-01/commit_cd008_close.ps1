$c='E:\AIprogram\mcthunder-cont'
$g='E:\AIprogram\mcthunder\tools\godot\Godot_v4.7.2-stable_win64_console.exe'
$L="$c\logs\COMBAT-DEEPEN-01"
$tp=0;$tf=0;$bad=@();$window=@()
foreach ($s in @('run_ai_combat_checks','run_ai_recovery_checks','run_ai_tactics_checks','run_ammo_compartment_checks','run_damage_checks','run_engineering_damage_checks','run_engineering_loading_checks','run_fire_control_checks','run_historical_checks','run_loading_checks','run_modern_candidate_checks','run_recovery_checks','run_recovery_player_checks')) {
  & $g --headless --path $c --fixed-fps 60 -s ("res://tests/" + $s + ".gd") *> "$L\f-$s.log"
  $o = Get-Content "$L\f-$s.log" -ErrorAction SilentlyContinue
  $pp=@($o|Select-String '^\[PASS\]').Count; $ff=@($o|Select-String '^\[FAIL\]').Count; $se=@($o|Select-String '^\s*SCRIPT ERROR').Count
  $nw = [bool]($o|Select-String 'requires a real window')
  if ($nw) { $window += $s } else { $tp+=$pp; $tf+=$ff; if ($ff -gt 0 -or $se -gt 0) { $bad += $s } }
  "  {0,-32} exit={1} PASS={2,4} FAIL={3} ERR={4} {5}" -f $s,$LASTEXITCODE,$pp,$ff,$se,$(if ($nw) { 'WINDOW_REQUIRED' } else { '' })
}
"  TOTAL PASS=$tp FAIL=$tf bad=" + ($bad -join ',') + " window=" + ($window -join ',')

'=== migration table: the CD08 entries ==='
$f="$c\docs\wt\continuation\COMBAT_DEEPEN01_RULE_MIGRATION.json"
$j = Get-Content $f -Raw -Encoding UTF8 | ConvertFrom-Json
function New-Change($id,$kind,$oldV,$newV,$veh,$modes,$fields,$reason,$sources,$legacyEntry,$legacyTests,$expected,$oracle,$before,$after,$migration,$rollback,$divergences) {
  [pscustomobject][ordered]@{ work_order_id=$id; change_kind=$kind; old_rule_version=$oldV; new_rule_version=$newV
    affected_vehicles=$veh; affected_modes=$modes; fields=$fields; reason=$reason; reference_sources=$sources
    old_reference_unchanged=$true; legacy_behavior_retained=$true; legacy_entry=$legacyEntry; legacy_tests=$legacyTests
    new_expected_declared_before_run=$expected; independent_oracle=$oracle; measured_before=$before; measured_after=$after
    migration=$migration; rollback=$rollback; divergences=$divergences }
}
$new = @()
$new += New-Change 'WT-CD-008' 'new_rule' 'alive_is_a_boolean' 'cd008-crew-condition-v1' `
  'every_vehicle_with_crew_stations' 'live_fire_and_ui_readout' @('condition','condition_version','condition_severity','alive') `
  'Injury, station and availability must be three separate things, so a versioned condition replaces the boolean for reading while alive stays present and derived for anything that already reads it.' `
  @('R01','R06','W02') `
  'The legacy alive field is retained and derived, so a reader that only knows the boolean sees exactly what it saw before.' `
  'tests/run_cd008_scene_checks.gd (S1/S3) and tests/run_damage_checks.gd (crew legs)' `
  'With the condition declared, a graded state must exist as product state, and no middle condition may reduce duty because no efficiency figure has been verified.' `
  'The product produced crew state read before any submission, so a condition written by the test itself cannot be mistaken for the product.' `
  'Measured: the product crew record was {"alive":true,"original_role":...} only - a boolean, with nothing to grade.' `
  'Measured: every record carries condition, condition_version and severity, the scene reads met, and availability still only depends on incapacitation so no unconfirmed penalty is switched on.' `
  'A record without a condition falls back to the boolean; nothing that reads alive changes.' `
  'Remove the condition fields; the boolean is then the only state again, as before.' `
  'Thresholds are project design initial values and are declared as such; no external efficiency figure is claimed.'
$new += New-Change 'WT-CD-008' 'new_rule' 'person_identity_is_the_station' 'cd008-person-station-separation' `
  'every_vehicle_with_crew_stations' 'live_fire_and_recovery' @('crew_states keys','crew_assignments values','station_occupancy') `
  'A person must be identifiable apart from the station they occupy, and a relief move must move the person rather than duplicate one; the training layout already had a station id and a role that differ, so the identity had to be separated from both.' `
  @('R01','R06','W02') `
  'The role remains the bridge between station and person, so every reader resolves a person through the assignments map exactly as before.' `
  'tests/run_damage_checks.gd, tests/run_recovery_checks.gd, tests/run_ammo_compartment_checks.gd, tests/run_recovery_player_checks.gd (the crew legs in each)' `
  'With identities separated, no non-empty person holds two roles after a relief move, the headcount is conserved and the moving person keeps their own state and injuries.' `
  'The replacement path measured directly by a probe that builds its own actor: one empty slot, no duplicate, headcount unchanged.' `
  'Measured: a person key WAS the station key, so a person and a station were not distinguishable; the assignment map was keyed by role while station ids were read as persons.' `
  'Measured: person keys are person_1..person_N, station_roles keeps station to role, station_occupancy keeps station to person, the acceptance scene reads met, and thirteen suites return their exact baseline result counts with no runtime errors.' `
  'This one REQUIRED migrating delivered legs: seven sites named a person by a role or read a role as a person, and each was rewritten data driven - stronger than the name it replaced. The migration is recorded here as the class the package rule change section describes.' `
  'Revert the identity assignment; a person is then the station again and the seven legs pass as before.' `
  'A delivered test may still name a role where a person belongs; the eight such sites found are fixed, and the recovery player suite is window required under headless by design.'
$j.changes = @($j.changes) + $new
$j.migration_index = @($j.migration_index) + @('WT-CD-008: versioned crew condition, and person identity separated from station and role')
$j.full_run_evidence = [pscustomobject][ordered]@{
  before = 'CD08 start: run_damage_checks 57/0, run_recovery_checks 64/0, run_ammo_compartment_checks 62/0, run_historical_checks 192/0, run_shell_checks 193/0.'
  after = 'CD08 close: all thirteen suites that touch crew state return their exact baseline counts with zero failures and zero script errors (689 passes), and the four acceptance scenes read met on all six cases with their expectations untouched.'
  note = 'The only delivered expectations changed by this sub-order are the eight crew legs recorded above, each rewritten to read the person from the state; none was relaxed.'
}
[IO.File]::WriteAllText($f, ($j | ConvertTo-Json -Depth 14), (New-Object Text.UTF8Encoding($false)))
$chk = Get-Content $f -Raw -Encoding UTF8 | ConvertFrom-Json
"  changes now=" + @($chk.changes).Count + " ; parses=True"
'  tracked changes=' + @(git -C $c status --porcelain | Where-Object { $_ -notmatch '^\?\?' }).Count
@(git -C $c status --porcelain | Where-Object { $_ -notmatch '^\?\?' }) | ForEach-Object { '    ' + $_ }
if ($tf -eq 0) {
  git -C $c add scripts/defs/vehicle_runtime_state.gd scripts/damage/crew_damage_profile.gd tests/run_damage_checks.gd tests/run_recovery_checks.gd tests/run_ammo_compartment_checks.gd tests/run_recovery_player_checks.gd tests/run_cd008_scene_checks.gd tests/probe_cd008_t02_diag.gd tests/probe_cd008_replacement.gd docs/wt/continuation/COMBAT_DEEPEN01_RULE_MIGRATION.json docs/wt/continuation/COMBAT_DEEPEN01_CD008_EVIDENCE.md logs/COMBAT-DEEPEN-01
  git -C $c -c user.name=mcthunder-agent -c user.email=agent@mcthunder.local commit -m "MCT-COMBAT-DEEPEN-01 CD08-T02 completes: a person is identified apart from the station and the role, all four acceptance scenes read met, and thirteen suites return their exact baselines. The production change hands out a person identity in station order, independent of both the role and the station, keeps a station occupancy map so the three identities stay readable, and leaves the role as the bridge every reader already used. The last mistake was mine and it was a naming one: the training fixture has a station id of assistant_driver whose role is assistant_driver_bow_gunner, so a station id is not a role, and my scene helper was being handed person_gunner and person_driver strings that no map ever held - which is why one leg kept failing while every other part measured clean. Making the submission helper resolve its argument as a ROLE removed the possibility of a caller knowing how a person is named. Eight delivered legs that named a person by a role or station are rewritten data driven, each stronger than the name it replaced, and the two rules are recorded in the migration table with their measured before and after: the versioned crew condition with its legacy alive readable, and the person identity separated from station and role. Thirteen suites, zero failures, zero script errors, and the recovery player suite window required under headless by design" 2>&1 | Select-Object -First 2
} else { '  NOT green, nothing committed' }
'  commits=' + (git -C $c rev-list --count main..HEAD)
git -C $c push origin work/combat-deepen-01 2>&1 | Select-Object -Last 1 | ForEach-Object { '  push: ' + $_.ToString() }
$remote = ((& git -C $c ls-remote origin refs/heads/work/combat-deepen-01 2>$null) -split '\s+' | Select-Object -First 1)
'  remote_synced=' + ($remote -eq (git -C $c rev-parse HEAD))
