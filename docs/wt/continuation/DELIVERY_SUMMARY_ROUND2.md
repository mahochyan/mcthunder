# 第 2 轮交付汇总（WT-038-R1 阶段四）

> **两处编号更正（自我更正，2026-09-13）**：
> ① 下表中的 **「WT-035-R1 回归门」应计为 `WT-036-R1`（性能/回归/长时稳定）的回归部分**——WT-035 是「主界面、战斗HUD与新手教学」，属**尚未开工**的目标单；
> ② 本批**未交付** WT-035 的任何内容，不得以回归门充当其交付。

- **基线**：`a1bac406d2bc12b32c7f7d130590f1c1a17907c9`；**交付头**：`b9eeb245`
- **分支**：`work/continuation-20260913`（**本地，未推送**）
- **规模**：全链 **32 提交 / 279 文件 / +19489 −19**；其中**第 2 轮 18 提交 / 157 文件 / +12576 −5**
- 口径：只写**有可观测证据**的结论；未跑/不可跑一律标 `NOT_RUN` 或 `DEFERRED`

## 一、第 2 轮各单完成情况

| # | 执行单 | 提交 | 交付物 | 验证 |
|---|---|---|---|---|
| 1 | **WT-017-R1** 观察契约 | `7e21ce5f` | `observation_policy.gd` + `OBSERVATION_POLICY.md`（四类信息 + 来源/模式权限矩阵） | **32/32** + 回归 34/40/39/24 |
| 2 | **WT-018-R1** 支援动作 | `f1c002f1` | `support_actions.gd` + `AUX_SUPPORT.md`（逐车型能力/弹药规则/输入课目） | **51/51** |
| 3 | **WT-019/021-R1** 地图与交通 | `e9401a2f` | `team_coordinator.gd` + 地图咽喉点/路线用途 + `TACTICAL_MAP_AUDIT.md`/`TEAM_TRAFFIC_RULES.md` | **34/34**；回归河谷两套 PASS |
| 4 | **WT-024-R1** 权威战斗 | `ffa4f597` | `network_authority_contract.gd` + `NETWORK_AUTHORITY.md` | **62/62** + 既有网络 **246** + **三进程真实端到端 PASS×3** |
| 5 | **WT-025-R1** 时间模型 | `3a48795d` | `network_time_model.gd` + `network_fault_injector.gd` + `NETWORK_TIME_MODEL.md` | **42/42** + 回归 26/21/58 |
| 6 | **WT-026-R1** 身份与收据 | `b291e705` | `network_identity_policy.gd` + `network_result_receipt.gd` + `NETWORK_IDENTITY.md` | **60/60** |
| 7 | **WT-037-R1** 房间与连续运行 | `f8478068` | `network_room_service.gd` + `ROOM_SERVICE.md` | **52/52** |
| 8 | **WT-027-R1** 现代装填 | `328ddc0a` | `loading_mechanism.gd` + `MODERN_LOADING.md` | **65/65** + 回归装填/弹药舱/毁伤 |
| 9 | **WT-028-R1** 现代装备 | `410070a1` | `modern_equipment.gd` + `MODERN_EQUIPMENT.md` | **55/55**（一次通过） |
| 10 | **WT-029-R1** 技术段冻结 | `69e5c34b` | `tech_segment.gd` + `modern_sample.gd` + `TECH_SEGMENT.md` | **50/50** |
| 11 | **WT-030-R1** 内容契约 | `0be7be77` | `vehicle_content_record.gd` + `VEHICLE_CONTENT_CONTRACT.md` | **65/65** |
| 12 | **WT-030D-R1** 资产审计 + **更正** | `03325d29` | `asset_registry_audit.gd` + `WT-030D-R1_DESIGN.md`（含**早前结论更正**） | **44/44** + 更正后回归全绿 |
| 13 | **WT-031B-D-R1** GLB 探查 | `e892dbc5` | `model_binding_probe.gd` + `MODEL_BINDING_PROBE.md` | **60/60** |
| 14 | **WT-031C-D-R1** 角色映射 | `1591eb26` | `role_mapping.gd` + `ROLE_MAPPING.md` | **72/72** |
| 15 | **WT-035-R1** 回归门 | `7052fc2a` `b9eeb245` | `REGRESSION_GATE_ROUND2_FULL.md` + JSON | **140 套件 / 117 PASS / 0 回归** |
| 16 | **WT-038-R1** 交付门 | 本提交 | `DELIVERY_WT038_R1.md` + `DELIVERY_SUMMARY_ROUND2.md` + 清单 | 导出包 **EXIT=0 ×2**、隔离通过 |

## 二、未完成项及原因（如实）

