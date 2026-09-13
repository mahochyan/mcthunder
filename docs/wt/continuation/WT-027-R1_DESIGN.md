# WT-027-R1 设计页（现代装填机构、待发架与失能恢复）

- 对应父项：WT-027（前置 WT-008、WT-012、WT-013、WT-015）
- 依据：`03_全部42项目标工作单.md` 行 1111-1149

## 1. 现状核查（实测）

| 要求 | 现状 | 处置 |
|---|---|---|
| 人工/自动装填、待发/后备弹、搬运与入膛按装备数据定义 | **缺失**：`LoadingProfile`/`LoadingRules` 是通用装填参数；**无逐车型机构定义**（自动 vs 人工） | 新增 `LoadingMechanism` 逐车型定义 |
| 装填手/机构/供电/炮闩/起火 分开 | **部分**：`VehicleCapabilities` 对缺装填手统一降速（WT030 文档已指出"不能给三人车虚构装填手绕过"） | 新增**通道分离**模型并双向断言 |
| 待发弹 vs 全车无弹 | **部分**：`AmmoInventory` 有弹架概念 | 新增 `empty_ready` / `empty_all` 两个具名状态 |
| 取消/换弹/再受损不复制弹药 | 已由 WT-015 事务保证 | 本单在机构层**逐操作实测守恒** |
| 下一弹选择不改膛内弹种 | **缺失显式保证** | `select_next()` 明示 `chamber_unchanged` |
| 现代与旧车统一库存接口 | **缺失映射文档** | `INVENTORY_MAPPING` 指向同一套 `AmmoInventory` 字段 |

## 2. 改动清单

| 文件 | 改动 |
|---|---|
| `scripts/damage/loading_mechanism.gd`（新，~215 行） | 逐车型机构定义（T-80B 自动转盘 28+10 / 豹 2A4 人工 15+27）+ 三阶段状态机 + 五通道分离 + 中断回位守恒 + `empty_ready`/`empty_all` + 击发清膛 + 待发架补充 + 库存映射 + 设计值声明 |
| `tests/run_loading_mechanism_checks.gd`（新，65 项） | 上述全部（含 3 次"取消-重装-再损坏"守恒循环） |
| `docs/wt/continuation/MODERN_LOADING.md`（新） | 状态图与配置来源 + 耗竭/补充/损坏课目 + 库存映射 |
| 本页 | 设计页与剩余工作 |

**未改动**：`loading_rules`、`vehicle_capabilities`、`ammo_inventory`、`ammo_compartment_profile`、`vehicle_readiness`、任何既有战斗参数与准入状态。

## 3. 关键设计决定

1. **机构来自车型条目**：`MECHANISMS[mechanism]` + `VEHICLES[vehicle]` 两层数据；未知车直接拒绝，杜绝"默认自动装填"。
2. **通道白名单**：每个机构声明它**使用**哪些通道；不属于该车的通道事件被**忽略**（因此装填手受伤不影响自动装填机）——这同时防止"给三人车虚构装填手"。
3. **中断即回位**：中断把搬运中的弹**放回来源架**并保持 `accounted_rounds()` 不变 → 取消/换弹/再受损都不复制。
4. **两态分离**：`empty_ready`（待发架空、储备仍在）与 `empty_all` 是两个具名状态，避免"待发架空=全车无弹"的误判。
5. **设计值显式**：`provenance=game_rule`、`historical_value=null`；套件断言每机构都声明了三段时长。
6. **单一库存**：映射表指向 `AmmoInventory` 的既有字段，未新建弹药系统。

## 4. 本轮验证

| 套件 | 结果 |
|---|---|
| `run_loading_mechanism_checks`（新） | **65/65 PASS** |
| `run_loading_checks` / `run_ammo_compartment_checks` / `run_damage_checks` | **PASS / PASS / PASS** |

## 5. 自纠记录（我的缺陷，2 处）

1. `var shell := ready_rack.pop_back() if ... else ...` → GDScript 把"从 Variant 推断类型"当**错误**，改为显式 `String`。
2. 删除一处 `or true` 的**空断言**后，忘了前一步没有真正中断就断言 `resume()` 后为 `idle` → 改为"先中断、再恢复"的正确路径。
均未放宽验收断言（守恒、通道分离、两态分离、时间非历史值始终为硬断言）。

## 6. 剩余工作（如实）

- **接入生产**：把机构接到 `VehicleActor`/`Gunner` 的实际装填路径（当前为零侵入新增模块）。
- M1A1 / ZTZ-99A 的独立机构定义（需各自配置来源）。
- 两车保持 `candidate_only`（**不因本单改变准入**）；弹道/材料与火控（WT-028/029）仍受现实参数证据约束。
- 窗口课目与真人 `NOT_RUN`；性能 `HOLD_BY_USER`。

## 7. 回滚

删除 `loading_mechanism.gd` 与套件、回退文档；**零既有代码改动**。
