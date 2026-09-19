# MCT-COMBAT-DEEPEN-01 / WT-CD-016 contract: written BEFORE the package is built

This is stage two of WT-CD-016 and it is written before any package exists, because the order implementation step two says the package is built from a determined snapshot and step three says the short gates run first. Nothing in this document is a result; every line is a condition that the package must satisfy or fail.

## 1. The four deliverable classes, each with the gate that proves it

| deliverable the order names | what has to exist | gate that proves it | failure if absent |
|---|---|---|---|
| 两车现代河谷内部开发包及manifest/hashes | one package directory built from a committed snapshot, with its executable, its data pack, a manifest and a hash list | `tests/build_release.ps1` run against the integration commit, then the manifest and hash list read back and compared with the files on disk | the package is NOT built and no identity is claimed |
| 对标矩阵及未比较项 | `COMBAT_DEEPEN01_BENCHMARK_MATRIX.json` and its readable form | already built in stage one: 31 rows, 0 external rows, 41 not-compared items, every row bound to a commit | a row without a binding, or any external row without a capture, fails |
| 整局/专项/重启证据索引 | one index naming, for each of the full match, the special fixtures and the restart, the command, the log, the sha and the case id | the index's every entry must resolve to a file that exists at the sha that produced it | an index entry that points at nothing fails the delivery |
| 已知问题、旧档迁移和回退说明 | a known-issues list, an old-save migration statement and a rollback statement naming the previous package and its commit | read back against the actual old-save path and the previous package directory | a rollback claim with no previous package named fails |

## 2. The four rejection conditions, and the check that must FAIL on each

| rejected by the order | the check that fails the package |
|---|---|
| 把文件数量或PASS数当相似度 | the benchmark matrix must contain no percentage and no count presented as agreement; a reviewer finding either fails it |
| 同一项目检查器自证战雷一致 | every matrix row must carry `SOURCE_RULE` or `PROJECT_FIXTURE`; a row claiming `WT_BEHAVIOR_COMPARISON` without a captured external reference fails it |
| 必需工程车缺资源后换训练车通过 | the required content list in section 3 is checked on disk; substituting a historical or training vehicle for a missing modern one fails it |
| 未运行的最终包套用旧包证据 | every evidence row must bind the sha that produced it, and the package manifest must name its own build commit; reusing an earlier package's results fails it |

## 3. Required content: missing means FAIL, never a downgrade

```
TWO MODERN VEHICLES, by the names the order uses:
  T-80B      configs/vehicles/engineering/ussr_t_80b.json        238360 bytes, armour, 10 modules, drive profile, compatible shells, shell catalog, assembly, geometry, model binding, 5 sources
  Leopard 2A4 configs/vehicles/engineering/germ_leopard_2a4.json 183977 bytes, armour, 11 modules, drive profile, compatible shells, shell catalog, assembly, geometry, model binding, 4 sources
  each must also resolve its MODEL and its LAYOUT at run time: a missing model or layout is a FAILURE, and the
  registered mesh divergences already on record stay recorded rather than being hidden by a substitution.
HISTORICAL REGRESSION VEHICLES (the order asks for at least one historical AP/APHE vehicle and an open-top HE fixture):
  us_m4a3_75w_vvss_1944, us_m24_m6_t85e1_1951, us_m26_m3_1945, us_m36_m4a1_1945
THE RIVER VALLEY AND THE NORMAL ENTRY:
  scenes/maps/map_river_team.tscn and scenes/maps/river_junction_range.tscn, reached through the normal UI entry
  (scenes/app.tscn -> the garage -> the battle entry), not through a test-only shortcut
THE PACKAGE PATH:
  the Windows Release preset, the installed 4.7.2.stable release template, tests/package_doc_names.json and the
  manifest and hash list the order asks for
```
If any required item is absent, the correct outcome is a recorded FAILURE with the missing item named. The order forbids passing with a substitute.

## 4. The gate order, shortest first

```
G0  identity and evidence completeness (CD16-T01): the package is built from a named integration commit, every
    identity in the manifest is read back, an UNKNOWN exit code or a script error REJECTS the package
G1  two-vehicle entry and loadout (CD16-T02): the normal UI selects T-80B and then Leopard 2A4 into the river
    valley, and the actual vehicle, ammunition, model and layout are read back and compared
G2  normal full match (CD16-T03): an ordinary match played with the frozen rules to a real ticket outcome, then a
    SECOND match in the same process, whose event stream must carry no event from the first
G3  same-life live-fire re-sortie (CD16-T04): a controlled live-fire fixture kills the player, the ticket is
    deducted, and the new life must be drivable and able to fire, with the whole chain evidenced
G4  historical and open-top regression (CD16-T05): the old AP/APHE behaviour of the historical vehicles is
    unchanged, and the new HE behaviour is declared as this version rather than silently rewritten
G5  close, restart and independent path (CD16-T06): the package starts in a NEW directory, saves, closes, and an
    independent process restarts it; loadout, research and settings must come back at the declared version and
    the process must not read the development tree to find a missing resource
```

## 5. Identity binding

```
base_sha           the commit the package is built from, named explicitly and recorded in the manifest
tested_sha         the commit the cases were executed against; it must equal base_sha for the package itself
evidence commit    the commit that records these results; it is SEPARATE from the tested commit, as the package
                   delivery class requires
package identity   manifest records source_sha, engine version, template hash, rules and content ids, package kind,
                   the required content list, the validation scope, the known failures, and the four standing flags
standing flags     release_ready=false, public_release=false, human=PENDING, performance=HOLD_BY_USER - none of
                   them may be flipped by this sub-order
```
An UNKNOWN exit code, a missing exit code, a timeout, a script error, a missing artifact or a source identity that disagrees with the evidence identity all REJECT the package, exactly as the delivery protocol states.

## 6. Explicitly out of scope for this sub-order

```
No public release, no paid store, no account service, no internet play, no performance or capacity measurement,
no re-litigating any earlier sub-order's rules, and no new rule anywhere: WT-CD-016 integrates and delivers what
the fifteen closed sub-orders measured, and any behaviour it cannot show is reported NOT_RUN rather than implied.
```
