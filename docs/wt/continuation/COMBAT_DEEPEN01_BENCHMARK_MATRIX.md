# MCT-COMBAT-DEEPEN-01 benchmark matrix: every row measured internally, every external comparison NOT_COMPARED

Filled from what the fifteen closed sub-orders measured, and bound to the War Thunder build on this machine. It contains **zero** `WT_BEHAVIOR_COMPARISON` rows and **zero** `HUMAN_PLAYTEST` rows and gives **no** similarity percentage. Two things are kept apart on purpose: every row cites game build **2.59.0.13** and its extraction provenance, while only the rows whose real counterpart was actually read carry an expected reference - those are source comparisons, labelled `COMPARED_TO_SOURCE_FILE`, and every other row stays `NOT_COMPARED`.

Evidence levels are the four the package declares: `SOURCE_RULE` · `PROJECT_FIXTURE` · `WT_BEHAVIOR_COMPARISON` · `HUMAN_PLAYTEST`.

## 1. Summary

| measure | value |
|---|---|
| rows | 35 |
| `WT_BEHAVIOR_COMPARISON` rows | **0** |
| `HUMAN_PLAYTEST` rows | **0** |
| similarity percentage | **none given** |

| evidence level | rows |
|---|---|
| `SOURCE_RULE` | 5 |
| `PROJECT_FIXTURE` | 30 |

| sub-order | rows in matrix | coverage state | cases |
|---|---|---|---|
| WT-CD-001 | 0 | EVIDENCE_RECORDED | evidence document |
| WT-CD-002 | 0 | EVIDENCE_RECORDED | evidence document |
| WT-CD-003 | 2 | EVIDENCE_RECORDED | evidence document |
| WT-CD-004 | 3 | EVIDENCE_RECORDED | evidence document |
| WT-CD-005 | 1 | EVIDENCE_RECORDED | evidence document |
| WT-CD-006 | 0 | EVIDENCE_RECORDED | evidence document |
| WT-CD-007 | 6 | COMPLETE | 6/6 |
| WT-CD-008 | 2 | COMPLETE | 6/6 |
| WT-CD-009 | 2 | COMPLETE | 6/6 |
| WT-CD-010 | 1 | COMPLETE | 6/6 |
| WT-CD-011 | 2 | COMPLETE | 6/6 |
| WT-CD-012 | 1 | COMPLETE | 6/6 |
| WT-CD-013 | 2 | COMPLETE | 6/6 |
| WT-CD-014 | 4 | COMPLETE | 6/6 |
| WT-CD-015 | 5 | COMPLETE | 6/6 |

## 2. Dependency graph of the last sub-order, read from disk

| dependency | state | cases | evidence commit | result commit | rules carried into the matrix |
|---|---|---|---|---|---|
| WT-CD-001 | EVIDENCE_RECORDED | evidence document form | `69149f36` | - | 0 |
| WT-CD-002 | EVIDENCE_RECORDED | evidence document form | `fad05f88` | - | 0 |
| WT-CD-003 | EVIDENCE_RECORDED | evidence document form | `8949b639` | - | 2 |
| WT-CD-004 | EVIDENCE_RECORDED | evidence document form | `29f4cd98` | - | 3 |
| WT-CD-005 | EVIDENCE_RECORDED | evidence document form | `45b88736` | - | 1 |
| WT-CD-006 | EVIDENCE_RECORDED | evidence document form | `e398bbbd` | - | 0 |
| WT-CD-007 | COMPLETE | 6/6 | `39762ec9` | `39762ec9` | 6 |
| WT-CD-008 | COMPLETE | 6/6 | `14c2463f` | `4c6f5a22` | 2 |
| WT-CD-009 | COMPLETE | 6/6 | `a6fe494a` | `1f8553a5` | 2 |
| WT-CD-010 | COMPLETE | 6/6 | `29056cb9` | `fa9d93b8` | 1 |
| WT-CD-011 | COMPLETE | 6/6 | `fdb7229b` | `9493e286` | 2 |
| WT-CD-012 | COMPLETE | 6/6 | `937fd033` | `6132bcfa` | 1 |
| WT-CD-013 | COMPLETE | 6/6 | `656f6ab5` | `399ae69c` | 2 |
| WT-CD-014 | COMPLETE | 6/6 | `f31fc14b` | `cc42d6d8` | 4 |
| WT-CD-015 | COMPLETE | 6/6 | `e8d7e9a4` | `e8d7e9a4` | 5 |

