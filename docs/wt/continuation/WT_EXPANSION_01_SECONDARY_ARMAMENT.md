# WT-EXPANSION-01 secondary armament: DECLARED, INSTALLED and FIRING; the records and the HUD are what remain

**Status: steps 1 to 5 DONE and measured; the round never left a runnable state at any point.** The acceptance
scenario is 45 checks with zero failures and `WT_EXPANSION_01_PASS`, and the main-gun suites are unchanged.

**Scope statement, so this cannot be mistaken for package content.** The user asked on 2026-09-19 to raise this
game's completeness directly from the unpacked War Thunder data on this machine. This work order is that mandate
made concrete: it is an **authorised expansion beyond the package**, it is named WT-EXPANSION-01 rather than
WT-CD-017, and every artifact it produces says so in its own text.

## What is DONE, with the measurement that proves each step

| step | what it does | measured evidence |
|---|---|---|
| 1 declaration | both packets carry `secondary_weapons` with the group, gun, calibre, belt, reload, cadence, round and round speed from the extracted files, with flat provenance naming the gun file | every declaration leg passes; the production pipeline still ADMITS both packets, which is what proves the insertion is structurally sound |
| 2 runtime channels | `Gunner` installs one INDEPENDENT channel per weapon, each with its own belt ledger, cadence, round and cooldown; `VehicleActor` installs them from the packet on the setup path | the runtime exposes 2 channels per vehicle, built from the declaration |
| 3 round profiles | each secondary round declares its own classic AP profile: family, normalization, overmatch, ricochet limit, explicit rolled/cast table and a typed penetration curve | the declared round identity, belt and speed stay the game values while the penetration profile is declared project policy, and the final piece was the `wt012-full-caliber-v1` version the armour validator keys on |
| 4 launch | the shot is built in the SAME shape the main gun builds and fired through the SAME `ProjectileManager`, carrying the round own profile and calibre | a refused launch is ROLLED BACK - belt 750 to 750 and 200 to 200 with `projectile_id` 0 - which was measured against the real manager, twice, as the gates refused `invalid_armor_policy` and then `invalid_impact_profile` |
| 5 firing | the round actually leaves the barrel | `{ "ok": true, "reason": "fired" }` with the belt 750 to 749 and 200 to 199 and a REAL projectile whose state the manager returns, asserted by the probe |

Guards that earned their keep along the way, all recorded where they happened: the packet insertion is parsed before
it is written (two malformed candidates refused, no packet touched), the scripts are parse-checked before any suite
runs (a wiring edit using `defs` out of scope was refused outright), and a script error I introduced - asking a
`TankVehicle` for an `actor` property it does not have - was removed rather than tolerated even though the probe
passed with it present.

## What REMAINS

```
A. the secondary rounds must enter the DAMAGE and REPLAY records the same way the main gun rounds do - **DONE and
   measured**. A secondary shot is frozen into the SAME ShotRecordStore the replay reads, carrying its own round
   identity: the measurement reads `records 0 -> 1` with `shell_id=ap_i_ball shooter=wtexp01_1 shot=1` on the T-80B
   and `shell_id=ap_ball shooter=wtexp01_2 shot=1` on the Leopard 2A4.
   **AND THE PREVIOUS ROUND OWN CLAIM IS CORRECTED HERE:** that round reported "a secondary round does not reach the
   replay path today" as a product gap. IT WAS NOT. The manager freezes a record when the round TERMINATES, and that
   leg never flew the round - and when it did, its first cap of 900 steps was still shorter than the round own 4 s
   flight age (960 steps at 1/240), so the flight stopped just short of its own expiry. Both were faults of the leg,
   not of the product, and the record path had been working all along.
B. the HUD and controls need to select and fire a secondary channel, so the feature is reachable by a player and
   not only by a probe;
C. the main-gun suites must keep passing at every step, which they have: engineering runtime, shell, damage and
   feedback all exit 0 after the latest change.
```

## The contract, taken from the local game build and not invented

From `docs/wt/wt-reference/WT_REFERENCE_SECONDARY.json` (War Thunder **2.59.0.13**, extracted with
`wt_ext_cli v0.6.6`, provenance and hashes in `docs/wt/wt-reference/README.md`):

| vehicle | group | gun file | calibre | belt | reload | cadence | round | speed |
|---|---|---|---|---|---|---|---|---|
| T-80B | `coaxial` | `7_62mm_pkt_user_machinegun.blk` | 7.62 mm | 750 | 8 s | 11.66 /s (~700 rpm) | `ap_i_ball` | 817.5 m/s |
| T-80B | `machinegun` | `12_7mm_nsv_t_80_user_cannon.blk` | 12.7 mm | 250 | 5 s | 11.666 /s | `ap_i_t_ball` | 865 m/s (3400 m) |
| Leopard 2A4 | `coaxial` | `7_92mm_mg3_user_machinegun.blk` | 7.92 mm | 200 | 8 s | 20 /s (1200 rpm) | `ap_ball` | 853 m/s |
| Leopard 2A4 | `machinegun` | same MG3 | 7.92 mm | 200 | 8 s | 20 /s | `ap_ball` | 853 m/s |

Both vehicles also carry a `commander` trigger the game keeps as a dummy; it is deliberately **out** of this scope
because it fires nothing.

## 2. Acceptance criteria, written before the implementation

`tests/probe_wtexp01_secondary_armament.gd` asserts, per vehicle:

1. the packet **declares** its two secondary weapons, keyed by the group the file names, each carrying the calibre,
   belt size, reload, cadence, round name and round speed of the table above;
2. a **real actor** exposes that many secondary firing channels at runtime;
3. when the implementation lands, the **main gun is untouched** - the same tests that cover it today must run
   unchanged, because the point of a separate channel is that it does not become a bigger magazine.

**Measured state today: 15 checks, 8 failed, 6 unmet-declaration legs, `WT_EXPANSION_01_FAIL`.** The failing legs
are exactly the declaration and runtime-channel ones; the setup legs pass (the definitions load, both engineering
packets are admitted, real actors install), so the failure is the absent feature rather than a broken probe.

## 3. Implementation order, and what will NOT be done

```
step 1  the DECLARATION in the two packets: a secondary_weapons list carrying the table above, with the
        provenance recorded the way every other packet value records it (origin, source_refs, status, unit);
step 2  the RUNTIME channel: a second firing path with its own belt ledger, its own cadence and its own round,
        selected and fired through the same production request path the main gun uses, never a parallel system;
step 3  the ACCEPTANCE re-run until the probe passes in full, plus the main-gun suites unchanged (shell,
        engineering runtime, damage) to prove the first weapon did not move.
NOT done: the commander dummy trigger, any tracer or belt-mix modelling the file does not state, and any change to
the main gun's rules, values or projections.
```

## 4. Why this is worth doing rather than decoration

Both real belts are armour-piercing incendiary rounds, so a machine gun is a second real firing path with its own
round and cadence, not a cosmetic extra. The cadence difference between the two vehicles is real data this project
has never had: about 700 rounds per minute on the T-80B against 1200 on the Leopard 2A4.
