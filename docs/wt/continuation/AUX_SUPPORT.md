# 辅助能力配置、动作状态机与弹药规则（WT-018-R1）

- 依据：`03_全部42项目标工作单.md` WT-018（行 727-766）
- 实现：`scripts/battle/support_actions.gd`（新增，权威侧状态机）；验证 `tests/run_support_actions_checks.gd`（**51/51 PASS**）
- 与 WT-017 的关系：烟幕云是 `ObservationPolicy` 的 `media="smoke"` 输入，**同一遮蔽对象**供 AI/网络/回放读取

## 1. 辅助能力配置（逐车型，非"万能机枪"）

| 车型 | 辅助武器 | 烟幕 | 侦察 | 助修 | 拖救 |
|---|---|---|---|---|---|
| `us_m4a3_75w_vvss_1944` | 车体 7.62（600 发，0.12 s，射界 ±15°/−10…20°） | 6 发，半径 18 m，20 s，12 s 装填 | 15 s / 15 m | ✓ | ✓ |
| `us_m24_chaffee` | 并列 7.62（400 发）+ 车体 12.7（200 发，0.25 s） | 4 发，半径 15 m，18 s | 15 s / 15 m | ✓ | ✓ |
| `us_m26_pershing` | 并列 7.62（500 发）+ 车体 12.7（300 发） | 6 发，半径 18 m，20 s | 15 s / 15 m | ✓ | ✓ |
| `us_m36_jackson` | 车体 12.7（300 发） | 4 发，半径 15 m，18 s | 15 s / 15 m | ✓ | ✓ |
| `player_tank`（训练车） | **无** | **无** | **无** | ✓ | **无** |

- 表中数值是**游戏设计初值**，不冒充历史性能。
- **未列出的车型一律无辅助能力**：`fire_aux` 返回 `no_aux_capability`（不静默发一把万能机枪）；训练车即按此拒绝。
- 不存在的历史装备**不以默认配置出现**（要出现必须显式登记为该车型的实验配置）。

## 2. 弹药与作用范围规则

| 规则 | 实现 |
|---|---|
| **副武器弹药与主炮分离** | 仅 `aux_pools[weapon_id]` 计数；模块**不存在**任何主炮库存接口 |
| **换车不串用** | `begin(vehicle, life)` 以 (车型, life) 为键重建池；换车后旧武器池**不存在**（实测 `carried.is_empty()`） |
| 冷却 / 耗尽 | `aux_cooldown` / `aux_depleted`（耗尽后任何时刻都不再开火） |
| 烟幕库存与装填 | `smoke_stock` 递减；`smoke_reloading` 门控；耗尽 → `smoke_depleted` |
| 烟云作用范围 | 圆柱径向距离 ≤ `cloud_radius_m`（忽略高度）；`active_clouds()` 按 `expires_at` 过期 |
| 侦察精度与过期 | 标记精度 **15 m**（粗粒度，来自 WT-017 的 `shared_intel` 口径）；到期清除并记录 `recon_expired:<id>` |
| 助修 | `assist` 模式，非"瞬间修复"；取消返回 `repair_cancelled` + `cancel_reason` |

## 3. 动作状态机

| 动作 | 前置 | 成功 | 拒绝码 |
|---|---|---|---|
| `fire_aux(weapon)` | 车型有能力、池内有余弹、冷却已过 | 消耗 1 发并刷新冷却 | `no_aux_capability` / `aux_depleted` / `aux_cooldown` |
| `deploy_smoke(now,pos,source)` | 有烟幕能力、库存 > 0、装填已过 | 生成云对象 + 扣 1 发 + 起装填 | `no_smoke_capability` / `smoke_depleted` / `smoke_reloading` / **`replay_cannot_spawn_smoke`** |
| `recon_mark(entity,life,pos,source)` | 有侦察能力 | 生成 15 m 精度标记（带过期） | `no_recon_capability` / **`replay_cannot_mark`** |
| `start_repair_assist(target)` | 有能力 + 有目标 | 进入助修 | `no_repair_capability` / `no_target` |
| `cancel_repair_assist(reason)` | 存在活动助修 | 清除并记录原因 | `no_active_assist` |
| `connect_tow(target,state)` | 有能力、未连接、目标可拖 | 连接 | `tow_not_capable` / `tow_already_connected` / **`tow_wreck_bounds`** / **`tow_immobile_target`** / **`tow_terrain`** |
| `disconnect_tow(reason)` | 存在连接 | 断开并记录原因 | `no_active_tow` |

