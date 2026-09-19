# War Thunder local-install reference: what is recorded here, and the boundary around it

This directory holds **derived values and provenance only**. It exists because the user authorised, on
2026-09-19, using the unpacking tools to parse the War Thunder installation on this machine in order to raise the
completeness of this project.

## The boundary, stated first because everything else depends on it

```
* The extracted game data lives OUTSIDE this repository, at E:/AIprogram/wt-datamine, and the extraction tool
  lives outside it too, at E:/AIprogram/wt-tools. Neither is committed, and neither is ever packaged: no War
  Thunder file, model, texture, sound, weapon definition or data dump is redistributed by this project.
* What IS committed here is a CITATION: the values a comparison rests on, the file they came from, its sha256,
  the game build and the extraction date - the same shape the package benchmark matrix already asks for.
* The extracted values are the REFERENCE this project is measured against. They are never presented as this
  project own design values, and where a unit is not documented the interpretation is recorded as an assumption
  rather than as a fact.
```

## What was extracted, and how to reproduce it exactly

```
War Thunder install   E:/WarThunder                          build 2.59.0.13
  version source      wt_ext_cli vromf_version reports 2.59.0.13 for aces.vromfs.bin, char.vromfs.bin,
                      game.vromfs.bin and mis.vromfs.bin
tool                  wt_ext_cli v0.6.6 (binary commit 764867e35eb7ead01425781ecae0bc6488be4e22)
  release asset       wt_ext_cli-x86_64-pc-windows-msvc.zip
  asset sha256        2e7593535f341ae88956583a9ba6aada3500d153f4c4a26196cae89ecdb685af   (verified after download)
  project             https://github.com/Warthunder-Open-Source-Foundation/wt_ext_cli
command               wt_ext_cli.exe unpack_vromf -i E:/WarThunder/aces.vromfs.bin
                                     -o E:/AIprogram/wt-datamine/aces --format Json --continue Standard
result                26023 files, 727.3 MB, of which gamedata holds 25481 files (690.1 MB)
the two unit files    gamedata/units/tankmodels/ussr_t_80b.blk      sha256 0aa45815921d483a...  125507 bytes
                      gamedata/units/tankmodels/germ_leopard_2a4.blk sha256 2d09f0ed2de7143b... 117104 bytes
```

## What the record contains

`WT_REFERENCE_UNITS.json`, built by `logs/COMBAT-DEEPEN-01/build_wt_reference.js`, holds for each of the two
vehicles this project actually models:

| part | content |
|---|---|
| war_thunder | the unit file path, its sha256 and size, the raw scalar block (mass, speeds, accelerations, turn rate, smoke timings, subclass, type), and conversions with the assumption each rests on |
| structure | crew stations, weapon triggers with their real gun files, damage-part count, ammo stowage keys, modification keys, and the list of sections still available to mine |
| mcthunder | our own declared values read from the packet, each with the fact provenance the packet already carries |
| state | `NOW_COMPARABLE`: both sides are on disk under a named build, so a benchmark row can carry an actual reference instead of NOT_COMPARED |

## The first result: our reference-copied values are CONFIRMED by the game itself

```
                      War Thunder 2.59.0.13            this project            verdict
T-80B      mass       50000 kg                        50000 kg                equal
           forward    75 km/h  = 20.833 m/s           20.8333 m/s             equal
           reverse    10 km/h  =  2.778 m/s            2.7778 m/s             equal
           accel/decel 4 / 8 (unit not stated)         4 (unit not stated)     equal, unit STILL an assumption
           turn rate  30 (unit not stated)            30                      equal, unit STILL an assumption
           crew       gunner, driver, commander (3)    3                       equal, and correctly no loader
           calibre    125 mm cannon 2A46-2             125 mm                  equal
Leopard 2A4 mass      47000 kg                        47000 kg                equal
           forward    75 km/h  = 20.833 m/s           20.8333 m/s             equal
           crew       gunner, driver, loader, commander (4)  4                 equal, and correctly a loader
           calibre    120 mm Rheinmetall L44           120 mm                  equal
```
So the figures this project had previously copied from a dossier are the same figures the game file states. The
two `unit not stated` rows are exactly the fields whose units the game file leaves empty; that remains an
assumption and is not upgraded to a fact by this record.

