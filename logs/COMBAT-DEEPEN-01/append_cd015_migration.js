// MCT-COMBAT-DEEPEN-01 / WT-CD-015 phase four: append the CD15 rule migration entries.
// The migration table is in PowerShell ConvertTo-Json style, so this helper reproduces that
// style and PROVES it by re-serialising an existing entry and demanding a byte-for-byte match
// before it writes anything. If the style check fails the script refuses to write.
const fs = require('fs');
const path = 'docs/wt/continuation/COMBAT_DEEPEN01_RULE_MIGRATION.json';
const raw = fs.readFileSync(path, 'utf8');

function js(v) {
  if (typeof v === 'string') return JSON.stringify(v);
  if (typeof v === 'boolean' || typeof v === 'number') return String(v);
  if (v === null) return 'null';
  if (Array.isArray(v)) throw new Error('array handled by caller');
  return ps(v, 0);
}
// PowerShell ConvertTo-Json style: "key":  value (two spaces); nested keys at +4; arrays align
// their items at the value column + 4 and close at the value column. `keyIndent` is the
// indentation of the KEYS, and the braces sit four columns to its left, which is what the
// byte-for-byte style check below enforces.
function ps(obj, keyIndent) {
  const pad = ' '.repeat(keyIndent);
  const brace = ' '.repeat(keyIndent - 4);
  const inner = [];
  for (const k of Object.keys(obj)) {
    const v = obj[k];
    const prefix = '"' + k + '":  ';
    if (Array.isArray(v)) {
      if (v.length === 0) { inner.push(pad + prefix + '[]'); continue; }
      const itemPad = ' '.repeat(keyIndent + prefix.length + 4);
      const closePad = ' '.repeat(keyIndent + prefix.length);
      const items = v.map((x) => itemPad + js(x)).join(',\r\n');
      inner.push(pad + prefix + '[\r\n' + items + '\r\n' + closePad + ']');
    } else {
      inner.push(pad + prefix + js(v));
    }
  }
  return brace + '{\r\n' + inner.join(',\r\n') + '\r\n' + brace + '}';
}

const doc = JSON.parse(raw);

// --- style self check: reproduce the LAST existing entry exactly ---
const last = doc.changes[doc.changes.length - 1];
const rendered = ps(last, 24);
if (!raw.includes(rendered)) {
  console.error('STYLE_CHECK_FAIL: the serialiser does not reproduce the existing entry byte for byte.');
  console.error('--- rendered ---');
  console.error(rendered);
  process.exit(2);
}
console.log('STYLE_CHECK_PASS: the serialiser reproduces migration entry ' + doc.changes.length + ' byte for byte.');

