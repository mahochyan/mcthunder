
# MCT-COMBAT-DEEPEN-01 / WT-CD-009 evidence: gradual module disablement, failure and post-repair capability

## 0. Stage 0 — pickup check (verbatim from the packaged list)

```
07_WORK_ORDERS.json / items[8] (WT-CD-009):
  id=WT-CD-009 ; title=模块渐进失能、故障与恢复后能力 ; priority=P1 ; phase=G2 ; scope=core ; status=planned
  depends_on = **WT-CD-005, WT-CD-008**   ⇒ BOTH are closed in this order, so CD09 may proceed.
  related_parent_orders = WT-014 / WT-015
  basis = 已有模块完整度、炮塔轴比例和能力推导，但部分关键模块只在归零禁用。需按模块区分，不是所有模块都线性削弱。
  player_outcome = 发动机重损后的机动力、炮闩故障风险、机构失能和维修结果，能改变玩家下一步决策。
  read_first = scripts/damage/vehicle_capabilities.gd / scripts/damage/damage_resolver.gd /
               scripts/damage/vehicle_recovery.gd / scripts/gunner.gd / scripts/defs/vehicle_runtime_state.gd
  source_ids = R06 / W02 ; acceptance_case_ids = CD09-T01 .. CD09-T06
```

### 0.1 The six cases, quoted from `08_ACCEPTANCE_CASES.json`
| case | title | action | expected |
|---|---|---|---|
| **CD09-T01** | 发动机部分损伤 | 以生产伤害降低完整度后保持同样驾驶输入 | **实际动力按已声明曲线下降而非零前完全相同** |
| **CD09-T02** | 传动/履带/驾驶员 | 分别造成三类失能 | **原因和可用转向/推进不同，不互相覆盖** |
| **CD09-T03** | 炮闩故障单次请求 | 多帧按住及重复同事件开火请求 | **只按有效请求判一次，库存结果符合故障规则** |
| **CD09-T04** | 炮管与轴机构 | 分别损坏炮管、水平轴、垂直轴 | **对应能力独立失效，不能全部变成同一个炮塔锁死** |
| **CD09-T05** | 修理与中断 | 真实维修到当前目标，中途移动/起火 | **恢复比例与能力相符，中断不返还已消耗事件** |
| **CD09-T06** | 无模块车型与重生 | 加载未装备某设备的车型并重生 | **不继承其他车能力；旧故障不污染新车** |

### 0.2 Rejection conditions carried forward verbatim
```
所有模块统一线性乘数 ✗ · 完整度颜色变了但实际能力未变 ✗ ·
维修完成直接全新且无规则变更 ✗ · 测试直接修改能力布尔值冒充生产损伤 ✗
```

## 1. Stage 2 — the contract scripts read, and the order's `basis` MEASURED rather than trusted

### 1.1 The single derivation, read in full
`scripts/damage/vehicle_capabilities.gd` derives every ability in ONE place — its own comment says "Single derivation shared by
player/AI command consumers and the HUD" — producing `drive`, `propulsion`, `left_track`, `right_track`, `fire`, `turret_scale`,
`yaw_scale`, `pitch_scale`, `stabilizer_available`, `reload_rate` and a `reasons` list, then merging the loading result.

**The `basis` is confirmed exactly**, and the line that does it is:
```gdscript
		if float(m.get("integrity",0)) > 0:
			continue
```
⇒ any module with integrity above zero is **skipped entirely**, so a module matters only at **exactly zero** — all or nothing.

**The only exceptions are the two turret axis drives**, which use a fraction:
```gdscript
		if m.get("kind")=="turret_horizontal_drive": yaw_scale=minf(yaw_scale,fraction)
		if m.get("kind")=="turret_vertical_drive":   pitch_scale=minf(pitch_scale,fraction)
```
⇒ so the present state is the **opposite** of a uniform linear multiplier: the axis drives are linear and **everything else is
binary at zero**. A `ModuleResponseProfile` choosing linear / threshold / probabilistic **per kind** is therefore the right shape,
and it is what the order asks for.