## 3. Rows: behaviour, project measurement, and the external half left empty

| id | order | level | mechanic | project measurement (measured, not intended) | external reference |
|---|---|---|---|---|---|
| `BM-01-cd003-shape-v1` | WT-CD-003 | `SOURCE_RULE` | cd003-shape-v1 :: shape_profile, shape_kind, section_radius_m, rays, error_bound_m | Declared section: 0 of 9 disagree. | `null` / NOT_COMPARED |
| `BM-02-cd003-rotation-step-0.02rad` | WT-CD-003 | `SOURCE_RULE` | cd003-rotation-step-0.02rad :: ROTATION_STEP_RAD, part_transform_basis | Subdivided: crossing 0.536451, a delta of 0.000973; the frozen control is unchanged at 0.500000. | `null` / NOT_COMPARED |
| `BM-03-cd004-ballistics-v1` | WT-CD-004 | `SOURCE_RULE` | cd004-ballistics-v1 :: ballistics_profile, drag_model, drag_k_per_m, provenance, retention_table | Declared retention 0.972 / 0.932 / 0.869 / 0.811 against the frozen 0.972 / 0.932 / 0.871 / 0.814, worst deviation 0.0034; the vacuum control is bit-identical. | **`COMPARED_TO_SOURCE_FILE`** - gun file 125mm_2a46_2_user_cannon.blk round 125mm_ussr_3BM42_APDS_FS speed 1700 m/s; 120mm_rheinmetall_l44_user_cannon.blk round 120mm_NATO_APDS_FS speed 1650 m/s -> EQUAL to our APFSDS muzzle velocity on both vehicles (docs/wt/wt-reference/WT_AMMO_COMPARISON.json) |
| `BM-04-cd004-residual-ratio-v1` | WT-CD-004 | `SOURCE_RULE` | cd004-residual-ratio-v1 :: residual_model, RESIDUAL_K, RESIDUAL_FLOOR | One hundred millimetres leaves 805.788 and three hundred leaves 617.363; bursts land 19.11575 and 15.34726 metres out, inside one step of residual times delay. | `null` / NOT_COMPARED |
| `BM-05-cd004-ballistics-v1_shared_solver` | WT-CD-004 | `PROJECT_FIXTURE` | cd004-ballistics-v1_shared_solver :: ballistic_intercept_verification, ai_lane_prediction, gunner_spec_drag_k_per_m | Vacuum miss 0.000305 m, unchanged; drag miss 0.001376 m, with the predicted time moved from 0.363637 s to 0.379341 s. | `null` / NOT_COMPARED |
| `BM-06-wt012-reactive-v1` | WT-CD-005 | `SOURCE_RULE` | wt012-reactive-v1 ::  | A qualifying hit spends the charge and adds its reduction; a hit below the trigger minimum does NOT spend it; through the resolver a live charge costs 220.0000 mm against a spent charge's 100.0000 mm. | `null` / NOT_COMPARED |
| `BM-07-cd07-he-family-v1` | WT-CD-007 | `PROJECT_FIXTURE` | cd07-he-family-v1 :: family, source_bullet_type, effect_policy | Measured: VehicleShellCatalog.build ok=true, and the runtime option list is three rounds on the vehicle carrying the 125 mm gun and two on the other, so the weapon limit holds at the configuration, admission and runtime layers. | **`COMPARED_TO_SOURCE_FILE`** - gun file 125mm_2a46_2_user_cannon.blk round 125mm_ussr_HE speed 850 m/s, explosive a_ix_2 3.402 kg -> ALIGNED: the declared 700 m/s was moved to the file value 850 m/s as declared behavior change cd16-he-velocity-850-v1 with its measured before and after, and the six affected suites are green (307 checks, no failures); the HE damage model, its 30 mm flat curve and its blast channels remain declared project policy and NOT_COMPARED |
| `BM-08-cd07-bounded-connectivity-v1` | WT-CD-007 | `PROJECT_FIXTURE` | cd07-bounded-connectivity-v1 :: overpressure, blast, fragmentation, declared_openings | Measured: the burst records three separate channels and the overpressure channel carries a computed verdict with the reason "closed compartment with no breach and no declared opening: the pressure has no path in, so there is no invented interior overpressure", … | `null` / NOT_COMPARED |
| `BM-09-cd07-external-on-every-burst` | WT-CD-007 | `PROJECT_FIXTURE` | cd07-external-on-every-burst :: external | Measured: the same burst now records external=true, and the fuzed bursts are unchanged. | `null` / NOT_COMPARED |
| `BM-10-cd07-contact-and-world-detonation` | WT-CD-007 | `PROJECT_FIXTURE` | cd07-contact-and-world-detonation :: burst_target, burst_entry_distance, burst_visited, contact_kind | Measured: the same shot now reports burst=present with the three channels, the world route records contact_kind=world_contact, and the armour route is unchanged in every other respect. | `null` / NOT_COMPARED |
| `BM-11-cd07-external-blast-fragment-candidates` | WT-CD-007 | `PROJECT_FIXTURE` | cd07-external-blast-fragment-candidates :: eligible, left_target, other_target, burst_target | NOT YET MEASURED. The gated changes are in place but the occlusion contrast still records no damage on either target, so no positive effect is claimed; the remaining link is to be located by instrumenting the loop, which the recorded lessons require before fur … | `null` / NOT_COMPARED |
| `BM-12-edited_loadout_total` | WT-CD-007 | `PROJECT_FIXTURE` | edited_loadout_total :: rounds_remaining | Measured: with the assertion expressed as the edited total the suite is 29 of 29, and the ten-suite run is 893 passes with no failures. | `null` / NOT_COMPARED |
| `BM-13-cd008-crew-condition-v1` | WT-CD-008 | `PROJECT_FIXTURE` | cd008-crew-condition-v1 :: condition, condition_version, condition_severity, alive | Measured: every record carries condition, condition_version and severity, the scene reads met, and availability still only depends on incapacitation so no unconfirmed penalty is switched on. | `null` / NOT_COMPARED |
| `BM-14-cd008-person-station-separation` | WT-CD-008 | `PROJECT_FIXTURE` | cd008-person-station-separation :: crew_states keys, crew_assignments values, station_occupancy | Measured: person keys are person_1..person_N, station_roles keeps station to role, station_occupancy keeps station to person, the acceptance scene reads met, and thirteen suites return their exact baseline result counts with no runtime errors. | `null` / NOT_COMPARED |
| `BM-15-cd009-module-response-v1` | WT-CD-009 | `PROJECT_FIXTURE` | cd009-module-response-v1 :: power_scale, yaw_scale, pitch_scale, reasons | Measured: an engine taken from full to half records power_scale 0.5 and the reason engine:linear:0.50, while a transmission loss, a track side loss and a driver loss record three different causes with different steering and pivot outcomes. | `null` / NOT_COMPARED |
| `BM-16-cd009-breech-jam-v1` | WT-CD-009 | `PROJECT_FIXTURE` | cd009-breech-jam-v1 :: breech_failure, breech_failures, blocked_reason | Measured on the production path: after nine real requests a jam occurred and recorded {shot_id 9, seed 2335249131, roll 0.131, chance 0.2, rule cd009-breech-jam-v1, round_consumed false}; the same request was refused the same way; a held trigger did not multip … | `null` / NOT_COMPARED |
| `BM-17-cd10-ammo-reaction-v1` | WT-CD-010 | `PROJECT_FIXTURE` | cd10-ammo-reaction-v1 :: ammo_reactions, ammo_reaction, ammo_loss_total, lost, store class, compartment state | Measured: the profile answers with one of four outcomes keyed on storage class, damage channel and compartment state; the fourth case reads isolated against vent_only once the real barrier module is the one damaged; and the conservation prints exactly - the T- … | `null` / NOT_COMPARED |
| `BM-18-cd11-drive-profiles-v1` | WT-CD-011 | `PROJECT_FIXTURE` | cd11-drive-profiles-v1 :: drive_profile, turn_speed_falloff, turn_drag_per_second, track_spacing_m, damaged_track_turn_scale, power_falloff | Measured: the Leopard reads power falloff 0.500, six gears, turn falloff 0.420, track spacing 2.880 and turn drag 0.400 while the T-80 reads 0.420, five gears, 0.300, 2.720 and 0.320, and their forward tops differ at 10.304 against 10.373. | **`COMPARED_TO_SOURCE_FILE`** - unit file gamedata/units/tankmodels/{ussr_t_80b,germ_leopard_2a4}.blk: mass 50000 / 47000 kg, maxFwdSpeed 75 km/h = 20.833 m/s, maxRevSpeed 10 km/h = 2.778 m/s, maxAccel 4, maxDecel 8, maxAngSpeed 30 -> EQUAL on every figure our packets declare (docs/wt/wt-reference/WT_REFERENCE_UNITS.json) |
| `BM-19-cd11-recoil-v1` | WT-CD-011 | `PROJECT_FIXTURE` | cd11-recoil-v1 :: recoil_speed_mps, recoil_max_mps, recoil_velocity | Measured: the Leopard moves 0.780 and the T-80 0.550 through the same entry, so the response differs by vehicle, and both are bounded by their own declared caps of 1.55 and 1.10. | `null` / NOT_COMPARED |
| `BM-20-cd12-observation-and-support-wired-v1` | WT-CD-012 | `PROJECT_FIXTURE` | cd12-observation-and-support-wired-v1 :: INFO_CLASSES, PRECISION_M, MEDIA_RULES, INTERNAL_FIELDS, recon_marks, smoke_clouds, stabilizer_available | Measured by the six acceptance scenes: an observation leaves the turret yaw at zero rather than commanding it; the stabiliser reads false when absent and true when present; a building blocks a projectile while smoke does not, and smoke occludes the optical cha … | `null` / NOT_COMPARED |
| `BM-21-cd13-contribution-v1` | WT-CD-013 | `PROJECT_FIXTURE` | cd13-contribution-v1 :: events, counters, contacts, effective_damages, shots_fired, firing_slots, kills | Measured by a dedicated probe: contacts 1, effective damages 3, shots fired 1, firing slots 1 and kills 1 from one firing and several module damages; the same dedup key twice is refused as already_counted with the counter unmoved; and a life is killed once. | `null` / NOT_COMPARED |
| `BM-22-cd13-attribution-v1` | WT-CD-013 | `PROJECT_FIXTURE` | cd13-attribution-v1 :: primary, assists, attribution_version, assist_window_s, no_credit_causes | Measured: two shooters on one target give primary shooter_C with shooter_A as an assist under cd13-attribution-v1; a hit older than the twelve second window is not an assist however large; friendly fire, abandonment, an environmental death and an orphaned fire … | `null` / NOT_COMPARED |
| `BM-23-cd14-ground-rb-preset-v1` | WT-CD-014 | `PROJECT_FIXTURE` | cd14-ground-rb-preset-v1 :: start_tickets, time_limit_s, books, initial_sp, vehicle_cost, repeat_sortie_limit, contribution_income, sortie_rules | Measured: the old preset still reports the same id, version, three hundred tickets and the SAME fingerprint, while the new preset reports id ground_rb_like_v1 with four books, initial SP 450, per class costs, a repeat limit of three, contribution income and th … | `null` / NOT_COMPARED |
| `BM-24-cd14-personal-sp-book-v1` | WT-CD-014 | `PROJECT_FIXTURE` | cd14-personal-sp-book-v1 :: initial_sp, balance, lifetime_earned, lifetime_spent, entries | Measured: earning from a committed event credited 120 to a 450 balance for 570, the same event key again was refused as already_earned, and the book own check reports that no balance in its entry history ever went negative. | `null` / NOT_COMPARED |
| `BM-25-cd14-sortie-transaction-v1` | WT-CD-014 | `PROJECT_FIXTURE` | cd14-sortie-transaction-v1 :: reservations, receipts, sortie_rules | Measured: a blocked spawn released with the balance still 300, a cancellation released as well, a confirmed and committed sortie charged once, the same token again returned idempotent with zero charged, and a request the balance could not cover was refused as  … | `null` / NOT_COMPARED |
| `BM-26-cd14-rule-version-interpreter-v1` | WT-CD-014 | `PROJECT_FIXTURE` | cd14-rule-version-interpreter-v1 :: rule_version, known_versions, migrated, action | Measured: version one is explained as team_standard_300 with nothing reinterpreted, and version 999 is refused with reason unknown_rule_version:999 and action refuse_or_migrate alongside the known version list. | `null` / NOT_COMPARED |
| `BM-27-cd15-presentation-consumer-v1` | WT-CD-015 | `PROJECT_FIXTURE` | cd15-presentation-consumer-v1 :: effect_policy, committed_event, stop_all, presentation_stopped | Measured on the production objects: the manager is reached through the range OWN projectiles member and that member does own the feedback layer; stopping it leaves the same match with nine committed events and identical tickets 300/300 on both sides. The dedic … | `null` / NOT_COMPARED |
| `BM-28-cd15-shell-family-effects-v1` | WT-CD-015 | `PROJECT_FIXTURE` | cd15-shell-family-effects-v1 :: effect_policy, impact_profile, burst, fragment_candidates, termination_reason | Measured through the real spawn gate: all FOUR declared families - kinetic, he_blast, internal_burst and long_rod - are ACCEPTED with zero refusals, each carrying its OWN complete impact profile. The long-rod family is validated by its own rule set, which FORB … | `null` / NOT_COMPARED |
| `BM-29-cd15-record-interpretation-v1` | WT-CD-015 | `PROJECT_FIXTURE` | cd15-record-interpretation-v1 :: rule_version, known_versions, action, shot_record, seed | Measured by driving the interpreter and reading the codec: version one is explained as team_standard_300 with nothing reinterpreted, version 999 is refused with reason unknown_rule_version:999 and action refuse_or_migrate, and both the codec and the builder ar … | `null` / NOT_COMPARED |
| `BM-30-cd15-local-authority-v1` | WT-CD-015 | `PROJECT_FIXTURE` | cd15-local-authority-v1 :: reject, not_owner, stale_sequence, unsupported_message, unsupported_version, baseline, event_journal, final_snapshot | Measured by driving three real processes: the authority and BOTH production clients finished with the SAME final digest b7a1c492eae3dcb76994b6ea13bd6e6dd6b1d73a65dd6a9868c6ec5d244feebf, the server accepted 311 commands and refused by name not_owner:2 for a spo … | `null` / NOT_COMPARED |
| `BM-31-cd15-information-permission-v1` | WT-CD-015 | `PROJECT_FIXTURE` | cd15-information-permission-v1 :: INFO_CLASSES, is_internal_field, project, precision_m, expires_at | Measured by driving the policy: the four classes read world_truth, observer_visible, shared_intel and last_seen_memory; the internal field guard refuses an internal field; and a real spectator projection is produced from observer_visible rather than from world … | `null` / NOT_COMPARED |
| `BM-32-cd16-declared-manifest-expectation-v1` | WT-CD-016 | `PROJECT_FIXTURE` | cd16-declared-manifest-expectation-v1 :: shell_catalog.shells, shell_catalog.default, shell_options, muzzle_velocity_mps, effect_policy | Measured after the migration: 54 checks, 0 failed. The T-80B declares three rounds and all three validate with their own policies; the Leopard declares two and both validate; the HEAT reload, both real launches and the reset restoration still pass for both veh … | `null` / NOT_COMPARED |
| `BM-33-cd16-he-velocity-850-v1` | WT-CD-016 | `PROJECT_FIXTURE` | cd16-he-velocity-850-v1 :: shell_catalog.shells.muzzle_velocity_mps, evidence.ballistics.muzzle_velocity_mps | Measured after: the packet declares 850 m/s in both places, the fixture launch velocity is read from found.muzzle_velocity_mps, and the six suites above are green with no expectation edited. probe_cd007_he_landed had been failing for three fixture reasons of i … | `null` / NOT_COMPARED |
| `BM-34-cd16-modern-player-flow-derived-edit-v1` | WT-CD-016 | `PROJECT_FIXTURE` | cd16-modern-player-flow-derived-edit-v1 :: modern_match_verifier.expected_rounds, modern_match_verifier.resume_proof_total | Measured after: 30 checks, 0 failed, MODERN_MATCH_PASS in the source tree on the same scenario, with MODERN_SPAWN printing rounds=24 wanted_rounds=24. The package flow, which additionally runs the separate process resume proof and captures 06_fresh_process, is … | `null` / NOT_COMPARED |
| `BM-35-cd16-modern-life-fixture-derived-edit-v1` | WT-CD-016 | `PROJECT_FIXTURE` | cd16-modern-life-fixture-derived-edit-v1 :: modern_life_verifier.expected_new_life_rounds | Measured after: PLAYER_LIVE_ROUND_PASS from the source tree on the same fixture, with the enemy firing, the player life dying once, the ticket cost deducted and the new life restoring the derived total; waiting.png and respawned.png are produced. The package c … | `null` / NOT_COMPARED |

