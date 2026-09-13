# 河谷枢纽 RoadGraph / MapManifest 版本与兼容表（WT-032-R1）

- 依据：`02_首轮10张执行单.md` §05「必须交付：MapManifest/RoadGraph 版本和兼容表」
- 数据来源：`scripts/maps/river_junction_navigation.gd`、`river_junction_definition.gd` 的**实际运行输出**（本单实测），非设计推测。

## 1. RoadGraph 契约（序列化结构）

```
graph = {
  "schema_version": 1,            # 由 RiverJunctionNavigation.build() 写出
  "map_id": "river_junction_10v10" | "river_junction_16v16",
  "through_waypoints": true,      # 中间路点连续通过；旧图缺此键即沿用"路点停车"旧规则
  "nodes": [ {"id": "%.3f_%.3f", "position": [x,y,z]} ... ],
  "edges": [ {"a": <node id>, "b": <node id>, "width": <m>} ... ]
}
```

| 项 | 规则 | 证据 |
|---|---|---|
| 节点 id | `"%.3f_%.3f" % [x, z]`（交叉处共享节点） | `river_junction_navigation.gd:10` |
| 节点高度 | 道路节点 `y=8.0`；非道路节点用 `RiverJunctionDefinition.height(x,z)`（真实地形/桥面） | 同文件:11；实测"heights follow terrain and bridge decks" |
| 路段长度 | 最长约 24 m（`ceili(距离/24)` 分段） | 同文件:19,36 |
| 部署区接入 | 每泊位 → 后方通道 → 左右两个出口接主路（`road=false, width=8`） | 同文件:50-62 |
| 占点目标 | 落在区域内的道路上（`goals` 存**位置 Vector3**，非节点 id） | 同文件:63-65（本单实测确认） |
| 补给目标（本单新增） | `supply_goals = {"supply1": Vector3, "supply2": Vector3}`，位于后方部署通道末端 | 本单改动，见 §4 |

## 2. 各布局实测计数

| 布局 | map_id | 节点 | 边 | 出生泊位/队 | 占点 | 补给 |
|---|---|---|---|---|---|---|
| 10v10 | `river_junction_10v10` | **408** | **417** | 10 | A/B/C | 1/队（后侧通道） |
| 16v16 | `river_junction_16v16` | **857** | **880** | 16 | A/B/C | 1/队（后侧通道） |

## 3. 兼容表

| 消费方 | 期望 | 兼容规则 |
|---|---|---|
| `DriveNavigator.configure(graph)` | `schema_version` + `nodes` + `edges` | 本单实测两种布局均 `ok=true, valid=true` |
| `DriveNavigator` 容量 | 节点/边上限 | WT-032 已提升至 1024 节点 / 4096 边以容纳 16v16 图；旧图不因此改变行为（`logs/WT032-navigation/RESULTS.json`） |
| 旧图（村庄/工业） | 无 `through_waypoints` 键 | 沿用原"到路点即停车"规则；本单未改动其数据 |
| 本单新增 `supply_goals` | **不进入序列化 graph** | 作为 `RiverJunctionNavigation` 的附加属性暴露，因此 **graph schema 未变、无需迁移**；旧消费者忽略该属性 |
| 网络/快照 | `VehicleFramePose` v1 / 网络 v6 | 与地图图无关，本单未改 |

## 4. MapManifest（本单登记）

| 字段 | 10v10 | 16v16 |
|---|---|---|
| 边界 `bounds` | `Rect2(-740,-600,1480,1200)` | `Rect2(-1040,-800,2080,1600)` |
| 跨河通路 `crossings` | `[-520, 0, 520]` | `LANES = [-820,-520,0,520,820]` |
| 部署深度 `deployment_z` | 480 | 680 |
| 占点 | A 采石场(-520,120) / B 货运站(0,-130) / C 河畔镇(520,100)，半径 45 | 同 |
| 非计分地标 | D 机修厂 / E 农庄 / F 木材场（16v16 外侧）/ G 中继站 | 同 |
| 补给点（新增） | team1 (-370→**370**, +512)、team2 (370, −512) | team1 (370, +712)、team2 (370, −712) |
| 世界构成（实测） | 34 栋建筑 / 2615 棵树 / **5 座桥** / 120 块地形 / 39 处土工掩体 | 同 |
| `status` / `combat_admitted` | `design_preview` / `false` | 同 |

## 5. 未包含（如实）

- 环境/材质/建筑轮廓精修未达最终目标（`WT032_ROAD_NAVIGATION.md:15`）。
- **20/32 人容量、多车会车、网络**：`NOT_RUN`（本单不做容量压力采样）。
- 性能：`HOLD_BY_USER`，本单不采集任何 FPS/p95/p99。
- 射线采样不是完整车体扫掠：不构成"所有车型通过性"验收。