**回放/观战只读**：`SPAWN_SOURCES = [authority, local_player, ai]`；`replay`/`spectator` 一律被拒 → **重放不会重新生成烟幕或标记**。它们通过 `snapshot(now)` 读取同一份云列表与标记。

## 4. 共享遮蔽对象（与 WT-017 打通）

```
occluding_media(position, now) -> "smoke" | "none"
   ↓ 作为 media 传入
ObservationPolicy.record(..., source="observer_visible", media, channel)
   ├ optical : 拒绝（occluded）
   ├ thermal : 允许（衰减 0.6）
   └ blocks_projectile("smoke") == false（遮蔽 ≠ 挡弹）
```
套件实测：烟云内光学观测被拒、热成像仍可记录、烟不挡弹；AI/网络/回放读到的云来自同一 `snapshot()`。

## 5. 权威与联机规则

- `apply_client_request()`：请求中若含 `smoke_stock` / `stock` / `aux_ammo` / `ammo` / `repair_amount` / `instant_repair` / `repair_seconds` → **`client_cannot_author_inventory`**（客户端不得自定无限烟幕或瞬间修复）。
- 合法请求（`fire_aux` / `smoke` / `recon` / `repair_assist` / `cancel_repair`）由权威状态机执行；未知动作 → `unknown_action`。
- 所有计数变更只发生在权威实例内。

## 6. 正常输入支援课目（drill，供接线后按步验收）

| # | 步骤 | 建议默认键 | 预期可观察结果 |
|---|---|---|---|
| 1 | 主炮装填中按辅助武器开火 | `Ctrl+左键`（并列）／`3`（车体机枪） | 机枪弹道出现，**主炮装填计时不变**、弹药池只减辅助弹 |
| 2 | 打空辅助弹再按 | 同上 | 明确拒绝提示（`aux_depleted`），不消耗任何东西 |
| 3 | 发射烟幕 | `X` | 车体附近生成烟云；本车与 AI 的光学观测同步降级，热成像仅衰减 |
| 4 | 连按烟幕至耗尽 | `X` | `smoke_depleted` 提示；无新云生成 |
| 5 | 侦察标记敌人 | `Q` | 小地图/队伍报点出现**粗精度**标记，15 s 后过期并提示 |
| 6 | 对队友发起助修 | `F` | 进入助修；按取消 → `repair_cancelled` + 具体原因 |
| 7 | 尝试拖救残骸/熄火目标 | `T` | 明确拒绝（`tow_wreck_bounds` / `tow_immobile_target` / `tow_terrain`） |
| 8 | 回放同一局 | 结算页回放 | **不重新生成烟幕**；云与标记按记录时间轴显示 |

**接线状态（如实）**：本轮交付**权威侧状态机与规则**并全部验证；`project.godot` 输入动作、`PlayerController` 转译、HUD 提示与冲突提示**尚未接线** → 属 WT-018 剩余工作（上表给出待接线的默认键与预期提示）。**AI 侧尚未把 `occluding_media()` 接入 `AIPerception`**（AI 现有可见性过滤已独立验证）→ 同属剩余工作。

## 7. 本轮验证

`run_support_actions_checks` **51/51 PASS**，覆盖：车型能力差异与拒绝、弹药池分离与换车不串用、冷却/耗尽、烟幕库存/装填/耗尽/过期、**共享遮蔽对象**（光学拒/热成像允/不挡弹）、**回放与观战不得生成烟幕或标记**、侦察过期原因、助修取消原因、拖救五类边界、**客户端不得自定库存或瞬间修复**、快照字段齐备。

未验证：真实窗口的按键/冲突提示/HUD 课目（`NOT_RUN`）、网络同步（`NOT_RUN`）、真人（`NOT_RUN`）；性能 `HOLD_BY_USER`。