## The second result: every armour figure this project declares is confirmed by the current build

`WT_ARMOR_COMPARISON.json`, built by `logs/COMBAT-DEEPEN-01/compare_wt_armor.js`, pairs each `armor.*` fact with
the real `DamageParts` of the installed build by a printed region rule. The T-80B unit file carries 95 armour
parts and the Leopard 2A4 carries 116.

```
rows compared        34   (17 per vehicle: hull front/side/rear/roof/floor, turret front/side/rear/roof, gun shield)
matched_exact        27   a real part carries exactly this thickness
candidates_include   7   the value is present among that region parts (supported, not unique)
matches_effective_max 0   none of our figures turns out to be an effective maximum rather than a plate
no_candidate          0   NOT ONE of our armour figures is unsupported by the installed game files
```

Selected pairs, with the part they match:

| our fact | mm | War Thunder part (2.59.0.13) |
|---|---|---|
| T-80B `hull_front_upper` / `_lower` | 80 | `hull/body_front_dm` = 80 |
| T-80B `hull_sides_*` (four zones) | 80 | `hull/body_side_dm` = 80 |
| T-80B `hull_roof_*` | 30 | `hull/body_top_dm` = 30 |
| T-80B `hull_rear_*` | 60 | `hull/body_back_dm` = 60 |
| T-80B `hull_floor_*` | 20 | `hull/body_bottom_dm` = 20 |
| T-80B `turret_front` | 250 | `turret/turret_front_dm` and `turret/turret_01_front_dm` = 250 |
| T-80B `turret_sides` | 157 | `turret/turret_side_dm` = 157 |
| T-80B `turret_roof` | 90 | `turret/turret_03_top_dm` = 90 |
| T-80B `gun_shield` | 50 | `turret/gun_mask_dm` and `gun_mask_01_dm` = 50 |
| Leopard `hull_front_upper` | 400 | `hull_front_composite_armor/body_front_dm` = 400 |
| Leopard `hull_front_lower` | 35 | `hull/superstructure_front_dm` = 35 |
| Leopard `hull_roof_front` | 35 | `hull/superstructure_top_dm` = 35 |
| Leopard `turret_front` | 250 | `turret/turret_09_front_dm` = 250 |
| Leopard `turret_sides` | 160 | `turret/turret_07_side_dm` = 160 |
| Leopard `gun_shield` | 50 | `mask/gun_mask_05_dm` = 50 |

**And this is also a version check, not only a comparison.** Our packets record
`source_refs: ["wt-2.57.1.137"]` - the figures were copied from an older build dossier - while the install here
is **2.59.0.13**. All 34 figures are still present in the newer build, so the dossier values did not go stale
across that version change. That is recorded because it is the honest form of the claim: the values are supported
by the installed files, and the record names the build they were checked against.

What the comparison adds beyond confirmation: the real *armour classes* (`RHA_tank_modern`, `CHA_tank_modern`,
`RHAHH_tank`, `titanium_alloy_vt6`, `tank_textolite`, `t_80b_composite_armor`, `tank_structural_steel`), the real
composite layer structure (T-80B textolite layers of 50/50 mm and a 60 mm superstructure front with a 1.2 generic
quality), and per-part `genericArmorQuality` and `armorEffectiveThicknessMax` values that our material policy can
be argued against instead of invented - while our `protection.zone.*` response profiles stay declared PROJECT
policy, as they already say in their own notes.



```
1. game_build: every benchmark matrix row can name War Thunder 2.59.0.13 instead of null, and every expected
   reference can cite a real file with a real hash - the matrix stops being all NOT_COMPARED by definition.
2. real weapon identities: the T-80B 2A46-2 125 mm with PKT coaxial and NSV AA machine gun, the Leopard 2A4
   Rheinmetall L44 120 mm with MG3 - including the coaxial and commander machine guns this project does not model.
3. real crew stations and damage-part counts (21 parts on both) and the 29/25 modification lists, which is the
   structural completeness the user asked for.
4. the armour, ammo-stowage, weapon and compartment sections are still in the extraction, unread, with their
   names recorded in the JSON, so the next comparisons are a matter of reading rather than of searching.
```