const entries = [
  {
    work_order_id: 'WT-CD-015',
    change_kind: 'existing_rule_confirmed_and_wired',
    old_rule_version: 'presentation_consumes_events_but_the_invariant_was_unmeasured',
    new_rule_version: 'cd15-presentation-consumer-v1',
    affected_vehicles: 'every_delivered_vehicle',
    affected_modes: 'live_match ; replay ; local_two_client',
    fields: ['effect_policy', 'committed_event', 'stop_all', 'presentation_stopped'],
    reason: 'The order requires sound, particles, explosions and hit prompts to CONSUME committed events only and never to decide settlement, and it rejects by name any case where turning the effects off changes a hit. So the existing presentation layer had to be measured as a pure consumer rather than assumed to be one.',
    reference_sources: ['R10', 'R11'],
    old_reference_unchanged: true,
    legacy_behavior_retained: true,
    legacy_entry: 'scripts/feedback/combat_feedback.gd is untouched: on_combat_event, on_shot, on_contact, on_finished and stop_all keep their signatures, and the layer still draws only from committed events.',
    legacy_tests: 'run_feedback_checks.gd 40/0, run_hud_checks.gd 56/0, run_vehicle_damage_hud_checks.gd 109/0 and run_network_authority_checks.gd 62/0, all unchanged',
    new_expected_declared_before_run: 'With the separation declared, stopping the presentation layer must leave the committed event count, the ammunition, the damage and the tickets of the same match unchanged, and no presentation value may be read back into a rule.',
    independent_oracle: 'Two real begun matches compared by their OWN committed event count and ticket ledger, with the presentation layer stopped between them.',
    measured_before: 'Measured: the feedback layer already existed and consumed committed events, but nothing had measured the invariant this case names. The first pass looked for a projectile manager as a CHILD of the match scene, found none, and recorded that wiring gap as an admitted weak pass instead of claiming the case.',
    measured_after: 'Measured on the production objects: the manager is reached through the range OWN projectiles member and that member does own the feedback layer; stopping it leaves the same match with nine committed events and identical tickets 300/300 on both sides. The dedicated probe prints P1 feedback present=true with 9 -> 9 events, and the acceptance scene prints REACHED AND STOPPED=true, so the presentation half is exercised and is no longer inferred from a file name.',
    migration: 'The presentation layer is confirmed and wired rather than replaced; the behaviour probe and the acceptance scene drive the production member, and nothing on the rule side was moved into presentation or back out of it.',
    rollback: 'No rule value changed, so there is nothing to roll back in the rules; removing the probe and the scene restores the previous verification level and changes no game behaviour.',
    divergences: 'The event kinds, points and priorities the layer consumes remain declared project design initial values with comparison NOT_COMPARED; no audio or particle asset is claimed and the headless runs carry no screenshot.'
  },
  {
    work_order_id: 'WT-CD-015',
    change_kind: 'field_extension',
    old_rule_version: 'effect_policy_gate_declared_but_never_driven',
    new_rule_version: 'cd15-shell-family-effects-v1',
    affected_vehicles: 'every_delivered_vehicle',
    affected_modes: 'live_fire',
    fields: ['effect_policy', 'impact_profile', 'burst', 'fragment_candidates', 'termination_reason'],
    reason: 'The order requires each shell family to produce its OWN effect from a real event and rejects by name giving an unexploded round a lethal burst, so the declared families had to be driven through the real spawn gate instead of being inferred from the presence of a shell family file.',
    reference_sources: ['R10', 'R11'],
    old_reference_unchanged: true,
    legacy_behavior_retained: true,
    legacy_entry: 'The five admitted effect policies and the manager dedup of a relaunch (duplicate_launch) are unchanged, and no armour, fragment or ammunition rule was rewritten for this order.',
    legacy_tests: 'run_damage_checks.gd 57/0, run_material_replay_checks.gd 43/0 and run_network_event_journal_checks.gd 64/0, all unchanged',
    new_expected_declared_before_run: 'Every declared family must be admitted by the real gate carrying its own complete effect profile, an undeclared effect must be refused by name rather than treated as kinetic, and a round that reaches nothing must produce no lethal burst at all.',
    independent_oracle: 'ProjectileManager.try_spawn driven with each declared family and with an undeclared one, reading the admission result and the recorded burst rather than a file.',
    measured_before: 'Measured: the spawn gate admitted only the effect policies the manager declares, and no probe had driven them. The first pass rested on the presence of a shell family file and of the replay codec, which is presence rather than behaviour, and it is recorded as an admitted weak pass.',
    measured_after: 'Measured through the real spawn gate: all FOUR declared families - kinetic, he_blast, internal_burst and long_rod - are ACCEPTED with zero refusals, each carrying its OWN complete impact profile. The long-rod family is validated by its own rule set, which FORBIDS the full-caliber normalization and overmatch fields outright and instead demands a bounded angle-resistance curve from zero to ninety degrees, so the profiles are genuinely different per family rather than one shape reused. An undeclared effect is REFUSED BY NAME as invalid_effect_policy, and a round that reaches nothing produces NO burst at all, with the accepted and refused lists printed by both the probe and the scene.',
    migration: 'The gate and the per family profiles are extended rather than replaced; a stored record keeps the effect policy it was written with, and the undeclared case has an explicit refusal instead of a silent default.',
    rollback: 'Remove the driven probes; the gate then admits exactly what it admitted before and no production path changes.',
    divergences: 'No shell family, penetration or fragment value is a real ammunition figure; they remain declared project design initial values with comparison NOT_COMPARED.'
  },
  {
    work_order_id: 'WT-CD-015',
    change_kind: 'existing_rule_confirmed_and_wired',
    old_rule_version: 'stored_record_read_under_current_rules_only',
    new_rule_version: 'cd15-record-interpretation-v1',
    affected_vehicles: 'every_stored_result',
    affected_modes: 'replay',
    fields: ['rule_version', 'known_versions', 'action', 'shot_record', 'seed'],
    reason: 'The order requires an old and a new rule record to be EXPLAINED or explicitly unsupported and never re-settled, so a stored record must be read by the version it carries rather than recomputed under the rules of today.',
    reference_sources: ['R10', 'R11'],
    old_reference_unchanged: true,
    legacy_behavior_retained: true,
    legacy_entry: 'The record builder, the codec, the store, the controller, the view and the three record validators are untouched: shot_record_builder.gd, shot_record_codec.gd, shot_record_store.gd, replay_controller.gd, replay_view.gd, chemical_record_validator.gd, reactive_armor_record_validator.gd and spall_record_validator.gd.',
    legacy_tests: 'run_replay_checks.gd 73/0, run_material_replay_checks.gd 43/0 and run_era_network_checks.gd 22/0, all unchanged',
    new_expected_declared_before_run: 'A stored record must be explained by the version that produced it, and an unknown version must be refused by name with an action, so that reading a replay never re-randomises damage or re-settles an outcome.',
    independent_oracle: 'The RuleVersionInterpreter driven with a known and an unknown version, plus the codec and the builder read on the production path.',
    measured_before: 'Measured: the builder, the codec, the store, the controller, the view and the three validators all existed and the record carried its own rule version, but nothing had been measured at READ time, and the first pass rested on the codec being present, which is presence rather than behaviour.',
    measured_after: 'Measured by driving the interpreter and reading the codec: version one is explained as team_standard_300 with nothing reinterpreted, version 999 is refused with reason unknown_rule_version:999 and action refuse_or_migrate, and both the codec and the builder are present on the production path, so a stored record is explained by its own version and is never re-randomised or re-settled.',
    migration: 'The existing record chain is confirmed and used as it is; the interpretation layer only explains or refuses and rewrites no history, and the tag keeps the version it was written with.',
    rollback: 'Remove the interpreter call; stored records keep their versions and nothing else changes.',
    divergences: 'The known version table is a declared project fact with comparison NOT_COMPARED.'
  },
  {
    work_order_id: 'WT-CD-015',
    change_kind: 'existing_rule_confirmed_and_wired',
    old_rule_version: 'local_authority_read_by_source_name_rather_than_driven',
    new_rule_version: 'cd15-local-authority-v1',
    affected_vehicles: 'every_delivered_vehicle',
    affected_modes: 'local_two_client ; reconnect',
    fields: ['reject', 'not_owner', 'stale_sequence', 'unsupported_message', 'unsupported_version', 'baseline', 'event_journal', 'final_snapshot'],
    reason: 'The order requires one server and two clients to agree on the authority result and identity, forbids a client from submitting a kill or a reward as an authority fact, and requires out-of-order, duplicated, expired and old-life input to have a named policy, so the authority surface had to be DRIVEN rather than read by source string.',
    reference_sources: ['R10', 'R11'],
    old_reference_unchanged: true,
    legacy_behavior_retained: true,
    legacy_entry: 'scripts/network/network_battle_server.gd is untouched: reject, _freeze_finish, _queue_baseline, _awaiting_baseline and _send_baseline keep their names and their behaviour, and no client-authoritative damage or reward path was added. The stale sequence refusal stays in network_identity_policy.gd.',
    legacy_tests: 'run_network_event_recovery_checks.gd 58/0, run_network_authority_checks.gd 62/0, run_network_fault_checks.gd 42/0, run_network_identity_checks.gd 60/0 and run_network_event_journal_checks.gd 64/0, all unchanged',
    new_expected_declared_before_run: 'A client that spoofs another vehicle identity, replays a stale sequence, sends an unknown message or claims a hit must be refused by name, and the authority digest must be identical across the server and both clients, with no client adding its own kill or reward.',
    independent_oracle: 'tests/run_network_slice.ps1 launching THREE real processes - one authority and two production clients - and comparing the final payload digest of all three.',
    measured_before: 'Measured: the server with its version constant, packet cap, per-client send and reject, checkpoint, baseline queueing and replay after a sequence already existed, but the first CD15 scene read them by SOURCE STRING presence, which is presence rather than behaviour, recorded as an admitted weak pass.',
    measured_after: 'Measured by driving three real processes: the authority and BOTH production clients finished with the SAME final digest b7a1c492eae3dcb76994b6ea13bd6e6dd6b1d73a65dd6a9868c6ec5d244feebf, the server accepted 311 commands and refused by name not_owner:2 for a spoofed entity identity, stale_sequence:2 for a replayed sequence, unsupported_message:2 for a client CLAIMING A HIT through claim_hit, and unsupported_version:4 for a bad protocol version, with 4 shots fired and 4 finished and 2 final acknowledgements. Both clients report passed=true with the snapshot and event order verified and their own cursor equal to the final event sequence, so neither client added a kill or a reward. In addition run_network_event_recovery_checks.gd drives the initial versioned baseline, a duplicate reliable batch that moves no cursor, a malformed suffix that rejects the whole batch, an event tick regression across batch boundaries, the retention window and an overlapping resync.',
    migration: 'The authority surface is confirmed and exercised rather than replaced; what changed is the LEVEL of the evidence, and the deepened rules ride the same chain instead of a single-machine test.',
    rollback: 'No authority or transport code changed, so there is nothing to roll back; removing the harness and the probes restores the previous verification level.',
    divergences: 'The harness own aggregate flag reads false because it reads a NULL process exit code from its started processes, while each process printed its PASS line and returned through the passing branch and the three digests are identical; that instrument fault is stated rather than smoothed over. Losing and delaying the transport is a fixture and the order permits it; no packet loss, capacity or p95 measurement is claimed and performance stays HOLD_BY_USER.'
  },
  {
    work_order_id: 'WT-CD-015',
    change_kind: 'existing_rule_confirmed_and_wired',
    old_rule_version: 'information_permission_declared_but_projection_unmeasured',
    new_rule_version: 'cd15-information-permission-v1',
    affected_vehicles: 'every_observer_and_every_replay_view',
    affected_modes: 'live_observation ; replay',
    fields: ['INFO_CLASSES', 'is_internal_field', 'project', 'precision_m', 'expires_at'],
    reason: 'The order requires the enemy live internals to be used for the battle HUD only and refuses to let the new data fields leak real-time internals, so the permission trimming had to be measured on a real spectator projection.',
    reference_sources: ['R10', 'R11'],
    old_reference_unchanged: true,
    legacy_behavior_retained: true,
    legacy_entry: 'scripts/battle/observation_policy.gd is untouched: the four information classes, the precision and expiry tables, the media rules and the internal field guard keep their values, and no field was added to the wire format.',
    legacy_tests: 'run_observation_policy_checks.gd, run_optics_checks.gd, run_sight_ballistics_checks.gd and run_support_actions_checks.gd as confirmed under WT-CD-012, unchanged',
    new_expected_declared_before_run: 'An observer or a replay must receive only permitted information, a spectator projection must come from an observer class rather than from world truth, and an internal field must be refused rather than trimmed silently.',
    independent_oracle: 'ObservationPolicy driven directly: the four classes, the internal field guard and a real spectator projection.',
    measured_before: 'Measured: the four information classes with their per source precision and expiry, the media rules and the internal field guard already existed from CD12, but no spectator projection and no observer against world truth comparison had been measured, so the trimming claim rested on the policy being present.',
    measured_after: 'Measured by driving the policy: the four classes read world_truth, observer_visible, shared_intel and last_seen_memory; the internal field guard refuses an internal field; and a real spectator projection is produced from observer_visible rather than from world truth, so the enemy live internals are not carried by the extended fields into the observer or the replay.',
    migration: 'The permission rules are confirmed in place and exercised rather than replaced, so a record written earlier keeps exactly the information it was allowed to carry.',
    rollback: 'No policy value changed and nothing was removed, so there is nothing to roll back; removing the scene leaves the machinery as it was found.',
    divergences: 'Precision, expiry and attenuation values remain declared project design initial values with comparison NOT_COMPARED, and thermal and radar remain explicitly unsupported states rather than a filter standing in for a sensor.'
  }
];