### 1.2 Related present behaviours worth stating
| behaviour | where | note |
|---|---|---|
| track side separation | `track` branch: `track_left`, `track_right`, unknown side fails BOTH | a pivot is never authorised by an unknown side |
| breech | `"breech": fire = false` | only at zero, so a **failure risk does not exist yet** — CD09-T03 has to add it |
| crew | `role_available("driver"/"gunner")` | driver affects drive and propulsion, gunner affects fire and turret |
| destroyed | forces everything off and adds the reason `crew_out` | |
| `reload_rate` | from `LoadingRules.compute`, merged last | so module state and loading share one result |

### 1.3 The six vehicles measured: the module to capability dependency table
| vehicle | modules | kinds present | kinds absent |
|---|---|---|---|
| us_m24_m6_t85e1_1951 | 9 | ammo, breech, engine, fuel, track, transmission, turret_drive | autoloader, ammo_partition, blowout_panel, barrel, axis drives, stabilizer |
| us_m26_m3_1945 | 10 | as above | as above |
| us_m36_m4a1_1945 | 10 | as above | as above |
| us_m4a3_75w_vvss_1944 | 10 | as above | as above |
| germ_leopard_2a4 | 11 | **plus ammo_partition, blowout_panel** | autoloader, barrel, axis drives, stabilizer |
| ussr_t_80b | 10 | **plus autoloader** | ammo_partition, blowout_panel, barrel, axis drives, stabilizer |

⇒ **The "not applicable" items the order asks to name are now named**: no vehicle in the delivered set carries a `barrel`, a
`turret_horizontal_drive`, a `turret_vertical_drive` or a `stabilizer`, so CD09-T04 (barrel and axis mechanisms) cannot be driven
by real vehicle data as it stands and must be driven by a **declared configuration** rather than a claimed one. Two vehicles are
natural contrasts for CD09-T06: the T-80B alone carries an `autoloader`, and the Leopard alone carries partitions and a blowout panel.

### 1.4 The real fire request, for CD09-T03
`scripts/gunner.gd` holds the request path (`try_fire` validates and asks the projectile manager for a round) and its
`blocked_reason` vocabulary is cooldown / grace / barrel_occluded / no_ammo / projectile_capacity / invalid_shell / invalid_spec —
**there is no breech or jam reason at all**. So the failure is not merely unimplemented, it has no vocabulary yet, and the order's
requirement that it be judged **once, at the correct stage of a real request**, and never re-rolled per UI frame, is a new rule of
the class the migration table records.

## 2. Next steps
1. write the **acceptance scenes first**, covering all six cases, including the two that need declared configurations (T04) and the
   contrast vehicles (T06), and including the multi-frame held and repeated fire requests of T03;
2. then introduce `ModuleResponseProfile` with per-kind strategies and keep the single derivation as the only place ability is decided;
3. emit committed events for both failure and recovery, carrying source, rule version and before/after ability;
4. record the rule in the migration table with before and after, and keep the rollback.

## 3. The per-kind response profile is written, and three attempts to wire it in were all reverted

### 3.1 What was added
```
scripts/damage/module_response_profile.gd (cd009-module-response-v1): a strategy per module KIND -
   linear for engine, transmission and the two turret axes;
   threshold for track, barrel, autoloader and stabilizer;
   probabilistic for the breech, evaluated once per real request from a seeded roll;
   binary_at_zero retained for the kinds the order does not ask to soften.
Every threshold and chance is declared as a PROJECT DESIGN INITIAL VALUE with comparison NOT_COMPARED, and every
strategy still reaches exactly zero at zero integrity, which is what the existing suites assert today.
```
### 3.2 Why it is not wired in yet, stated plainly
```
Three attempts to replace the all-or-nothing skip in vehicle_capabilities.gd were reverted:
  1. a multi-line text anchor matched nothing, and the script reported zero replacements rather than failing loudly;
  2. two single-line anchors also matched nothing, even though a whitespace-visible dump showed the exact bytes I had
     anchored on - so the anchor approach itself is what is unreliable here, not the file;
  3. a deterministic LINE SURGERY by index truncated the file from seventy lines to twenty nine, because the code that
     collected the tail of the loop matched nothing and therefore collected an empty suffix. The parse check caught it.
So the file is reverted to its committed state, the profile is kept (it is self-contained and parses clean), and the
wiring is redone next round with a method that cannot truncate: read the file whole, rewrite it whole through the file
tool, and verify the line count and a parse BEFORE running anything.
```
### 3.3 Standing lesson from this round
```
A pattern that matches nothing must FAIL LOUDLY rather than silently doing nothing or, worse, silently leaving a
collection empty. Both silent outcomes happened here: the first two attempts changed nothing, and the third changed
too much. The guard is to assert the expected shape after every structural edit - a line count and a parse - before
any run is trusted.
```