## 4. Every row carries these bindings

| field | value for the rows above |
|---|---|
| `war_thunder.game_build` | `2.59.0.13` in every row, measured from the local install |
| `war_thunder.mode` | `Ground Realistic Battles (normal mode)` |
| `war_thunder.vehicle_variant` / `shell` / `crew_or_modifications` | `null` in every row |
| `war_thunder.source_url_or_capture_id` / `observed_at` | the local install path and the extraction provenance, in every row |
| `mcthunder.tested_sha` | the commit that last touched the order result document, or its evidence document where the order carries the accepted evidence-document form; `sha_kind` says which |
| `mcthunder.package_sha256` | `null` until CD16-T01 builds the package |
| `conditions.*` | `null`, with a note saying they are left null rather than filled from an internal run |
| `expected_reference` / `tolerance_predeclared` | `null` in every row |

## 5. Sub-orders with no row, and why that is deliberate

Rows are derived from rule migration entries. A sub-order that changed no rule therefore has no row, and it is listed here with its reason rather than padded with an invented row:

| sub-order | reason | evidence document |
|---|---|---|
| WT-CD-001 | no rule migration entry: this sub-order delivers rack and loading GEOMETRY and its state machine, measured in its own evidence document, so it contributes content rather than a rule row | `docs/wt/continuation/COMBAT_DEEPEN01_CD001_EVIDENCE.md` |
| WT-CD-002 | no rule migration entry: this sub-order delivers armour and module GEOMETRY and coverage, measured in its own evidence document | `docs/wt/continuation/COMBAT_DEEPEN01_CD002_EVIDENCE.md` |
| WT-CD-006 | no rule migration entry: this sub-order delivers the post-penetration, fuze and fragment behaviour measured in its own evidence document, and its occlusion half is the CD07-T04 fixture closed under the user ruling | `docs/wt/continuation/COMBAT_DEEPEN01_CD006_EVIDENCE.md` |

