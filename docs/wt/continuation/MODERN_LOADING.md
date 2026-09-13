# 现代装填机构、待发架与失能恢复（WT-027-R1）

- 依据：`03_全部42项目标工作单.md` WT-027（行 1111-1149）
- 实现：新增 `scripts/damage/loading_mechanism.gd`（逐车型机构定义 + 状态机 + 通道分离 + 守恒）
- 验证：新增 `tests/run_loading_mechanism_checks.gd`（**65/65 PASS**）+ 回归 `run_loading_checks` **PASS**、`run_ammo_compartment_checks` **PASS**、`run_damage_checks` **PASS**

## 1. 装填机构状态图与配置来源（交付物第一条）

```
idle → extracting → transferring → chambering → ready          （正常装填）
  ↑         │            │             │
  └── interrupted ←──────┴─────────────┘   （机构/装填手/供电/炮闩/起火 任一中断）
                resume（对应通道修复后）→ idle

racks: ready_rack →（空）→ reserve_rack → transfer → chamber →（击发）fired
status: empty_ready（待发架空）≠ empty_all（全车无弹）
```

| 配置来源（实测） | T-80B | 豹 2A4 |
|---|---|---|
| 机构 | `autoloader_carousel`（**三人车、无装填手岗**） | `manual_loader`（**四人车、需装填手**） |
| 待发 / 储备 | **28 + 10** | **15 + 27** |
| 影响通道 | 机构 / 供电 / 炮闩 / 起火 | **装填手** / 炮闩 / 起火 |
| 弹种 | 由 `AmmoInventory` 统一管理 | 同 |
| 数值性质 | **`provenance = game_rule`，`historical_value = null`** | 同 |

**逐车型定义，不抄同一套常量**：未知车型无机构（`unknown_vehicle`）；两车机构不同且通道不同。

## 2. 待发架耗尽 / 补充 / 损坏 课目（交付物第二条）

| 课目 | 实测结果 |
|---|---|
| 待发架耗尽 | `status() == "empty_ready"`，`ready_exhausted()==true`，但 `vehicle_empty()==false` → **与全车无弹是不同状态** |
| 继续取弹 | 自动改从**储备架**取（`source == "reserve"`），储备架递减 |
| 全车无弹 | 待发+储备+搬运+膛内皆空 → `empty_all`，`start_load()` 明确拒绝 |
| 待发架补充 | 未满 20 s → `resupply_incomplete`（不动弹）；满 20 s → 从储备架补足至容量（**设计初值**）；已满 → `ready_full` |
| 机构损坏（自动） | 中断并 `mechanism_damaged`；未修复时 `resume()` 返回 `mechanism_still_unavailable` |
| 断电（自动） | 中断并 `power_damaged` |
| 装填手失能（手动） | 中断并 `loader_damaged`；换人后可恢复 |
| 起火 | 两种机构都中断（`fire_damaged`） |
| **通道互不干扰** | **装填手受伤对自动装填机无效**（`channel_not_used_by_this_mechanism`）；**机构故障对人工装填无效**（实测双向断言） |

## 3. 守恒与"不复制弹药"（硬约束）

`accounted_rounds() = 待发 + 储备 + 搬运 + 膛内 + 已击发` —— 本单实测**全程不变**：

| 操作 | 守恒 |
|---|---|
| 装填三阶段 + 入膛 | ✓（38 → 38） |
| 击发清膛 ×28（打空待发架） | ✓ |
| 从储备架取弹直至全车无弹 | ✓ |
| **中断 → 修复 → 重装 → 再损坏 ×3 循环** | ✓ **无复制** |
| 待发架补充 | ✓ |

## 4. 现代与旧车统一库存接口映射（交付物第三条）

`INVENTORY_MAPPING` 显式指向**同一套** `AmmoInventory` 字段，不引入第二套弹药系统：

| 本机构概念 | 统一库存字段 |
|---|---|
| 待发架 / 储备架 | `ammo_inventory.rack_capacities[ready|reserve]` |
| 膛内 / 搬运 / 已选 / 允许弹种 | `chamber_shell` / `transfer_shell` / `selected_shell` / `allowed_shells` |

→ 与 WT-015 的守恒与事务（`run_ammo_compartment_checks` **PASS**、`run_loading_checks` **PASS**）一致，未另建系统。

## 5. 验收对照

| 验收要求 | 证据 |
|---|---|
| 待发弹用完 ≠ 全车无弹 | §2（`empty_ready` vs `empty_all`） |
| 毁伤打断/乘员换位/断电/维修后恢复按定义执行 | §1/§2（通道分离 + 具名拒绝 + 修复后 `resume()` 回 `idle`） |
| 下一弹选择不改掉膛内弹种 | `select_next()` 前后 `chamber_shell` 恒定（实测） |
| 没有资料的具体时间不声称精确历史值 | §1（`game_rule` + `historical_value=null`；套件断言） |

**明确不做**：不把全体现代车默认设为自动装填（两车机构不同、未知车拒绝）；不引入第二套弹药系统（映射到 WT-015 库存，守恒实测）。

## 6. 未完成（如实）

- 本机构**尚未接入** `VehicleActor`/`Gunner` 的生产装填路径（生产仍走 `LoadingProfile` + `AmmoInventory`）→ 属 WT-027 剩余工作。
- 两车**仍为 `candidate_only`、未进入对局准入**（本单未改 `vehicle_readiness`）。
- M1A1 / ZTZ-99A 的独立定义**未加入**（需各自配置，按父项要求"独立定义"）。
- 真实窗口课目与真人 `NOT_RUN`；性能 `HOLD_BY_USER`。