// --- 1. append the entries to the changes array ---
const anchorA = '"divergences":  "The known version table is a declared project fact with comparison NOT_COMPARED."\r\n                    }\r\n                ],';
if (!raw.includes(anchorA)) { console.error('ANCHOR_A_MISSING'); process.exit(3); }
const replacementA = '"divergences":  "The known version table is a declared project fact with comparison NOT_COMPARED."\r\n                    },\r\n'
  + entries.map((e) => ps(e, 24)).join(',\r\n')
  + '\r\n                ],';
let out = raw.replace(anchorA, replacementA);

// --- 2. extend the migration index ---
const anchorB = '"WT-CD-014: a realistic rule preset beside the old one, a personal sortie book, a four step sortie transaction, and a rule version interpreter"\r\n                        ],';
if (!out.includes(anchorB)) { console.error('ANCHOR_B_MISSING'); process.exit(4); }
const indexLine = 'WT-CD-015: the presentation layer, the shell family gate, the replay record interpretation, the local authority across three processes and the information permission are CONFIRMED and DRIVEN on the same chain rather than replaced';
out = out.replace(anchorB, '"WT-CD-014: a realistic rule preset beside the old one, a personal sortie book, a four step sortie transaction, and a rule version interpreter",\r\n                            ' + JSON.stringify(indexLine) + '\r\n                        ],');

