# WT-002-R1 设计页（统一样车的命令、坐标与战斗快照）

- 对应父项：WT-002 / WT-004 / WT-005 / WT-006 / WT-008；依赖：WT-001-R1、WT-031-R1
- 依据：`02_首轮10张执行单.md` §04；`03` WT-002 行 55-122；`08` 第 5 段不变量

## 1. 现状（实测）

| 事实 | 证据 |
|---|---|
| 查询快照从**一次读取**的权威节点变换构成 | `scripts/query/query_snapshot_builder.gd:21-28`（hull_frame / drive / track_left|right_frame / turret_rig / barrel_pivot），缺失部件登记 `missing_parts`（34-42），不持 Node 引用（43） |
| 相对位姿属权威、渲染插值只读 | `scripts/drive/vehicle_frame_pose.gd:2-6`（`PARTS=["hull","running_left","running_right"]`，NETWORK_VERSION=6） |
| 悬挂/地面求解是唯一车体姿态提交者，且**同时驱动射击几何** | `scripts/drive/suspension_response.gd:3-4` 文件头声明 |
| 炮塔在固定步内转动、渲染帧不写权威朝向 | `tests/run_turret_tick_checks.gd:33-36`（既有窗口套件：`render_does_not_turn`） |
| 命令信封按身份判陈旧并**单步消费** | `scripts/vehicle_actor.gd:62-76`（`stale_identity`/`stale_sequence`/`invalid_input_tick`）；`TankVehicle._physics_process` 内 `_mailbox.consume()` 一次 |
| 殉爆炮塔脱离/回挂 | `scripts/damage/wreck_turret_motion.gd:29 launch`（`turret.reparent(self,true)`）、`:53-57 restore`（回挂 `tank.hull_frame` + 还原 `original_transform` + `queue_free`），`_physics_process:38` 以代际/存活守卫自动回挂 |
| **基线红灯** | `tests/run_drive_checks.gd` 在 `a1bac406` 失败 1 项（主目录与隔离工作树同 SHA 均复现） |

## 2. 目标（本单只做最小闭合）

1. 出具**权威状态/变换表**（谁写、何时写、谁只读）→ `WT-002-R1_AUTHORITY_TABLE.md`。
2. 修掉与权威结构不符的**陈旧测试**（几何/父帧），恢复基线绿灯，并加严守卫。
3. 补齐四条验收中**尚无覆盖**的部分：同 tick 姿态一致与无陈旧缓存、脱离—重置 10 次无残留、身份陈旧命令不跨重置。
4. 场景矩阵按既有套件实测登记，缺项如实标注 `NOT_RUN`。

## 3. 改动清单

| 类型 | 文件 | 改动 |
|---|---|---|
| 修测试 | `tests/run_drive_checks.gd` | 蒙皮查找改为权威父帧（hull→`tank.hull_frame`，turret→`turret`）；**新增**"蒙皮必须留在权威父帧"守卫；原"全部补片有蒙皮 + 顶点精确成员"强度不变。断言 25→26 |
| 新回归 | `tests/run_authority_state_checks.gd`（新增 19 项） | 同 tick 姿态/有限性/无缺失、快照深拷贝与无陈旧缓存、脱离—重置 ×10 无残留、身份陈旧命令 |
| 文档 | `docs/wt/continuation/WT-002-R1_{DESIGN,AUTHORITY_TABLE}.md` | 本页与权威表 |
| 日志 | `logs/WT-002-r1/*.log` | 10 套件真实输出 |

**未改动**：`query_snapshot_builder.gd`、`vehicle_frame_pose.gd`、`suspension_response.gd`、`wreck_turret_motion.gd`、`vehicle_actor.gd` —— 审计未发现需要修改的权威结构缺陷；本单不重写底盘。

## 4. 兼容与迁移

- 仅测试与文档变更，无运行时代码变更 → 无存档/协议/内容迁移需求。
- 断言集合单向增强（25→26），不放宽任何既有判定。

## 5. 验收矩阵（02 §04 必须验证）

| 要求 | 覆盖 | 结果 |
|---|---|---|
| 平地正常驾驶与射击 | `run_drive_checks`（含"production projectile accepts tilted-target shot"、"real shell penetrates sloped vehicle rear and disables actual engine only"） | 26/26 PASS |
| 侧坡 | `run_surface_drive_checks`（road/grass/concrete 阻力）+ `run_airborne_drive_checks` | 15/15、13/13 PASS |
| 单侧路沿 | `run_partial_support_checks` | 7/7 PASS |
| 坡顶/离台腾空与落回 | `run_airborne_drive_checks` + `run_landing_contact_checks` | 13/13、13/13 PASS |
| 桥缝 | `run_river_driving_checks --river-driving-check`（生产 M4 完整跨越 5 座桥、支撑与横向间隙保持；WORLD bridges=5, terrain_tiles=120） | exit 0，见 `logs/WT-002-r1/run_river_driving_checks.log` |
| 同 tick 炮口/装甲/模块容差 | 新增 `run_authority_state_checks`（快照==活节点）+ 既有 `run_hull_frame_checks`（位移后装甲三角对齐 + 炮口跟随） | 19/19、25/25 PASS |
| 渲染帧率对照只用事件/位姿、不采 FPS | `run_turret_tick_checks` 提供 `render_does_not_turn` 与 `--stall` 长帧对照（**需真实窗口**） | `NOT_RUN`（本单未跑窗口） |
| 重复 10 次脱离—重置无查询残留 | 新增 `run_authority_state_checks` 第 3 组 | 通过（残留计数 0） |

## 6. 明确不做

- 不重写底盘/悬挂/火控；不改战斗参数；不做全动力学科研。
- 不采集 FPS/p95/p99（`HOLD_BY_USER`）；性能/容量结论不因本单改变。
- 不代签真人；不改导出预设。

## 7. 回滚

`tests/run_drive_checks.gd` 单文件回退 + 删除新增套件/文档即可；运行时代码零改动，无状态迁移风险。
