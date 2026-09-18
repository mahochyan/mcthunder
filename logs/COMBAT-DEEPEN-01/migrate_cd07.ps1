$c='E:\AIprogram\mcthunder-cont'
$f="$c\docs\wt\continuation\COMBAT_DEEPEN01_RULE_MIGRATION.json"
$j = Get-Content $f -Raw -Encoding UTF8 | ConvertFrom-Json

function New-Change($id,$kind,$oldV,$newV,$veh,$modes,$fields,$reason,$sources,$legacyEntry,$legacyTests,$expected,$oracle,$before,$after,$migration,$rollback,$divergences) {
  return [pscustomobject][ordered]@{
    work_order_id=$id; change_kind=$kind; old_rule_version=$oldV; new_rule_version=$newV
    affected_vehicles=$veh; affected_modes=$modes; fields=$fields; reason=$reason
    reference_sources=$sources; old_reference_unchanged=$true; legacy_behavior_retained=$true
    legacy_entry=$legacyEntry; legacy_tests=$legacyTests; new_expected_declared_before_run=$expected
    independent_oracle=$oracle; measured_before=$before; measured_after=$after
    migration=$migration; rollback=$rollback; divergences=$divergences
  }
}

$new = @()
$new += New-Change 'WT-CD-007' 'new_rule' 'no_family_for_an_external_blast' 'cd07-he-family-v1' `
  'engineering_vehicles_whose_gun_matches_the_round' 'live_fire' @('family','source_bullet_type','effect_policy') `
  'The content gate requires a family whose declared source type and effect agree with each other, and there was no family for an external blast, so one is added beside the existing four instead of relabelling an existing family.' `
  @('R07','W07') `
  'The four existing families and every round admitted under them are untouched; a round that declares no family is still refused exactly as before.' `
  'tests/run_shell_checks.gd (family agreement legs)' `
  'The engineering HE is admitted by the shell catalogue and offered at runtime by the vehicle carrying its gun and by no other.' `
  'The shell catalogue build result and the runtime option list per engineering vehicle, read from the production install path.' `
  'Measured: the shell catalogue REFUSED the round with "shell.<id>: effect_policy: unsupported", and the content pipeline likewise.' `
  'Measured: VehicleShellCatalog.build ok=true, and the runtime option list is three rounds on the vehicle carrying the 125 mm gun and two on the other, so the weapon limit holds at the configuration, admission and runtime layers.' `
  'A round without the declaration keeps the previous refusal word for word; records made before the family existed are not rewritten.' `
  'Remove the family entry; the round is then refused by name exactly as it was before.' `
  'The engineering round carries project design initial values only; no historical round or figure is claimed.'
$new += New-Change 'WT-CD-007' 'new_rule' 'legacy_fragment_template_only' 'cd07-bounded-connectivity-v1' `
  'all_vehicles_for_the_external_blast_effect' 'live_fire' @('overpressure','blast','fragmentation','declared_openings') `
  'An external blast needs its own pressure verdict rather than a legacy fragment template, and that verdict must follow from bounded connectivity: pressure reaches the interior only through a breach or a declared opening, and never through a wall.' `
  @('R07','W07') `
  'The internal burst and long rod profiles keep their own recorded versions and are not touched by this rule.' `
  'tests/probe_cd007_he_spec.gd (root event shape) and tests/probe_cd007_open_contrast.gd (open against closed)' `
  'With the rule declared, a closed compartment with no breach and no declared opening must record the pressure as NOT applied, and an open one must record it as applied.' `
  'The declared layout openings carried in the query snapshot: the pressure verdict is decided by whether the burst is outside, whether the plate was breached, and how many declared open-fighting-compartment apertures the target has.' `
  'Measured: the burst carried only the legacy fragment template, with the blast channel marked applied=false and pending "cd07-blast-channel", so there was no pressure verdict at all.' `
  'Measured: the burst records three separate channels and the overpressure channel carries a computed verdict with the reason "closed compartment with no breach and no declared opening: the pressure has no path in, so there is no invented interior overpressure", while the open case records it as applied.' `
  'A burst that declares no external blast keeps the legacy template exactly; existing records keep the version they were made under.' `
  'Remove the overpressure channel; the burst then carries the legacy template only, as before.' `
  'The rule keys only on the open-fighting-compartment aperture because structural caps are the limit of inside travel rather than armour, so counting every aperture would make every vehicle look open.'
