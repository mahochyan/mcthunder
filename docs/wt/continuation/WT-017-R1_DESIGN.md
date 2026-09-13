# WT-017-R1 设计页（观察权限、声音线索与烟幕的一致规则）

- 对应父项：WT-017（前置：WT-007、WT-014；本轮已具备 WT-007-R1 火控与 WT-012-R1 毁伤证据）
- 依据：`03_全部42项目标工作单.md` 行 684-723

## 1. 现状核查（实测）

| 既有能力 | 证据 | 与父项要求的差距 |
|---|---|---|
| AI 侧可见性过滤：只取可见表面，绝不读模块/乘员坐标 | `ai_perception.gd`（`# Visible surface samples, never module or crew coordinates.`）；WT-020-R1 实测隐藏目标 500 tick 全程 `visible=false` | 规则**散落在各实现**，无统一契约 |
| 观战相机 + 阵亡后观察友军 | `team_range.gd:22-23,85-92,296,452`（`spectator`/`spectator_index`） | 无"何种视图能看何种信息"的显式矩阵 |
| 小地图/情报：敌方目击或限时最后位置 | `battle_ui`/HUD 既有口径（`hud_presenter` 原因码、README 描述） | 无时间戳/精度/过期的统一字段 |
| 画质档位 | `accessibility_settings.gd`：`fx_level` 注释 **"Display only"** | 缺"画质不得移除玩法遮蔽"的结构性保证（当前靠注释约定） |
| 烟幕 | **无部署实现**（属 WT-018） | 本轮只定义并验证"烟存在时的规则" |

**结论**：本轮交付**统一契约与矩阵**（父项第一、二项交付物），并把"画质无关""重生失效""投影不泄露"变成**可执行断言**；不改造既有感知/HUD（采纳列为剩余工作）。

## 2. 改动清单

| 文件 | 改动 |
|---|---|
| `scripts/battle/observation_policy.gd`（新，~170 行） | 四类信息契约 + 媒体×通道×物理规则 + 精度/过期 + `register_life` 重生失效 + `audio_cue` + 按视图 `project()` 剥离 |
| `tests/run_observation_policy_checks.gd`（新，32 项） | 契约/媒体通道/画质无关/重生/声音/投影 + 实验室失视集成 |
| `docs/wt/continuation/OBSERVATION_POLICY.md`（新） | **Observation/ContactMemory 契约 + 信息来源与模式权限矩阵** |
| 本页 | 设计页与采纳状态 |

**未改动**：`ai_perception.gd`、`battle_ui`/HUD、`replay_*`、任何战斗参数与显示设置。

## 3. 关键设计决定

1. **世界真值只属于权威**：客户端视图 `record(world_truth)` 直接拒绝 → 从结构上阻止"把全敌军真值 Dictionary 发给 UI"。
2. **视觉 ≠ 物理**：`attenuation(media,channel)` 与 `blocks_projectile(media)` 是两组字段；烟挡视线不挡弹，建筑两者都挡。
3. **通道 opt-in**：未知介质按全阻挡保守处理，绝不假设"所有烟对所有传感器相同"。
4. **画质无关**：模块**不引用**任何显示设置（套件以源码扫描 + 三段画质等值断言双重保证）。
5. **投影二次剥离**：`project()` 对非主体条目再剥一层内构字段，误传也不外泄。
6. **重生即失效**：以 `life_id` 为键，变化即删标记，旧 life 记录被拒。

## 4. 本轮验证

| 套件 | 结果 |
|---|---|
| `run_observation_policy_checks`（新） | **32/32 PASS** |
| 回归 `run_ai_combat_checks` / `run_ai_drive_checks` / `run_ai_tactics_checks` / `run_optics_checks` | **34/34 · 40/40 · 39/39 · 24/24** |

## 5. 采纳状态（如实）

- 契约与矩阵**已实现并验证**；AI 感知侧的既有行为与矩阵一致（WT-020-R1 已独立验证）。
- **HUD 小地图 / 回放视图 / AIPerception 尚未改为以本契约为唯一来源** → 属 WT-017 剩余工作；本单不声称它们已完成改造。
- **烟幕部署**属 WT-018；本轮不伪造部署能力。
- 不声称"仅可见性过滤即可防住全部作弊"；不以真值坐标替代侦察。
- 网络与真人 `NOT_RUN`；性能 `HOLD_BY_USER`。

## 6. 回滚

删除新模块与套件、回退文档即可；**零既有代码改动**，无迁移风险。
