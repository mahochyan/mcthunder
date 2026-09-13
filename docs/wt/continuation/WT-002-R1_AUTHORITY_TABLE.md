# WT-002-R1 权威状态与变换表

- 依据：`02_首轮10张执行单.md` §04「画出每个权威状态的写入者和更新阶段，按现有结构补缺」
- 方法：逐条读代码定位写入者与读取者；`run_*` 套件实测结果见 §5。**未逐文件通读的部分标注为"据文件头声明"**。
- 相关不变量（`08_IMPLEMENTER_PROMPT.txt` 第 5 段）：命令在固定物理步消费一次；真实炮口发射；渲染不写伤害或炮管权威方向；车体/炮塔/模块/装甲查询同姿态同 tick；视觉 LOD 不改受击；车体位姿只有一个最终求解提交者。

## 1. 权威状态表

| # | 权威状态 | 唯一写入者（文件:行） | 更新阶段 | 只读消费者 |
|---|---|---|---|---|
| 1 | 命令邮箱（本步命令） | `vehicle_actor.gd:62-76 submit_command_envelope` → `submit_command`（`_mailbox`） | 输入提交（任意时刻）；**消费一次**于 `TankVehicle._physics_process` | 驱动/炮塔/火控/装填（同一物理步） |
| 2 | 命令代际与序号 | `_last_input_sequence`/`_staged_sequence`/`_pending_input_tick`（`vehicle_actor.gd:73-75`）、`_expire_pending_input()` | 物理步 | `submit_command_envelope` 的陈旧判定 |
| 3 | 驱动体位姿（移动碰撞） | `TankVehicle` 驱动求解；`drive_powertrain.gd`（文件头："fixed-step longitudinal simulation shared by local, AI and authority actors"） | 固定物理步 | 查询快照 `"drive"` 项、相机跟随、AI |
| 4 | 车体权威帧 `hull_frame` | 悬挂/地面求解 `suspension_response.gd`（文件头："ground-motion solver; these authoritative poses also move shot geometry"） | 固定物理步 | 炮塔基座、相机 rig、装甲查询、炮口几何（全部作为子节点继承） |
| 5 | 左右行走机构 `track_left_frame`/`track_right_frame` | 同一悬挂求解 + `TrackAssembly` | 固定物理步 | 查询快照 `running_left/right`、断带贴图 |
| 6 | 相对姿态契约 `VehicleFramePose`（v1，网络 v6） | `vehicle_frame_pose.gd:capture(tank)` 打包 hull/running_left/running_right 的**相对**刚体位姿 | 物理步末/快照点 | 网络副本；文件头明确"render interpolation never writes back" |
| 7 | 炮塔方位 / 炮管俯仰 | 炮塔机构（`turret.mechanism`），`actor.turret.rotation.y`、`barrel_pivot.rotation.x` | 固定物理步（`run_turret_tick_checks` 证明渲染帧不转动炮塔） | 炮口节点、瞄具、AI、回放 |
| 8 | 炮口 `turret.muzzle` | **无独立写入者**：是 `barrel_pivot` 下的派生节点，位姿由父链决定 | 继承 | 发射起点（真实炮口）、几何叠加 |
| 9 | 装甲补片几何 | 布局对象 `VehicleLayoutDefinition.armor_patches`（只读配置）+ 渲染蒙皮 `Skin_<id>` 于**权威父帧**（`m4_engineering_profile.gd:104,110-120`） | 装配时创建，运行时只读 | `QueryGeometry`/`GeometryOverlay`、命中结算 |
| 10 | 模块与乘员状态 | `VehicleActor.state`（`module_states`/`crew_states`） | 命中/维修/替换事件（物理步内） | HUD、能力查询、回放 |
| 11 | 身份：`entity_id`/`life_id`/`generation`/`control_epoch` | `vehicle_actor.gd:25,89,92,129,134`（`life_id` 每次 `setup` 递增）；`state.generation` 随重置变化 | 生成/重置 | `submit_command_envelope:66`、事件应用 `209/229/231`、查询快照 `target_generation` |
| 12 | 炮塔脱离残骸 | `wreck_turret_motion.gd:launch`（`turret.reparent(self,true)`）、`restore`（回挂 `hull_frame` 并还原 `original_transform`） | 殉爆瞬间 / 重置或代际变化（`_physics_process:38` 守卫） | 视觉与查询共用同一 `TurretRig`（文件头声明） |
| 13 | 暂停/恢复边界 | `process_mode = PROCESS_MODE_PAUSABLE`（`vehicle_actor.gd:135-138`）；`team_range.gd:94/164/271/292/329 reset_pending`、`322 clear_commands`、`465 gunner.resume_grace` | 暂停/重生/新路线 | 邮箱、装填宽限、HUD |

**同 tick 一致性结论**：装甲、模块、炮口、查询快照都从**同一批权威节点变换**推导——`QuerySnapshotBuilder.build_from_vehicle` 一次读取 `hull_frame / drive / track_left|right_frame / turret_rig / barrel_pivot`（`query_snapshot_builder.gd:21-28`），布局部件缺失会登记 `missing_parts` 而不用单位变换伪装（同文件 34-42）。不存在第二套几何来源。

## 2. 本单修复：陈旧测试（基线红灯）

