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

## What is now available that was not before

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