// --- 3. replace the full run evidence ---
const swaps = [
  ['CD14 start: run_garage_checks 151/0, run_save_lock_checks 8/0, run_match_rules_checks 43/0, run_match_event_checks 11/0, run_damage_checks 57/0, run_recovery_checks 64/0.',
   'CD15 start: run_feedback_checks 40/0, run_hud_checks 56/0, run_replay_checks 73/0, run_network_authority_checks 62/0, run_network_event_recovery_checks 58/0, run_network_fault_checks 42/0 and run_shell_checks 193/0 = 524 checks with no failures, the same seven suites and the same seven totals the CD15 first pass measured.'],
  ['CD14 close: the same six suites at their exact baselines with 334 passes and no failures, and all six acceptance scenes reading met.',
   'CD15 close: the same seven suites again at 524/0, plus six more chain suites driven green this round - run_vehicle_damage_hud_checks 109/0, run_network_event_journal_checks 64/0, run_network_identity_checks 60/0, run_damage_checks 57/0, run_material_replay_checks 43/0 and run_era_network_checks 22/0 - for 13 headless suites at 879 checks with no failures, and the three-process authority harness produced three identical final digests. run_ammo_compartment_checks is NOT counted green: it prints 62/0 but carries a pre-existing test-suite script error at its own line 104, recorded since the CD07 and CD10 rounds and outside this change set.'],
  ['team_standard_300, the ticket ledger and the runtime death gate were NOT replaced, and no delivered expectation was changed at any point.',
   'The feedback layer, the replay chain, the authority server and the information policy were NOT replaced, no delivered expectation was edited at any point, and no production code was changed for this phase.']
];
for (const [from, to] of swaps) {
  if (!out.includes(from)) { console.error('SWAP_MISSING: ' + from.slice(0, 60)); process.exit(5); }
  out = out.replace(from, to);
}

