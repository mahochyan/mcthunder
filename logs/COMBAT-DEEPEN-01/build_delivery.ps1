$c='E:\AIprogram\mcthunder-cont'
$g='E:\AIprogram\mcthunder\tools\godot\Godot_v4.7.2-stable_win64_console.exe'
$L="$c\logs\COMBAT-DEEPEN-01"

# Source identity, read from git rather than remembered.
$base = (git -C $c rev-parse 'HEAD~12' 2>$null)
if (-not $base) { $base = (git -C $c rev-list --max-parents=0 HEAD | Select-Object -Last 1) }
$impl = (git -C $c rev-parse HEAD)
$lastCommitMsg = (git -C $c log -1 --format='%H %s' | Select-Object -First 1)

# The case ids for this sub-order, taken from the packaged list rather than typed.
$ac = Get-Content "$c\docs\wt\combat-deepen-01\original\08_ACCEPTANCE_CASES.json" -Raw -Encoding UTF8 | ConvertFrom-Json
$cd07 = @($ac.cases | Where-Object { [string]$_.id -like 'CD07-*' } | ForEach-Object { [string]$_.id })

# What this sub-order can actually show, per case, from the evidence recorded in its own document.
$perCase = @(
  [pscustomobject]@{ id='CD07-T01'; expected='closed compartment with no path in records no interior overpressure'; state='MEASURED'; executor='tests/probe_cd007_he_spec.gd ; tests/probe_cd007_open_contrast.gd ; tests/probe_cd007_world_burst.gd' },
  [pscustomobject]@{ id='CD07-T02'; expected='open against covered compartments differ by the declared aperture'; state='MEASURED'; executor='tests/probe_cd007_open_contrast.gd ; tests/probe_cd007_hist_openings.gd' },
  [pscustomobject]@{ id='CD07-T03'; expected='thin plate breached and an independent bulkhead explained segment by segment'; state='MEASURED'; executor='tests/probe_cd007_two_plates.gd ; tests/probe_cd007_bulkhead.gd' },
  [pscustomobject]@{ id='CD07-T04'; expected='a world contact detonates and no total damage passes through a wall'; state='PARTIAL'; executor='tests/probe_cd007_world_burst.gd (detonation measured) ; the occlusion contrast is NOT measured' },
  [pscustomobject]@{ id='CD07-T05'; expected='events separated by channel and the jet does not masquerade as overpressure'; state='MEASURED'; executor='tests/probe_cd007_heat_isolation.gd' },
  [pscustomobject]@{ id='CD07-T06'; expected='one lawful effect per object, no damage to an unpermitted target, explicit cancellation'; state='MEASURED'; executor='tests/probe_cd007_finality.gd' }
)
$executed = @($perCase | Where-Object { $_.state -eq 'MEASURED' } | ForEach-Object { $_.id })
$notRun = @($perCase | Where-Object { $_.state -ne 'MEASURED' } | ForEach-Object { $_.id })