## 6. Not-compared items, listed rather than implied

- **WT-CD-003/cd003-shape-v1** — The sampled section is a project approximation; its error bound is declared in the profile, not measured.
- **WT-CD-003/cd003-rotation-step-0.02rad** — Two earlier attempts were disproved by measurement and are recorded in the CD003 evidence file.
- **WT-CD-004/cd004-ballistics-v1** — The coefficient is a project design value awaiting human calibration and is labelled design, not validated_history.
- **WT-CD-004/cd004-residual-ratio-v1** — K and the floor are project design values, calibrated by declaration rather than against measured data.
- **WT-CD-004/cd004-ballistics-v1_shared_solver** — The refinement is an eight step bounded iteration with a forty step bisection inside; its convergence tolerance is declared in the code.
- **WT-CD-005/wt012-reactive-v1** — 
- **WT-CD-007/cd07-he-family-v1** — The engineering round carries project design initial values only; no historical round or figure is claimed.
- **WT-CD-007/cd07-bounded-connectivity-v1** — The rule keys only on the open-fighting-compartment aperture because structural caps are the limit of inside travel rather than armour, so counting every aperture would make every vehicle look open.
- **WT-CD-007/cd07-external-on-every-burst** — None; the field is additive.
- **WT-CD-007/cd07-contact-and-world-detonation** — The terminal reason for the world route is internal_burst because the emitter owns it; the contact kind therefore has to be recorded on the burst rather than inferred from the terminal name.
- **WT-CD-007/cd07-external-blast-fragment-candidates** — This entry is deliberately recorded as necessary and NOT sufficient: it is kept because it corrects a real assumption, and it is explicitly not claimed to make external-blast fragments strike anything.
- **WT-CD-007/edited_loadout_total** — This is the only delivered expectation this order changed, and it changed because the order instructed adding a round, not to make a failure disappear.
- **WT-CD-008/cd008-crew-condition-v1** — Thresholds are project design initial values and are declared as such; no external efficiency figure is claimed.
- **WT-CD-008/cd008-person-station-separation** — A delivered test may still name a role where a person belongs; the eight such sites found are fixed, and the recovery player suite is window required under headless by design.
- **WT-CD-009/cd009-module-response-v1** — Every threshold and chance is a declared project design initial value and the comparison state is NOT_COMPARED; no efficiency figure is claimed as external truth.
- **WT-CD-009/cd009-breech-jam-v1** — The chance is a declared project design initial value with comparison NOT_COMPARED, and the rule is frozen: a jam consumes no round and damages no component in this version.
- **WT-CD-010/cd10-ammo-reaction-v1** — Every chance, loss fraction and isolation credit is a declared project design initial value with comparison NOT_COMPARED; no real ammunition behaviour is claimed, and where no dynamic door model exists the project keeps a logical abstraction with a scope note.
- **WT-CD-011/cd11-drive-profiles-v1** — Every value is a declared project design initial value with comparison NOT_COMPARED; no historical gear ratio is invented and no real vehicle performance is claimed.
- **WT-CD-011/cd11-recoil-v1** — Both values are declared project design initial values with comparison NOT_COMPARED; the order explicitly does not require realistic impulse figures and none are claimed.
- **WT-CD-012/cd12-observation-and-support-wired-v1** — Every precision, expiry, attenuation and blocking value remains a declared project design initial value with comparison NOT_COMPARED. Thermal and radar remain explicitly unsupported states rather than a grey filter standing in for a sensor, and no sensor ability is granted to a vehicle that does not carry it.
- **WT-CD-013/cd13-contribution-v1** — Every window and threshold is a declared project design initial value with comparison NOT_COMPARED, and no real-world attribution figure is claimed.
- **WT-CD-013/cd13-attribution-v1** — The assist window of twelve seconds and the key damage minimum are declared project design initial values with comparison NOT_COMPARED.
- **WT-CD-014/cd14-ground-rb-preset-v1** — Every number is a declared project design initial value with comparison NOT_COMPARED, and no official battle rating or real price is claimed anywhere.
- **WT-CD-014/cd14-personal-sp-book-v1** — The income table is a declared project design initial value with comparison NOT_COMPARED.
- **WT-CD-014/cd14-sortie-transaction-v1** — The steps and the release rules are declared project design initial values with comparison NOT_COMPARED.
- **WT-CD-014/cd14-rule-version-interpreter-v1** — The known version table is a declared project fact with comparison NOT_COMPARED.
- **WT-CD-015/cd15-presentation-consumer-v1** — The event kinds, points and priorities the layer consumes remain declared project design initial values with comparison NOT_COMPARED; no audio or particle asset is claimed and the headless runs carry no screenshot.
- **WT-CD-015/cd15-shell-family-effects-v1** — No shell family, penetration or fragment value is a real ammunition figure; they remain declared project design initial values with comparison NOT_COMPARED.
- **WT-CD-015/cd15-local-authority-v1** — The harness own aggregate flag reads false because it reads a NULL process exit code from its started processes, while each process printed its PASS line and returned through the passing branch and the three digests are identical; that instrument fault is stated rather than smoothed over. Losing and delaying the transport is a fixture and the order permits it; no packet loss, capacity or p95 measurement is claimed and performance stays HOLD_BY_USER.
- **WT-CD-015/cd15-information-permission-v1** — Precision, expiry and attenuation values remain declared project design initial values with comparison NOT_COMPARED, and thermal and radar remain explicitly unsupported states rather than a filter standing in for a sensor.
- **WT-CD-016/cd16-declared-manifest-expectation-v1** — The three-round manifest is a declared project content fact with comparison NOT_COMPARED; no real T-80B ammunition loadout is claimed.
- **WT-CD-016/cd16-he-velocity-850-v1** — The 850 m/s is now a value taken from the local game build and not a project design value, while the HE damage model, its 30 mm flat curve and its blast channels remain declared project policy with comparison NOT_COMPARED. The alignment is a SOURCE comparison against a data file, not an in-game behaviour capture.
- **WT-CD-016/cd16-modern-player-flow-derived-edit-v1** — The expected total is now derived from the flow own edit rather than stated, so the historical 18 lives in THIS entry instead of inside the check. The per spin counts 12 and 6 remain the flow edit policy, a project design value rather than a War Thunder value, and the check compares the product against that policy and not against the game.
- **WT-CD-016/cd16-modern-life-fixture-derived-edit-v1** — The expected total is now derived from the fixture own edit, so the historical 8 lives in THIS entry. The four rounds per shell remain the fixture edit policy, a project design value rather than a War Thunder value.
- **package** — declared layout tolerance: The project config declares 50 mm / 2 percent while the reference packet declares 1 mm / 0.1 percent. Both are recorded; reconciliation needs the user.
- **package** — registered mesh divergences: Eleven registered items are model coverage rather than authored geometry; no layout fault was found and completion of the models would close them.
- **package** — normal-match checkpoint: NOT_RUN. Fixtures do not substitute for a normal match and this agent does not sign for human play.
- **package** — beyond effective range: The declared effective range is 200 m, so the 500, 1000 and 1500 m rows of the sampling table are extrapolation only and carry no performance promise.
- **package** — publicly comparable version: Not established: the package carries no measured historical data, so all values are project design initial values.
- **WT-CD-014 divergence register** — The realistic sortie set is a PROJECT rule set, not War Thunder Ground RB. The team pool, the personal sortie points, the vehicle costs, the repeat sortie limit and the contribution income are declared project design initial values.
- **package** — external behaviour comparison: NOT_COMPARED. No War Thunder build was played, no capture exists, and this project writes no numeric similarity percentage.
- **package** — human playtest: PENDING. No screenshot, recording or player report is claimed by this agent.
- **package** — performance: HOLD_BY_USER. No FPS, p95 or capacity figure is measured or claimed.
- **package** — public release: NOT_READY. release_ready=false and public_release=false.
- **WT-CD-016** — package identity: no package has been built yet at this stage, so package_sha256 is null in every row and CD16-T01 will bind it.

## 7. The four rejection conditions and how this matrix answers them

- declared: `把文件数量或PASS数当相似度` — no count of files or passes appears as a measure of external agreement; the only external statement is NOT_COMPARED
- declared: `同一项目检查器自证战雷一致` — every row carries a project fixture or a declared rule as its evidence level, and no row is allowed to claim War Thunder agreement from a project check
- declared: `必需工程车缺资源后换训练车通过` — the required vehicles and their content are recorded in the CD16 evidence inventory, and a missing required resource is an explicit failure rather than a fallback
- declared: `未运行的最终包套用旧包证据` — every row is bound to a real commit by sha and sha_kind, so no evidence can be inherited from an earlier package or an unrun build