## 4. The breech failure: the state side is in place, the request side needs one measured accessor

### 4.1 What was established before implementing anything
```
scripts/gunner.gd try_fire() checks, in order: capability fire, paused, cooldown, grace, ammunition, chamber, spawn,
barrel occlusion - and it already computes a DETERMINISTIC seed for the shot itself:
   "seed": hash(JSON.stringify([_current_round(), shooter_id, tank.life_id, next_shot_id]))
So the correct place to judge a breech failure once is this request, rolled from the SAME seed, which makes a repeated
request for the same shot yield the same outcome and makes a held trigger unable to re-roll it.
```
### 4.2 What was added, and what was reverted
```
KEPT: scripts/defs/vehicle_runtime_state.gd gained an additive committed record -
   var breech_failures: Array[Dictionary] = []  and  var breech_failure: Dictionary = {}
which parses clean and changes no existing behaviour. Each entry is meant to carry the shot, the seed, the roll, the
chance, the rule identity and the ability before the failure, so a judgement is auditable and cannot be silently re-rolled.
REVERTED: the judgement itself was written into try_fire and did not compile, because the gunner has no `actor` field -
it holds `tank`, `turret`, `weapon`, `shell`, a `capabilities_provider` callable and a `projectile_manager`, and the way it
reaches the vehicle runtime state is not the spelling I assumed. Eight parse errors were reported at the first shape check
and the file was reverted immediately, which is exactly what asserting the shape before running is for.
```
### 4.3 Next step, narrowed to one measurement
```
Measure how the gunner actually reaches the runtime state - whether through `tank`, through an injected provider callable,
or through the actor that already injects `capabilities_provider` - and then judge the failure there, from the shot seed,
with the declared chance scaled by how damaged the breech is, refusing the request by the name `breech_jam` and consuming
no round, exactly as the order freezes that rule.
```

## 5. The breech judgement is in place at the real request, and its scene is one step from measuring it

### 5.1 What is now in the request path
```
scripts/gunner.gd try_fire() now judges a breech failure BEFORE the shot id is assigned and AFTER the ammunition and
chamber checks, which is exactly the correct stage the order names:
   var cd009_actor := get_parent() as VehicleActor        # the proven spelling used elsewhere in this file
   if ... ModuleResponseProfile.rolls_per_request("breech"):   # the profile decides WHICH kinds roll
      chance = declared chance * (1 - integrity fraction)     # scaled by how damaged the breech is
      roll   = hash([round, shooter, life, shot_id+1, breech]) % 1000 / 1000   # the SAME seed the shot uses
      on failure: record breech_failure {shot, seed, roll, chance, rule, round_consumed:false} in the state, set
                  blocked_reason = breech_jam, and RETURN FALSE before any round is deducted.
So: judged once per real request, from a deterministic seed, never per frame, refused by name, no round consumed -
which is the frozen rule the order asks for. It is IN PLACE but NOT YET MEASURED, because the third scene computes
capabilities and never makes a fire request, so the committed record stays empty and the case honestly reads not yet met.
```
### 5.2 Two of my own faults, both caught by asserting shape first
```
1. the first attempt spelled the actor access wrongly and produced eight parse errors - the gunner has no actor field and
   the proven spelling is get_parent() as VehicleActor, which the measurement then found in four places;
2. the scene edit wrote s3.state.breech_failure where s3 IS the state, which threw at runtime and silently STOPPED the
   suite after the third scene, so cases four to six never ran at all. The full log read then showed the error, the token
   was fixed, and all six scenes now run again.
```
### 5.3 Next step
```
Make the third scene issue a REAL fire request through the production gunner with a damaged breech, then assert three
things the order names: the failure is recorded once with its seed and rule, a HELD trigger across frames does not
re-roll it, and a REPEATED request for the same shot yields the same outcome - and that a jam consumes no round.
```