| 项 | 内容 |
|---|---|
| 现象 | `tests/run_drive_checks.gd` 基线失败：`[FAIL] all silhouette armor skins render actual finite query vertices`（25 项 1 失败）。**主目录与隔离工作树同 SHA 均复现**，即基线自带红灯，非本分支引入。 |
| 根因（实测） | 蒙皮由 `build_skin(actor.tank.hull_frame, actor.turret, …)` 挂到**权威 hull 帧**（`m4_engineering_profile.gd:104`），而测试在 `tank` 下查找。探针实测：补片 76（hull 10 / turret 66）；蒙皮命中 `tank`=**0**、`hull_frame`=**10**、`turret`=**66**；顶点成员不符=**0**。`9f59025f` 分离权威 hull 帧后该查找失效。 |
| 修复 | 测试改为在权威父帧查找（hull→`tank.hull_frame`，turret→`turret`），并**新增**一条更严的守卫：蒙皮必须留在权威父帧（若 hull 蒙皮出现在 `tank` 下即失败），同时保留"全部补片有蒙皮 + 顶点精确成员"的原强度。 |
| 结果 | `run_drive_checks` **26 项 0 失败**（原 25 项 1 失败），新增输出 `[PASS] armour skins stay parented to the authoritative frames (10 hull / 66 turret)`。 |
| 性质说明 | 这是**修正查找位置**，不是放宽断言：断言集合从 25 条增至 26 条，且每条仍为精确判定。 |

## 3. 新增回归：`tests/run_authority_state_checks.gd`（19 项，0 失败）

| 组 | 覆盖 |
|---|---|
| 同 tick 姿态 | 快照 hull/turret/barrel 与活节点逐一相等；`hull/drive/running_left/running_right` 变换有限；无 `missing_parts` |
| 快照语义 | 改快照不回写活节点；炮口不动；驱动若干固定步后**新快照反映新姿态**（无陈旧缓存） |
| 脱离—重置 ×10 | 每轮 `launch` 后 turret 父节点=残骸节点、`restore` 后回挂 `hull_frame`、局部变换精确还原；**残骸节点/缺失部件/几何叠加残留 = 0** |
| 身份陈旧命令 | 当前身份命令被接受；**伪造 life_id → `stale_identity`**；重置前命令仅在身份确实存活时被接受（实测重置改变身份 → 被拒）；重置后新身份命令被接受 |

## 4. 与既有套件的分工（不重复造）

| 既有套件 | 已覆盖 | 本单动作 |
|---|---|---|
| `run_hull_frame_checks` (25) | 炮塔/相机归属 hull 帧、车体位移独立于移动碰撞、位移后炮口与查询跟随、**位移后装甲三角对齐**、重置清位移 | 直接复用，未改 |
| `run_turret_tick_checks`（需真实窗口） | 360 固定 tick 跟踪、渲染帧不转炮塔、2 发 2 命中、`--stall` 长帧对照 | 直接复用；本单未新增窗口运行 |
| `run_command_contract_checks` | 信封编解码、重复序号拒绝、非法字段、tick 窗口 | 直接复用；本单补"跨重置身份"一项 |
| `run_partial_support_checks` (7) | 单侧支撑/路沿 | 复用 |
| `run_landing_contact_checks` (13) | 接地确认、腾空与落地 | 复用 |
| `run_track_assembly_checks` (89) | 左右履带独立、断带不取消支撑 | 复用 |

## 5. 实测证据（本单运行时序）

| 套件 | 结果 | 日志 |
|---|---|---|
| `run_authority_state_checks`（新增） | **19 项 0 失败**，exit 0 | `logs/WT-002-r1/authority-run.log` |
| `run_drive_checks`（修复后） | **26 项 0 失败**，exit 0 | `logs/WT-002-r1/run_drive_checks.log` |
| `run_hull_frame_checks` | 25 项 0 失败 | `logs/WT-002-r1/run_hull_frame_checks.log` |
| `run_turret_mechanism_checks` | 34 项 0 失败 | 同名日志 |
| `run_partial_support_checks` | 7 项 0 失败 | 同名日志 |
| `run_landing_contact_checks` | 13 项 0 失败 | 同名日志 |
| `run_track_assembly_checks` | 89 项 0 失败 | 同名日志 |
| `run_surface_drive_checks` | 15 项 0 失败 | 同名日志 |
| `run_airborne_drive_checks` | 13 项 0 失败 | 同名日志 |
| `run_moving_contact_checks` | 67 项 0 失败 | 同名日志 |
| `run_river_driving_checks`（需 `-- --river-driving-check`） | **34 项 0 失败**（`RESULT river_driving passed=34 failed=0`；生产 M4 完整跨越 5 座桥，支撑与横向间隙保持） | 同名日志 |
| `run_command_contract_checks` | 35 项 0 失败 | 同名日志 |

## 6. 未运行 / 边界（如实）

- **未采集任何 FPS/p95/p99**（`HOLD_BY_USER`）；渲染帧率对照只用事件与位姿（`run_turret_tick_checks --stall` 属既有窗口套件，本单未跑）。
- **真实窗口**本轮未跑（`run_turret_tick_checks`、`run_*_player_checks` 需窗口）→ 记为 `NOT_RUN`，不以 headless 代替。
- 未做全动力学科研：只补两辆样车与河谷正常道路范围内的权威一致性。
