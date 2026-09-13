# WT-018-R1 设计页（机枪、烟幕、侦察与支援动作）

- 对应父项：WT-018（前置：WT-015、WT-017）
- 依据：`03_全部42项目标工作单.md` 行 727-766

## 1. 现状核查

**实测：全部缺失。** `VehicleCommand` 仅有 `aim_held/range_requested/apply_range_requested/fire_requested/repair_requested/extinguish_requested/replace_crew_requested/cancel_recovery_requested/cycle_shell_requested`；全仓无 `machine_gun`/`coaxial`/`smoke_launcher`/`support_action` 实现，输入映射中无支援类动作。→ 本单为**新增**（不是改造）。

## 2. 改动清单

| 文件 | 改动 |
|---|---|
| `scripts/battle/support_actions.gd`（新，~215 行） | 逐车型辅助能力表 + 动作状态机 + 弹药池分离 + 烟幕云（共享遮蔽对象）+ 侦察/助修/拖救 + 权威防作弊 + 只读快照 |
| `tests/run_support_actions_checks.gd`（新，51 项） | 覆盖父项四条验收 + 边界拒绝 + 与 WT-017 契约打通 |
| `docs/wt/continuation/AUX_SUPPORT.md`（新） | 能力配置、弹药与作用范围规则、状态机、输入支援课目（含待接线清单） |
| 本页 | 设计页与剩余工作 |

**未改动**：`project.godot` 输入映射、`PlayerController`、HUD、`AIPerception`、任何战斗参数与既有武器/装甲数值。

## 3. 关键设计决定

1. **按车型能力**：能力表以车型为键，未登记 = 无能力并**明确拒绝**；训练车故意为空 → 不发明装备（符合"不存在的历史装备只能以明确实验配置出现"）。
2. **弹药物理分离**：模块**不持有**主炮库存接口，辅助弹只在自己的池里；以 (车型, life) 为键 → 换车/重生都不串用。
3. **烟幕 = 一个共享对象**：`occluding_media()` 是 AI/网络/回放共同读取的答案，并直接对接 WT-017 的 `media`/`channel` 规则（光学拒、热成像 0.6、不挡弹）。
4. **回放只读**：生成类动作显式校验来源白名单，`replay`/`spectator` 被拒 → "重放不再生成烟幕"。
5. **权威独占计数**：客户端请求若试图携带库存/修复量/瞬时修复 → 直接拒绝，避免"自定无限烟幕或瞬间修复"。
6. **粗粒度情报**：侦察标记精度取 WT-017 的 `shared_intel` 口径（15 m），并带过期与可读的过期原因。

## 4. 本轮验证

| 套件 | 结果 |
|---|---|
| `run_support_actions_checks`（新） | **51/51 PASS** |

父项四条验收对应：副武器/主炮分离 + 换车不串用 ✓；烟幕耗尽真拒绝 + 重放不生成 ✓；侦察过期与助修取消可理解 ✓；客户端不得自定库存/瞬间修复 ✓。

## 5. 剩余工作（如实，不声称完成）

- **输入与 UI 接线**：`project.godot` 四个动作、`InputBindingService` 默认绑定、`PlayerController` 转译、HUD 拒绝码与冲突提示、取消提示——`AUX_SUPPORT.md` §6 已给出待接线的默认键与预期提示。
- **AI 消费共享烟云**：把 `occluding_media()` 接入 `AIPerception`（当前 AI 可见性过滤独立实现）。
- **网络同步**：只读快照已就绪，协议扩展未做。
- 真实窗口课目、联机、真人 `NOT_RUN`；性能 `HOLD_BY_USER`。

## 6. 回滚

删除新模块与套件、回退文档；**零既有代码改动**，无迁移风险。