// --- 4. write and verify ---
if (out.includes('\u0027')) { console.error('unexpected escaped apostrophe'); process.exit(6); }
fs.writeFileSync(path, out, 'utf8');

const check = JSON.parse(fs.readFileSync(path, 'utf8'));
console.log('changes=' + check.changes.length);
const keys = Object.keys(check.changes[0]);
console.log('entry_keys=' + keys.length + ' : ' + keys.join(','));
const bad = check.changes.filter((c) => Object.keys(c).length !== 20);
console.log('entries_with_wrong_key_count=' + bad.length);
const cd15 = check.changes.filter((c) => c.work_order_id === 'WT-CD-015');
console.log('cd15_entries=' + cd15.length + ' kinds=' + cd15.map((c) => c.change_kind).join('|'));
console.log('migration_index_lines=' + check.migration_index.length);
console.log('full_run_before_starts=' + check.full_run_evidence.before.slice(0, 12));
console.log('full_run_after_starts=' + check.full_run_evidence.after.slice(0, 12));
const bytes = fs.readFileSync(path);
console.log('non_ascii_bytes=' + bytes.filter((x) => x > 127).length);
console.log('BOM=' + (bytes[0] === 0xEF && bytes[1] === 0xBB && bytes[2] === 0xBF));
console.log('trailing_newline=' + out.endsWith('\n'));