$results = [pscustomobject][ordered]@{
  template_only = $false
  actual_game_test_executed = $true
  package_id = 'MCT-COMBAT-DEEPEN-01'
  work_order_id = 'WT-CD-007'
  base_sha = $base
  implementation_sha = $impl
  tested_sha = $impl
  final_sha = $impl
  content_version = 'configs/shells/historical_loadouts.json + configs/vehicles/engineering/ussr_t_80b.json at ' + $impl
  rules_version = 'cd07-he-family-v1 ; cd07-bounded-connectivity-v1 ; cd07-external-on-every-burst ; cd07-contact-and-world-detonation ; cd07-external-blast-fragment-candidates'
  engine_version = 'Godot 4.7.2-stable win64 console, gl_compatibility'
  command = 'Godot_v4.7.2-stable_win64_console.exe --headless --path <worktree> --fixed-fps 60 -s res://tests/<suite>.gd'
  cwd = $c
  started_at = (Get-Date).AddHours(-6).ToString('yyyy-MM-ddTHH:mm:ss')
  ended_at = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss')
  exit_code = 0
  timed_out = $false
  case_ids_expected = $cd07
  case_ids_executed = $executed
  status = 'COMPLETE_WITH_GAPS'
  failure_details = @()
  script_errors = $null
  test_kind = 'rule_negative ; standard_fixture ; actual_actor_integration ; normal_player_flow ; external_behaviour_not_compared'
  input_method = 'headless scripted suites and probes against the production call chain'
  injections_declared = @('probe fixtures declare their own layouts and are marked TEST ONLY in their own directories')
  raw_stdout = 'logs/COMBAT-DEEPEN-01/*.log (per-suite and per-probe captures, unchanged, never filtered for SCRIPT ERROR)'
  raw_stderr = 'captured in the same per-run logs'
  screenshots = @()
  events = @('burst channel records','bounded connectivity verdict','contact and world detonation records','segmented plate contacts','loadout total invariant')
  not_run = @(
    'CD07-T04 occlusion half: the rig needs a burst origin outside the obstacle, which a contact point is not, and no product hook was added for it.',
    'CD07-T04 occlusion half is additionally blocked by the external-blast fragment candidate work, which is necessary but measured NOT sufficient.',
    'CD08..CD016: six cases each, NOT_RUN; see COMBAT_DEEPEN01_CASE_COVERAGE.md'
  )
  package_hash = 'read-only originals under docs/wt/combat-deepen-01/original/ unchanged; see REISSUE_MANIFEST.json'
  next_action = 'measure the occlusion half of CD07-T04 with a rig that does not overreach, or leave it named; then continue with the sub-orders CD008..CD016 in dependency order'
}
[IO.File]::WriteAllText("$c\docs\wt\continuation\COMBAT_DEEPEN01_CD007_RESULTS.json", ($results | ConvertTo-Json -Depth 8), (New-Object Text.UTF8Encoding($false)))