$new += New-Change 'WT-CD-007' 'field_extension' 'external_written_only_for_a_fuzed_burst' 'cd07-external-on-every-burst' `
  'all_vehicles_for_the_external_blast_effect' 'live_fire' @('external') `
  'Whether an explosion happened outside the hull is a property of every burst, not only of a fuzed one, and a contact HE carries no fuze at all.' `
  @('R07') `
  'Every fuzed burst keeps the same value it already recorded; nothing about the fuze path changes.' `
  'tests/probe_cd007_world_burst.gd' `
  'A fuzeless external blast must record whether its explosion was outside the hull, rather than leaving the field absent.' `
  'The recorded external flag is compared against the burst geometry and the hull interior test.' `
  'Measured: a contact HE burst recorded the field as ABSENT, so nothing said whether it went off outside.' `
  'Measured: the same burst now records external=true, and the fuzed bursts are unchanged.' `
  'Bursts recorded before this change keep whatever they recorded; the field is added for new records only.' `
  'Remove the unconditional write; fuzed bursts then record it as before and fuzeless ones record nothing.' `
  'None; the field is additive.'
$new += New-Change 'WT-CD-007' 'new_rule' 'external_he_stopped_inert' 'cd07-contact-and-world-detonation' `
  'all_vehicles_for_the_external_blast_effect' 'live_fire' @('burst_target','burst_entry_distance','burst_visited','contact_kind') `
  'The order requires contact HE and detonation after a world collision first, so an external blast bursts where it meets armour or the world instead of being stopped inert; proximity, timed and guided fuzes stay out of scope.' `
  @('R07','W07') `
  'Every other effect keeps its behaviour exactly: the change is gated on the external blast policy alone, so internal burst, kinetic, long rod and chemical are untouched.' `
  'tests/probe_cd007_he_runtime.gd (armour contact) and tests/probe_cd007_world_burst.gd (world contact)' `
  'With the rule declared, a round that meets armour and stops must still produce a root event, and a round that meets the world must produce one too.' `
  'The contact verdict the resolver returns, plus the recorded contact kind, so the two routes are distinguishable in the record.' `
  'Measured: the round met the armour with one contact and a stopped verdict and reported burst=none, so an external HE was inert on contact.' `
  'Measured: the same shot now reports burst=present with the three channels, the world route records contact_kind=world_contact, and the armour route is unchanged in every other respect.' `
  'A round that declares another effect is unaffected; the recording is additive and the terminal reason is still owned by the emitter.' `
  'Remove the two gated branches; an external blast is then stopped inert again.' `
  'The terminal reason for the world route is internal_burst because the emitter owns it; the contact kind therefore has to be recorded on the burst rather than inferred from the terminal name.'
$new += New-Change 'WT-CD-007' 'new_rule' 'fragment_loop_assumed_inside_target' 'cd07-external-blast-fragment-candidates' `
  'all_vehicles_for_the_external_blast_effect' 'live_fire' @('eligible','left_target','other_target','burst_target') `
  'Five places in the fragment loop assumed a non-delayed effect happened inside its target, which is false for an external blast: it is inside none, has no burst target, and must still be able to act on any object its fragments reach while world occlusion still decides what they strike.' `
  @('R07') `
  'Delayed and spall fragments keep exactly the eligibility, guard, travel and target rules they had; every change is gated on the external blast policy.' `
  'tests/run_spall_checks.gd (delayed and spall legs, unchanged)' `
  'With the rule declared, a fragment from an external blast must be able to reach a target in range rather than stopping on the first iteration.' `
  'The occlusion contrast: a target behind an obstacle against one beside it at a reachable distance.' `
  'Measured: the loop treated an external blast as inside its (absent) target, so fragments exited on the first iteration or rejected every other target as other_target.' `
  'NOT YET MEASURED. The gated changes are in place but the occlusion contrast still records no damage on either target, so no positive effect is claimed; the remaining link is to be located by instrumenting the loop, which the recorded lessons require before further edits.' `
  'A round without the declaration keeps every one of the five behaviours exactly; the declaration only lifts them for this policy.' `
  'Remove the five gates; the previous single-target assumption returns unchanged.' `
  'This entry is deliberately recorded as necessary and NOT sufficient: it is kept because it corrects a real assumption, and it is explicitly not claimed to make external-blast fragments strike anything.'