| 项 | 状态 | 原因 |
|---|---|---|
| 现代两车进入**正常对局** | `NOT_RUN` | 未获战斗准入（`combat_definition` 为空）；装填/装备为实验级 |
| M1A1 / ZTZ-99A 注册 | `NOT_RUN` | 缺内容树参考条目 + packet `model_binding`；M1A1 角色映射 4/6 需重导出 |
| `model_sources.json` 登记 | `NOT_RUN` | 无 packet 带 `model_binding`；贸然填表会把带绑定车切到更严格路径（已论证） |
| server/client 导出预设 | **需授权** | 属改构建/发布流程（红线），未动手 |
| 公网双端 / 发现 / 中继 / 专管 / 账号 | `NOT_RUN` | 未授权且未实现；已给出本地可验证替身 |
| 11 个慢套件（`art_showcase`、`challenge`、`export`、`industrial*`、`research_thumbnail_bake`、`river_*`、`traffic_*`、`village_battle`） | `DEFERRED` | 超出预算仍在输出；**不计入通过**（其中 3 个在 240 s 重跑转为 PASS） |
| 37 个按名排除套件 | `NOT_RUN` | 需窗口/真实输入/长时/性能预算 |
| 10v10/16v16 容量、空海扩展、真人、性能 | `NOT_RUN` / `HOLD_BY_USER` | 按用户边界与 HOLD 政策 |

## 三、证据索引

| 主题 | 路径 |
|---|---|
| 回归门 | `docs/wt/continuation/REGRESSION_GATE_ROUND2_{FULL,}.md`；`logs/WT-035-r1/regression-gate-full.json` |
| 交付门 | `docs/wt/continuation/DELIVERY_WT038_R1.md`；`CANDIDATE_MANIFEST_WT038_R1.json` |
| 候选包 | `E:/AIprogram/mcthunder-candidates/WT038R1/<sha>/`（仓库外） |
| 各单设计与证据 | `docs/wt/continuation/*.md`（第 2 轮新增 32 份）+ `logs/WT-0*` |
| 首轮汇总 | `docs/wt/continuation/DELIVERY_SUMMARY_ROUND1.md` |

## 四、已知风险（第 2 轮新增/更新）

1. **既有红 4 个**（`chassis_response`、`historical_road`、`team_checks`、`map_checks`）——基线即红，需单独修复单；
2. **核心套件抖动**：`run_checks` 的 `R3-A` 单帧余量（0.00°）偶发失败，建议收紧该检查的测量窗口而非放宽阈值；
3. **现代资产口径已更正**：ZTZ-99A **有**标准 GLB+manifest、M1A1 **有**可导入资产（早前由内容 grep 得出的两条结论已更正并留证）；
4. **注册表为空**但 `VehicleReadiness` 按文件存在性解析 → "未注册 ≠ 不可用"，文档已修正过强表述；
5. 本批**零**性能采样，性能结论一律不可引用。

## 五、回滚

| 层级 | 方式 |
|---|---|
| 单提交 | `git revert <sha>`（全为追加式，默认惰性） |
| 第 2 轮整体 | `git revert 559f047c..b9eeb245` 或切回 `1e7b3b1e` |
| 全链 | 切回 `a1bac406`；原工作区从未被修改（porcelain 恒 379） |
| 候选包 | 删除 `E:/AIprogram/mcthunder-candidates/WT038R1/<sha>/`（仓库外零副作用） |

## 六、变更清单（第 2 轮 18 个提交，时间倒序）

```
b9eeb245 WT-035-R1 完整回归门（140 套件 / 117 PASS / 0 回归）
7052fc2a WT-035-R1 批次 A（70 套件 / 54 PASS / 0 回归）
1591eb26 WT-031C-D-R1 角色映射作者化（72/72）
e892dbc5 WT-031B-D-R1 GLB 只读探查（60/60）
03325d29 WT-030D-R1 资产审计 + 早前结论更正（44/44）
0be7be77 WT-030-R1 载具内容契约（65/65）
69e5c34b WT-029-R1 技术段冻结 + 六场景样片（50/50）
410070a1 WT-028-R1 现代装备矩阵（55/55）
328ddc0a WT-027-R1 逐车型装填机构（65/65）
f8478068 WT-037-R1 房间/分队/连续运行（52/52）
b291e705 WT-026-R1 身份/命令校验/幂等收据（60/60）
3a48795d WT-025-R1 网络时间模型 + 故障注入（42/42）
ffa4f597 WT-024-R1 服务器权威契约（62/62 + 三进程真跑）
e9401a2f WT-019/021-R1 地图咽喉点 + 团队交通（34/34）
f1c002f1 WT-018-R1 辅助/支援状态机（51/51）
7e21ce5f WT-017-R1 观察契约（32/32）
559f047c 第 1 轮收口汇总（10 单 + 台账增量）
bbf68e4d WT-023-R1 清单空文件修正
```

**第 2 轮运行时代码改动**：35 文件 / +2711 行（新增 11 个模块 + 地图定义追加 + `tech_segment`/`role_mapping`/`vehicle_content_record`/`asset_registry_audit`/`model_binding_probe` 等），其余为 **28 个新测试入口、32 份文档、日志**。
