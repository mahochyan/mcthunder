# MCT-COMBAT-DEEPEN-01 / WT-CD-007 delivery: HE external blast, fragmentation and overpressure

Status: **COMPLETE_WITH_GAPS**. Six cases of this sub-order exist; five are measured and one half of T04 is not, and that is stated rather than rounded up. The evidence state is the engineering self-consistent version only: a publicly comparable version is NOT established, so no numeric agreement with any external title is claimed.

## 1. Source identity

| field | value |
|---|---|
| package_id | MCT-COMBAT-DEEPEN-01 |
| work_order_id | WT-CD-007 |
| base_sha | `44c33c83d5876383793bfcce4a4e314d5acb4e24` |
| implementation_sha | `e843133bb3a9d2c817eda4aacba5a5a248630fd6` |
| tested_sha | `e843133bb3a9d2c817eda4aacba5a5a248630fd6` |
| final_sha | `e843133bb3a9d2c817eda4aacba5a5a248630fd6` |
| engine | Godot 4.7.2-stable win64 console, gl_compatibility |
| rules_version | cd07-he-family-v1; cd07-bounded-connectivity-v1; cd07-external-on-every-burst; cd07-contact-and-world-detonation; cd07-external-blast-fragment-candidates |

## 2. Six deliverable classes

| class | what this sub-order delivers |
|---|---|
| production implementation | the HE family and an engineering HE bound to one gun; the bounded connectivity pressure verdict; the external flag on every burst; contact and world detonation for an external blast; the gated multi-target fragment candidates. Definitions stay read-only; runtime state stays separate. |
| source identity | the table above; evidence commits and tested commit are the same commit here, stated rather than implied. |
| run evidence | real commands, working directory, engine version, exit codes, per-run raw stdout and stderr kept unfiltered; see `logs/COMBAT-DEEPEN-01/`. |
| operational evidence | headless scripted suites and probes through the production call chain; no screenshots are claimed, and the fixtures declare themselves TEST ONLY. |
| current limits | T04 occlusion half NOT measured; the external-blast fragment candidates are necessary and NOT sufficient; CD08..CD016 NOT_RUN; performance HOLD_BY_USER; human playtest PENDING; public release not requested. |
| continuation and rollback | next dependency is the remaining sub-orders; every rule carries a rollback in the migration table; no user file is deleted as a rollback. |

## 3. War Thunder behaviour -> code location -> case id

| behaviour the order names | code location | case | evidence |
|---|---|---|---|
| a closed compartment is not emptied through an intact wall: pressure has no path in | `scripts/projectiles/projectile_manager.gd` `_emit_internal_burst`, `model = cd07-bounded-connectivity-v1`, keyed on `open_fighting_compartment` in the layout snapshot | CD07-T01 | `tests/probe_cd007_he_spec.gd`, `tests/probe_cd007_open_contrast.gd`, `tests/probe_cd007_world_burst.gd` |
| an open compartment is affected while a covered one is not | `scripts/content/historical_vehicle_geometry.gd` `declare_opening`; `scripts/projectiles/shell_effect_policy.gd` `inside`/`on_inside_path` | CD07-T02 | `tests/probe_cd007_hist_openings.gd`, `tests/probe_cd007_open_contrast.gd` |
| a thin plate is breached and the bulkhead behind it answers for itself | `scripts/projectiles/projectile_manager.gd` contact loop and `handle_contact`; `scripts/armor/armor_resolver.gd` | CD07-T03 | `tests/probe_cd007_two_plates.gd`, `tests/probe_cd007_bulkhead.gd` |
| an external HE detonates on the world rather than being stopped inert | `scripts/projectiles/projectile_manager.gd` world-contact branch, gated on the external blast policy | CD07-T04 (detonation half) | `tests/probe_cd007_world_burst.gd` |
| a jet is not counted again as overpressure | `scripts/projectiles/chemical_jet_system.gd` `effect_channel`; `scripts/projectiles/chemical_profile.gd` and `scripts/projectiles/spall_profile.gd` validators | CD07-T05 | `tests/probe_cd007_heat_isolation.gd` |
| one lawful effect per object; an unpermitted target takes nothing; cancellation is named | `scripts/projectiles/projectile_manager.gd` `contact_policy`, `cancel_all`, damage record keys | CD07-T06 | `tests/probe_cd007_finality.gd` |

## 4. Five validation layers, not substituted for one another

| layer | state |
|---|---|
| rule and negative | measured: unsupported effects are refused by name |
| standard fixture | measured: independent analytical answers, not the function under test |
| actual actor integration | measured: real muzzle, ammunition, armour, modules and match call chain |
| normal player flow and package | measured for the garage and loadout legs; the sub-order itself is not a UI feature |
| external behaviour and human | NOT_COMPARED and PENDING; no claim is made and nothing is signed on the user behalf |

## 5. Case status

| case | state | executor |
|---|---|---|
| CD07-T01 | MEASURED | `tests/probe_cd007_he_spec.gd ; tests/probe_cd007_open_contrast.gd ; tests/probe_cd007_world_burst.gd` |
| CD07-T02 | MEASURED | `tests/probe_cd007_open_contrast.gd ; tests/probe_cd007_hist_openings.gd` |
| CD07-T03 | MEASURED | `tests/probe_cd007_two_plates.gd ; tests/probe_cd007_bulkhead.gd` |
| CD07-T04 | PARTIAL | `tests/probe_cd007_world_burst.gd (detonation measured) ; the occlusion contrast is NOT measured` |
| CD07-T05 | MEASURED | `tests/probe_cd007_heat_isolation.gd` |
| CD07-T06 | MEASURED | `tests/probe_cd007_finality.gd` |

Not run, named rather than omitted: the occlusion half of CD07-T04; and CD08..CD016, six cases each, listed in `COMBAT_DEEPEN01_CASE_COVERAGE.md`.

## CD07-T04 CLOSED BY MEASUREMENT (user ruling: build it first, then open CD15)
```
The occlusion half of the fourth case had been CLAIMED in this document while the result file recorded five of six cases
executed. It has now been built and measured rather than restated.
tests/probe_cd007_occlusion_target.gd puts a real second vehicle BEHIND the wall - six metres behind it, with its own
module and crew state readable - and fires the external HE at the wall from OUTSIDE, at x +9 travelling in -X, so the wall
is the first thing met.
MEASURED:
   O1 the round terminates AT the wall as internal_burst with contact_kind world_contact and still records all three
      channels with external true, so the world contact detonates as the case requires;
   O2 the overpressure channel is NOT applied, with the reason that a closed compartment with no breach and no declared
      opening gives the pressure no path in, so no interior overpressure is invented;
   O3 the target behind the wall keeps all TEN modules undamaged, loses NO crew, is not destroyed and records NO death.
So all three claims of the case - the world contact detonates, the obstruction still works, and no through-wall total
damage is dealt - are confirmed by measurement. CD007 result status is raised from COMPLETE_WITH_GAPS to COMPLETE and the
executed case list is corrected to six of six.
```