$new += New-Change 'WT-CD-007' 'expectation_migration' 'hard_coded_six_rounds' 'edited_loadout_total' `
  'engineering_vehicles_carrying_more_than_two_round_types' 'live_fire_and_garage' @('rounds_remaining') `
  'Adding a round type necessarily changes how a weapon distributes its rounds, because the install gives the default round seventy percent and splits the rest evenly; the shipping diagnostic asserted the old two-round total as a constant.' `
  @('R07') `
  'The historical two-round vehicles and their totals are unchanged; the assertion is satisfied by them as before.' `
  'scripts/diagnostics/modern_garage_verifier.gd (the same two legs)' `
  'The battle must receive exactly the total the player edited, whatever number of round types the vehicle has.' `
  'The loadout the player edited: the sum of its own per-round counts.' `
  'Measured: the garage suite failed 27 of 29 with the constant, because the third round changed the distribution.' `
  'Measured: with the assertion expressed as the edited total the suite is 29 of 29, and the ten-suite run is 893 passes with no failures.' `
  'This is a migration of an expectation, not a relaxation: the constant asserted a number, the replacement asserts the invariant the leg was always about.' `
  'Reinstate the constant; the two-round vehicles still satisfy it and a three-round one fails again.' `
  'This is the only delivered expectation this order changed, and it changed because the order instructed adding a round, not to make a failure disappear.'
$j.changes = @($j.changes) + $new
$j.migration_index = @($j.migration_index) + @('WT-CD-007: family, pressure verdict, external flag, contact and world detonation, fragment candidates, expectation migration')
$j.full_run_evidence = [pscustomobject][ordered]@{
  before='CD07 start, at the CD06 close: run_historical_checks 192/0, run_shell_checks 193/0, run_chemical_checks 92/0, run_fuze_checks 137/0, run_spall_checks 78/0, run_armor_checks 81/0, run_damage_checks 57/0 (7 suites, 773 passes, no failures).'
  after='CD07 close: the same seven suites plus run_modern_garage_checks 29/0 and the probe suites, run repeatedly through the order; the last full pass is run_shell 193/0, run_fuze 137/0, run_spall 78/0, run_chemical 92/0, run_armor 81/0, run_damage 57/0, run_historical 192/0, run_projectile 0/0 (8 suites, 830 passes, no failures).'
  note='The same suites give the same totals before and after, so the order is additive: the only migration is the expectation recorded above, and it was required by the order itself.'
}
$j | Add-Member -NotePropertyName cd07_evidence_state -NotePropertyValue 'engineering self-consistent version only; a publicly comparable version is NOT established, so no numeric agreement with any external title is claimed' -Force
[IO.File]::WriteAllText($f, ($j | ConvertTo-Json -Depth 14), (New-Object Text.UTF8Encoding($false)))
$chk = Get-Content $f -Raw -Encoding UTF8 | ConvertFrom-Json
"  changes=" + @($chk.changes).Count + " (was 6, added " + $new.Count + ")"
"  ids=" + ((@($chk.changes) | ForEach-Object { [string]$_.new_rule_version }) -join ' | ')
"  index_entries=" + @($chk.migration_index).Count + " ; keys_ok=" + ($chk.PSObject.Properties.Name -contains 'full_run_evidence') + " ; bytes=" + (Get-Item $f).Length
