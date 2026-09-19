# WT-EXPANSION-01 secondary armament: scenario written FIRST, implementation not started

**Status: NOT_RUN / not implemented.** The acceptance scenario exists and fails for the right reason. Nothing was
implemented in this round, and nothing in the package's sixteen sub-orders or its ninety-six cases is touched by
this note.

**Scope statement, so this cannot be mistaken for package content.** The user asked on 2026-09-19 to raise this
game's completeness directly from the unpacked War Thunder data on this machine. This work order is that mandate
made concrete: it is an **authorised expansion beyond the package**, it is named WT-EXPANSION-01 rather than
WT-CD-017, and every artifact it produces says so in its own text.

## 1. The contract, taken from the local game build and not invented

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
