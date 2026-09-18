
# MCT-COMBAT-DEEPEN-01 / WT-CD-010 evidence: loading, split ammunition, detonation and compartment state

## 0. Stage 0 — pickup check (verbatim from the packaged list)

```
07_WORK_ORDERS.json / items[9] (WT-CD-010):
  id=WT-CD-010 ; title=装填、分体弹药、殉爆与隔舱状态 ; priority=P1 ; phase=G2 ; scope=core ; status=planned
  depends_on = **WT-CD-001, WT-CD-006, WT-CD-008, WT-CD-009**  ⇒ all four are CLOSED, so CD10 may proceed.
  related_parent_orders = WT-015 / WT-027
  basis = 现有T-80自动装填、豹2待发/备用和泄压已实现，优先复用并补边界。
  player_outcome = 玩家能通过携弹量、弹种、待发耗尽和隔舱选择管理生存与持续作战。
  read_first = scripts/defs/loading_profile.gd / scripts/gunner.gd / scripts/damage/vehicle_recovery.gd /
               scripts/defs/vehicle_runtime_state.gd / configs/vehicles/engineering/ussr_t_80b.json /
               configs/vehicles/engineering/germ_leopard_2a4.json
  source_ids = R07 / R06 / W02 / W05 ; acceptance_case_ids = CD10-T01 .. CD10-T06
```

### 0.1 The six cases, quoted
| case | title | action | expected |
|---|---|---|---|
| **CD10-T01** | 自动装填机构毁坏 | 在已装膛与未装膛时分别损坏机构 | **已装膛合法最后一发可用，后续装填受限** |
| **CD10-T02** | 待发耗尽 | 连续真实射击至待发耗尽并等待补充 | **补充由备用扣除且使用独立计时，不瞬间全满** |
| **CD10-T03** | 炮弹/装药分账 | 分别命中配置中的非爆炸弹体与装药储存 | **反应来自各自物料策略，不因都叫 ammo 而一致** |
| **CD10-T04** | 隔舱完好与被穿 | 同方向实弹打待发架，分别设置经生产事件改变的隔板状态 | **泄压/乘员风险结果按实际隔离区别，库存损失可解释** |
| **CD10-T05** | 搬运与起火 | 搬运中受击并中断/灭火/维修 | **无弹药复制丢失，动作优先级有记录** |
| **CD10-T06** | 重生和并发事件 | 殉爆同时收到第二损伤，再请求新生命 | **死亡一次、扣票一次，新生命从冻结配装恢复** |

### 0.2 Rejection conditions carried forward verbatim
```
另建第二套弹数 ✗ · 将不明真实结构伪造为史实 ✗ · 维修凭空返还损失炮弹 ✗ · 用所有弹架都必爆替代有区别的反应 ✗
```

## 1. Stage 2 — the named sources read, and the `basis` MEASURED rather than trusted

### 1.1 The single ledger already exists and already counts conservation
`scripts/damage/ammo_inventory.gd` is the one book, exactly as the order requires it to stay. It holds `_rack_shells`,
`rack_capacities`, `chamber_shell`, `transfer_shell`, `transfer_from`, `chamber_from`, `_rack_move`, `_move_sequence` and an
`occupancy_revision`, and it already keeps the three conservation counters the order names:
**`supplied`, `fired`, `lost`** - alongside `racks`, `chamber` and `in_transfer`. Its surface includes `configure`,
`configure_loadout`, `proportional_allocation` and `total_available`.

⇒ **The first design requirement needs no new ledger**; what it needs is an assertion that those counters balance across the
whole of T01, T02, T04, T05 and T06, and that no code path mutates a rack outside this file.

### 1.2 Replenishment and shot loading are already independent timers
`scripts/defs/loading_profile.gd` declares `mode` (crew / **automatic**), `initial_distribution` (sequential / proportional),
`shot_feed_rack_ids`, `supply_rack_ids`, `reserve_rack_ids`, and the whole replenishment block:
`replenishment_enabled`, `replenishment_delay_s`, `replenishment_interval_s`, `replenishment_role`,
`replenishment_module_ids` and `replenishment_stationary`, plus `required_module_ids` and `missing_crew_rate`, with
`validate()` and `validate_bindings(layout)`.

⇒ **The second design requirement is implemented already**: a shot draws from the ready rack while replenishment is a separate
timed task that draws from the reserve. What CD10 must add is the boundary: T02 has to run real fire until the ready rack is
empty and prove that the refill comes from the reserve on its own clock rather than instantly filling.

### 1.3 The two vehicles, measured (the `basis` confirmed word for word)
| vehicle | ready | reserve | device | loading profile |
|---|---|---|---|---|
| **ussr_t_80b** | `ammo_ready` cap **28** | `ammo_reserve` cap **10** | **`autoloader`**, `breech` | **mode automatic**, `required_module_ids=["autoloader"]`, **delay 8.0 s / interval 20.0 s**, role commander, distribution proportional |
| **germ_leopard_2a4** | `ammo_ready` cap **15**, **with `ammo_protection`** | `ammo_reserve` cap **27** | **`bustle_partition`** (ammo_partition), **`bustle_vent`** (blowout_panel), `breech` | **mode crew**, role loader, **delay 4.0 s / interval 13.0 s** |

The Leopard ready rack already carries a **compartment rule**: `{mode: rear_bustle, barrier_module_id: bustle_partition,
vent_module_id: bustle_vent, version: wt015-rear-bustle-v1, provenance: game_rule}` whose own reason says an intact partition
and closed access isolate stored bustle rounds while geometry and pressure response remain provisional.

⇒ **The `basis` is confirmed**: the T-80 autoloader, the Leopard ready/reserve split and the venting rule all exist, so CD10
reuses them and adds only boundaries.

### 1.4 What genuinely does not exist yet
```
`AmmoReactionProfile` has NO implementation - it is only mentioned four times - while `ammo_protection` already appears in
twenty eight places. So the reaction state machine is the new piece, it must be attached to production events by
configuration, and the deterministic behaviour already recorded as `wt015-rear-bustle-v1` must be KEPT as the legacy strategy
rather than replaced, which is what the order asks for.
```
⇒ The third and fourth design requirements are therefore the real work: a reaction profile keyed on storage type, actual
stock, damage channel and compartment state, producing not-exploded / burning / partial loss / lethal outcomes - **explicitly
not "every rack at zero explodes the vehicle"** - with rules for hatch state, a perforated partition, the vent path and
isolation during a transfer, and with a project logical abstraction and a scope note where no dynamic door model exists.

## 2. Next steps
1. write the **acceptance scenes first** for all six cases, including T02 running fire to exhaustion, T03 hitting an inert
   body store and a propellant store separately, T04 comparing an intact and a perforated compartment, and T06 raising a
   second damage event while a detonation is in flight;
2. then add the reaction state machine and the conservation assertion, keeping `AmmoInventory` the only ledger and keeping
   the existing deterministic behaviour as the legacy strategy;
3. emit committed events for loss and resupply, and record the rule in the migration table with before and after.