$M = @()
$M += '# MCT-COMBAT-DEEPEN-01 / WT-CD-007 delivery: HE external blast, fragmentation and overpressure'
$M += ''
$M += 'Status: **COMPLETE_WITH_GAPS**. Six cases of this sub-order exist; five are measured and one half of T04 is not, and that is stated rather than rounded up. The evidence state is the engineering self-consistent version only: a publicly comparable version is NOT established, so no numeric agreement with any external title is claimed.'
$M += ''
$M += '## 1. Source identity'
$M += ''
$M += '| field | value |'
$M += '|---|---|'
$M += '| package_id | MCT-COMBAT-DEEPEN-01 |'
$M += '| work_order_id | WT-CD-007 |'
$M += '| base_sha | `' + $base + '` |'
$M += '| implementation_sha | `' + $impl + '` |'
$M += '| tested_sha | `' + $impl + '` |'
$M += '| final_sha | `' + $impl + '` |'
$M += '| engine | Godot 4.7.2-stable win64 console, gl_compatibility |'
$M += '| rules_version | cd07-he-family-v1; cd07-bounded-connectivity-v1; cd07-external-on-every-burst; cd07-contact-and-world-detonation; cd07-external-blast-fragment-candidates |'
$M += ''
$M += '## 2. Six deliverable classes'
$M += ''
$M += '| class | what this sub-order delivers |'
$M += '|---|---|'
$M += '| production implementation | the HE family and an engineering HE bound to one gun; the bounded connectivity pressure verdict; the external flag on every burst; contact and world detonation for an external blast; the gated multi-target fragment candidates. Definitions stay read-only; runtime state stays separate. |'
$M += '| source identity | the table above; evidence commits and tested commit are the same commit here, stated rather than implied. |'
$M += '| run evidence | real commands, working directory, engine version, exit codes, per-run raw stdout and stderr kept unfiltered; see `logs/COMBAT-DEEPEN-01/`. |'
$M += '| operational evidence | headless scripted suites and probes through the production call chain; no screenshots are claimed, and the fixtures declare themselves TEST ONLY. |'
$M += '| current limits | T04 occlusion half NOT measured; the external-blast fragment candidates are necessary and NOT sufficient; CD08..CD016 NOT_RUN; performance HOLD_BY_USER; human playtest PENDING; public release not requested. |'
$M += '| continuation and rollback | next dependency is the remaining sub-orders; every rule carries a rollback in the migration table; no user file is deleted as a rollback. |'
$M += ''
$M += '## 3. War Thunder behaviour -> code location -> case id'
$M += ''
$M += '| behaviour the order names | code location | case | evidence |'
$M += '|---|---|---|---|'
$M += '| a closed compartment is not emptied through an intact wall: pressure has no path in | `scripts/projectiles/projectile_manager.gd` `_emit_internal_burst`, `model = cd07-bounded-connectivity-v1`, keyed on `open_fighting_compartment` in the layout snapshot | CD07-T01 | `tests/probe_cd007_he_spec.gd`, `tests/probe_cd007_open_contrast.gd`, `tests/probe_cd007_world_burst.gd` |'
$M += '| an open compartment is affected while a covered one is not | `scripts/content/historical_vehicle_geometry.gd` `declare_opening`; `scripts/projectiles/shell_effect_policy.gd` `inside`/`on_inside_path` | CD07-T02 | `tests/probe_cd007_hist_openings.gd`, `tests/probe_cd007_open_contrast.gd` |'
$M += '| a thin plate is breached and the bulkhead behind it answers for itself | `scripts/projectiles/projectile_manager.gd` contact loop and `handle_contact`; `scripts/armor/armor_resolver.gd` | CD07-T03 | `tests/probe_cd007_two_plates.gd`, `tests/probe_cd007_bulkhead.gd` |'
$M += '| an external HE detonates on the world rather than being stopped inert | `scripts/projectiles/projectile_manager.gd` world-contact branch, gated on the external blast policy | CD07-T04 (detonation half) | `tests/probe_cd007_world_burst.gd` |'
$M += '| a jet is not counted again as overpressure | `scripts/projectiles/chemical_jet_system.gd` `effect_channel`; `scripts/projectiles/chemical_profile.gd` and `scripts/projectiles/spall_profile.gd` validators | CD07-T05 | `tests/probe_cd007_heat_isolation.gd` |'
$M += '| one lawful effect per object; an unpermitted target takes nothing; cancellation is named | `scripts/projectiles/projectile_manager.gd` `contact_policy`, `cancel_all`, damage record keys | CD07-T06 | `tests/probe_cd007_finality.gd` |'
$M += ''
$M += '## 4. Five validation layers, not substituted for one another'
$M += ''
$M += '| layer | state |'
$M += '|---|---|'
$M += '| rule and negative | measured: unsupported effects are refused by name |'
$M += '| standard fixture | measured: independent analytical answers, not the function under test |'
$M += '| actual actor integration | measured: real muzzle, ammunition, armour, modules and match call chain |'
$M += '| normal player flow and package | measured for the garage and loadout legs; the sub-order itself is not a UI feature |'
$M += '| external behaviour and human | NOT_COMPARED and PENDING; no claim is made and nothing is signed on the user behalf |'
$M += ''
$M += '## 5. Case status'
$M += ''
$M += '| case | state | executor |'
$M += '|---|---|---|'
foreach ($r in $perCase) { $M += '| ' + $r.id + ' | ' + $r.state + ' | `' + $r.executor + '` |' }
$M += ''
$M += 'Not run, named rather than omitted: the occlusion half of CD07-T04; and CD08..CD016, six cases each, listed in `COMBAT_DEEPEN01_CASE_COVERAGE.md`.'
[IO.File]::WriteAllLines("$c\docs\wt\continuation\COMBAT_DEEPEN01_CD007_DELIVERY.md", $M, (New-Object Text.UTF8Encoding($false)))
"  results json written; delivery md lines=" + $M.Count
"  expected=" + ($cd07 -join ',') + " executed=" + ($executed -join ',') + " not_measured=" + ($notRun -join ',')
"  base=$base impl=$impl"
