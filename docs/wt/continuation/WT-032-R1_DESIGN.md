# WT-032-R1 设计页（河谷真实道路、桥口、部署与补给可达网络）

- 对应父项：WT-019 / WT-021 / WT-032；依赖：WT-031-R1、WT-002-R1
- 依据：`02_首轮10张执行单.md` §05；`docs/wt/WT032_ROAD_NAVIGATION.md`；`logs/WT032-navigation/RESULTS.json`

## 1. 现状（a1bac406 已有成果，本单一律保留）

| 已有 | 证据 |
|---|---|
| 道路平台压平半宽 18→30 m、连续转角消除路面缝隙、货运站建筑移位让出横向通路 | `WT032_ROAD_NAVIGATION.md:13-15` |
| 世界构成：34 建筑 / 2615 树 / 5 桥 / 120 地形 / 39 土工掩体 | 实车运行输出（本单复现） |
| 图：10v10 408 节点 417 边；16v16 857 节点 880 边；部署区两出口接主路；`through_waypoints` 连续通过 | `river_junction_navigation.gd:25-69`；本单实测 |
| 156 组泊位→占点可达；单桥封闭 8 例可绕行；车宽 3.8 m 三射线通道检查 + 地面/桥面支撑采样 | `run_river_navigation_checks` 22/22、`run_river_junction_checks` 45/45 |
| 生产 M4 实车跨越 5 座桥、暂停返回车库、自由驾驶不发收益 | `run_river_driving_checks` 34/34 |

## 2. 本单发现的两处真实缺口（均已最小闭合）

| 缺口 | 证据 | 影响 |
|---|---|---|
| **G1 河谷图没有补给**：`village_definition.gd:35-38`、`industrial_definition.gd:24-27` 都在图里放 `supplyN` 节点并由 `village_range.gd:13` 覆盖补给点；河谷的 `supply_positions()` 沿用 `team_range.gd:101` 的空实现 → 该图**不存在任何补给位置**，"出生→A/B/C→补给"无法满足或验证 | 代码比对 + 全仓 grep（`supply` 仅出现在 team_range / village / ammunition_supply） | 02 §05 必须验证项缺失；两图共用补给规则在第三图不成立 |
| **G2 出生槽位不看残骸**：`team_range.gd:147-148` 只用 `combat_actors()` 位置作为 `occupied`，`WreckRegistry` 未被查询 | 代码比对 | 残骸所在槽位会被误判为空，可能把新载具放进残骸 |

## 3. 改动清单（5 个文件，最小闭合）

| 文件 | 改动 |
|---|---|
| `scripts/maps/river_junction_definition.gd` | 新增 `supply_points(team_size)`：每队一个补给点，位于**后方部署通道末端**（x=370，z=±(deployment_z+32)），即图里已存在且已被几何检查验证支撑的节点；`point()` 抬到真实地形高度 |
| `scripts/maps/river_junction_navigation.gd` | 新增 `supply_goals`（`{"supply1": Vector3, "supply2": Vector3}`），取自已存在的通道节点；**不改序列化 graph 契约**（仍 schema_version 1 + 同样键） |
| `scripts/maps/river_junction_range.gd` | 新增 `supply_positions(team)` 覆盖，返回本方补给点（对齐 `village_range.gd` 的既有模式） |
| `scripts/damage/wreck_registry.gd` | 新增 `wreck_positions() -> Array[Vector3]`（先 `_prune_invalid()`，失效实体不贡献陈旧位置） |
| `scripts/battle/team_range.gd` | 出生占用 `occupied` 追加 `wrecks.wreck_positions()` |
| `tests/run_river_reachability_checks.gd`（新，34 项） | 图契约、可达矩阵、侧翼、入口一致性、残骸占用 |

## 4. 兼容与迁移

- graph 契约不变（`schema_version=1`、键集合不变），`supply_goals` 是对象属性而非序列化字段 → **无迁移**；旧图消费者不受影响。
- 补给点是**新增**能力：河谷图此前完全没有补给；改动后行为与村庄/工业一致（后侧补给圈 + 每 2 s 补 1 发，见 `AmmunitionSupply.RADIUS_M` 规则）。
- 出生占用新增残骸位置：只影响选槽结果（换槽或有界 `spawn_blocked`），不改变命令/伤害/胜负面。

## 5. 验证（本单实测，全部 exit 0）

| 套件 | 结果 |
|---|---|
| `run_river_reachability_checks`（新） | **34/34**（`RIVER_REACHABILITY_CHECKS_PASS`） |
| `run_river_navigation_checks --river-navigation-check` | **22/22** |
| `run_river_junction_checks --river-junction-check` | **45/45** |
| `run_river_driving_checks --river-driving-check` | **34/34** |

矩阵与版本表：`REACHABILITY_MATRIX.md`、`MAP_ROADGRAPH_VERSION.md`；原始日志 `logs/WT-032-r1/`。
**未跑**：`run_river_route_ui_checks`（需真实窗口）→ `NOT_RUN`，不以 headless 冒充。

## 6. 明确不做

不新增第四张地图；不全量重做材质/模型；不用传送验证导航；不做 20/32 容量压力采样；不采集 FPS/p95/p99；不代签真人；不改导出预设。

## 7. 回滚

五个源码文件逐个 `git revert` 即可；无存档/协议迁移。回滚后河谷恢复"无补给、出生不看残骸"的 a1bac406 行为，既有 22/45/34 套件仍应保持通过。
