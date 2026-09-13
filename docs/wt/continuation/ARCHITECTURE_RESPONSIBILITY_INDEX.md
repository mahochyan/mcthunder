# 最小架构责任索引（WT-001-R2）

- 依据：`03_全部42项目标工作单.md` WT-001 行 31「更新最小架构索引，不重写全部历史文档」
- **重要前提**：`docs/ARCHITECTURE.md` 自称 **004 版**，章节只覆盖到 008，落后当前主线约 240 提交。本索引**不重写**它，只提供当前源码的最小责任索引；旧文档保留原样作为历史。
- 职责列的推导依据 = **目录名 + 代表文件（实测文件名）**，未逐文件通读；标「实测」者为本单实际打开/引用过的文件。

## 1. 入口与场景（实测）

| 角色 | 路径 | 说明 |
|---|---|---|
| 主场景 | `scenes/app.tscn` | `project.godot run/main_scene` |
| 流程入口 | `scripts/core/app_flow.gd`（478 行） | 教程、加载、`return_to_garage`、`request_leave_match`、`InputBindingService.initialize` |
| 车库/菜单 | `scripts/core/garage_shell.gd`、`scripts/ui/garage_frontend.gd`（153 行） | 菜单版本显示点；科技树入口 `open_research_tree()` |
| 科技树 | `scripts/ui/vehicle_research_tree.gd`（167 行） | 苏德五路线/改型折叠/跳转 |
| 战斗场景 | `scenes/battle/team_range.tscn`、`duel_range.tscn` | 团队战与 1v1 |
| 地图场景 | `scenes/maps/{map_hill_village,map_industrial_edge,river_junction_range,river_junction_survey}.tscn` | 两图已注册 + 河谷枢纽（勘察/正式共用） |
| 训练/实验室 | `scenes/training/*.tscn`（8 个） | ballistics / armor / damage / recovery / shell / terrain / ai_drive / ai_combat |
| 检视 | `scenes/inspection/vehicle_inspector.tscn` | 装甲/内构检视 |

## 2. 模块责任（`scripts/`，16-22 个文件/模块）

| 模块 | 文件数 | 责任（据目录名+代表文件） | 代表文件（实测名） |
|---|---|---|---|
| `core` | 16 | 应用流程、场景装载、验收清单、车库外壳 | `app_flow`、`app_scene_loader`、`garage_shell`、`acceptance_checklist` |
| `ui` | 22 | HUD、菜单、无障碍设置、本地化消费、战况/目标面板 | `battle_hud`、`hud_presenter`、`garage_frontend`、`river_objective_hud` |
| `battle` | 14 | 比赛导演/状态、占点与票池、重生、模拟快照 | `team_match_director`、`team_match_state`、`battle_objectives`、`capture_point`、`respawn_service`、`ticket_ledger`、`simulation_snapshot` |
| `maps` | 15 | 地图定义/世界几何/道路导航 | `river_junction_definition`、`river_junction_navigation`、`river_junction_world`、`village_world`、`industrial_world`、`navigation_bake_pipeline` |
| `drive` | 13 | 动力总成、路面阻力、悬挂/车体响应 | `drive_powertrain`、`drive_profile`、`surface_resistance`、`chassis_response` |
| `defs` | 12 | 车辆/武器/弹种定义与火控状态 | `fire_control_profile`、`fire_control_state`、`aim_intent` |
| `damage` | 12 | 弹药账本、装填、维修、乘员 | `ammo_inventory`、`ammo_compartment_profile`、`ammunition_supply` |
| `projectiles` | 13 | 弹道数学、拦截、化学射流、破片 | `ballistic_math`、`ballistic_intercept`、`chemical_jet_system`、`fragment_system`、`projectile_manager` |
| `armor` | 5 | 装甲层/材料响应与解算 | `armor_resolver`、`armor_layer_profile`、`armor_impact_profile` |
| `ai` | 8 | AI 驾驶/瞄准/难度/路径 | `ai_path_driver`、`aim_solver`、`ai_difficulty`、`drive_navigator` |
| `content` | 14 | 车型包、模型绑定、史料准入、弹种目录 | `bound_vehicle_model`、`historical_evidence_gate`、`historical_shell_catalog` |
| `garage` | 7 | 编成、配弹、进度/存档服务 | `garage_service`、`garage_preparation`、`lineup` |
| `layout` | 9 | 装甲补片/乘员站位/布局定义与校验 | `armor_patch_definition`、`crew_station_definition` |
| `query` | 5 | 命中查询几何与快照构造 | `query_geometry`、`query_snapshot_builder`、`external_contact_selector` |
| `replay` | 8 | 回放控制与各类记录校验 | `replay_controller`、`chemical_record_validator`、`reactive_armor_record_validator` |
| `network` | 9 | 早期本地权威服务器/客户端 | `network_battle_server`、`network_battle_client`、`server_main`、`client_main` |
| `training` | 11 | 训练/实验室场景 | `ai_combat_range`、`ai_drive_range`、`armor_range`、`terrain_range` |
| `challenges` | 7 | 挑战任务与个人最佳 | `challenge_director`、`challenge_catalog`、`challenge_battle_ui` |
| `diagnostics` | 6 | 安装/性能/玩家流程校验器 | `installation_verifier`、`performance_verifier`、`player_flow_verifier`、`match_scenario_runner` |
| `inspection` | 4 | 检视相机与查询调试面板 | `vehicle_inspector`、`preview_camera_math` |
| `feedback` | 4 | 战斗音效池、字幕、反馈 | `audio_pool`、`combat_feedback`、`combat_subtitles` |
| `art` | 14 | 美术调色/资产预算/清单校验 | `art_palette`、`asset_budget_report`、`asset_manifest_validator` |

## 3. 关键不变量（`08_IMPLEMENTER_PROMPT.txt` 第 5 段，实现时必须保持）

定义/状态/表现分离；命令在固定物理步消费一次；真实炮口发射；渲染不写伤害或炮管权威方向；车体/炮塔/模块/装甲查询同姿态同 tick；视觉 LOD 不改受击；多层接触不重复算同一板三角形；弹药守恒；死亡/重生/结算事件有完整身份且幂等；HUD/音效/回放只读已提交结果；履带支撑/驱动/受击分离，断履带不默认支撑消失；车体位姿只有一个最终求解提交者。

## 4. 已知文档缺口（登记，不在本单修）

| 文档 | 状态 | 影响 |
|---|---|---|
| `docs/ARCHITECTURE.md` | 004 版，覆盖到 008 | 不能作为当前架构依据；本索引替代其"当前可用"部分 |
| `docs/wt/CURRENT_STATUS.md` | 表格止于 2026-09-12，WT-032 行未反映实施 | 已由 `LEDGER_DELTA.md` + 增量节补正 |
| `docs/TASK_STATUS.md` | 仓库内不存在 | 旧 AGENTS 引用为历史 |
| `CHANGELOG.md` / `CONTRIBUTING.md` / 根 `LICENSE` | 不存在 | 无版本变更日志；发布材料另行登记 |
