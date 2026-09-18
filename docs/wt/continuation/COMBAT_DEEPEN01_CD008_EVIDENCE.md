
# MCT-COMBAT-DEEPEN-01 / WT-CD-008 evidence: crew injury, incapacitation and station relief

## 0. Stage 0 — pickup check (verbatim from the packaged list, nothing invented)

```
07_WORK_ORDERS.json / items[7] (WT-CD-008), read verbatim:
  id=WT-CD-008 ; title=乘员伤势、失能与岗位替补 ; priority=P2 ; phase=G2 ; scope=core ; status=planned
  depends_on = **WT-CD-001, WT-CD-006**   ⇒ both prerequisites are CLOSED in this order, so CD08 may proceed.
  related_parent_orders = WT-014 / WT-015
  basis = 当前抽查 DamageResolver 对有效乘员命中直接 alive=false；需要分开伤势、岗位和可用性。
          官方乘员页面中间伤势效能表述存在矛盾。
  player_outcome = 轻微伤害不自动等于全失能；乘员状态、换位和实际岗位能力一致，不凭空复活。
  read_first = scripts/damage/damage_resolver.gd / scripts/defs/vehicle_runtime_state.gd /
               scripts/damage/vehicle_capabilities.gd / scripts/damage/vehicle_recovery.gd / scripts/ui/ (display contract only)
  source_ids = R01 / R06 / W02 ; acceptance_case_ids = CD08-T01 .. CD08-T06
```

### 0.1 The six cases, quoted from `08_ACCEPTANCE_CASES.json` (原文照录 ✓)
| case | title | action | expected |
|---|---|---|---|
| **CD08-T01** | 低/中/高剂量同目标 | 用声明的工程伤害通道命中同一乘员 | 存在不同伤势/失能结果；**阈值属于项目版本而非假历史** |
| **CD08-T02** | 人和岗位分离 | 存活乘员换到失能岗位 | **人数守恒、旧岗位空缺、伤势跟随 `person_id`** |
| **CD08-T03** | 渐进累积与重复事件 | 同一事件重复 / 不同事件累积 | **重复不计伤，合法多次伤害能累积** |
| **CD08-T04** | 恢复与失能 | 对伤员推进合法恢复，对失能者同样推进 | 恢复遵守规则，**失能者不复活** |
| **CD08-T05** | 岗位能力契约 | 伤势变化后玩家/AI/装填/HUD 读取 | **读同一结果**，**中间罚率未确认时不被隐式启用** |
| **CD08-T06** | 旧档和新生命 | 读取旧 `alive` 记录再新局重生 | **迁移有版本且可回退；旧伤害不能作用新生命** |

## 1. Stage 2 — contract first (the order's own requirements, before any code)

| requirement (order) | contract consequence |
|---|---|
| **分开伤势、岗位与可用性** ✓ | one **versioned** `CrewDamageProfile`/condition; injury, station and availability are **three different things** rather than one `alive` flag |
| **保留兼容 alive 或明确迁移** ✓ | a legacy `alive` reader keeps working; anything that changes must be a **named migration with a version and a rollback** (also CD08-T06) |
| **`person_id` 与 station/role 分离** ✓ | moving a crew member **moves the person**, never duplicates one; station occupancy and person identity are separate fields |
| **轻伤/重伤/失能作为项目状态设计；效能罚率逐模式单列** ✓ | thresholds and any efficiency penalty are **declared project design values per mode**, never presented as external truth (CD08-T01, CD08-T05) |
| **未核实战雷相应版本前不声称罚率是真值** ✓ | evidence level stays project design; comparison state stays NOT_COMPARED |
| **不同输入通道（局部/破片/爆炸）但同一伤势提交服务** ✓ | the three damage channels converge on **one submission service**; injury is not simulated by UI recolouring |
| **已失能者不在本次生命中自然复活；换位不增员** ✓ | recovery is explicit and configured or absent; a move never changes the headcount (CD08-T02, CD08-T04) |
| **重复不计伤，合法多次可累积** ✓ | submissions carry an identity so a repeated event is **not** applied twice while distinct lawful events accumulate (CD08-T03) |
| **旧档保底读取先于改伤害求解** ✓ | read compatibility first, then change the production resolver (the order's own implementation step order) |
| **先可解释的固定响应，再对需要的随机加确定性 seed** ✓ | determinism first, seeded randomness only where a case requires it |

### 1.1 Rejection conditions carried forward (must not happen)
```
只增加红黄黑颜色而不变状态 ✗ · 伤员换位后变成满员 ✗ ·
把官方有冲突的效能描述编成确定事实 ✗ · 把失能人物自然复活 ✗
```

## 2. Next steps
1. **Read the four contract scripts** the order names (`damage_resolver.gd`, `vehicle_runtime_state.gd`,
   `vehicle_capabilities.gd`, `vehicle_recovery.gd`) and **measure** the present behaviour the order's `basis` asserts —
   that a hit on a valid crew member sets `alive=false` directly — rather than taking it on trust;
2. then write the **acceptance scenes first** (per the order: 同一人多次受伤 / 换位 / 自然恢复 / 死亡重生),
   and only then change the resolver;
3. keep the migration table updated for the new `CrewDamageProfile` version, with before/after runs.
