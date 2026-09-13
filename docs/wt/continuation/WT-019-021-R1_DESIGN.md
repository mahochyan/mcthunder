# WT-019-R1 / WT-021-R1 设计页（服务战术的地图 + 团队分工与交通收口）

- 对应父项：WT-019（前置 WT-003/006/017）、WT-021（前置 WT-020）
- 依据：`03_全部42项目标工作单.md` 行 770-808、855-896
- 共用一轮的原因：两张单的缺口都在"地图数据 ↔ AI 交通"这一接缝上（地图没有发布咽喉点，AI 让行规则因此无法在真实地图上生效）

## 1. 现状核查（实测）

| 要求 | 现状 | 处置 |
|---|---|---|
| 复用河谷枢纽、不另起地图 | 已存在（408/857 节点、三占点、补给、泊位） | 复用，零新建 |
| 路线定义战术用途 | **缺失**（道路图只有连通性，无用途） | 新增 `route_purposes()` |
| 桥面/路口等地形关系统一、供 AI 使用 | **缺失**（AI 让行的 `chokepoint_test` 是空 Callable） | 新增 `chokepoint_test()`/`chokepoint_labels()` 并交给协调器 |
| 团队协调器（分工 + 交通归因） | **缺失**（WT-020-R1 只有分配器，无队伍级协调与归因） | 新增 `TeamCoordinator` |
| "驻守/交火/维修/不能移动"与"堵车"分别归因 | **缺失** | 七类归因 + `summary()` 摘要 |
| 残骸作动态障碍 | 部分（WT-032-R1 只把残骸计入出生占用） | 协调器发布 `dynamic_obstacles` |
| 车型宽度参与规划 | 已实现（`DriveNavigator.request_path` 传 `drive_collision_size.x`） | 沿用，未改 |
| 脱困后恢复原目标 | 已实现（hop 不替换目标 + 重试） | 本轮补测（实测通过） |

## 2. 改动清单

| 文件 | 改动 |
|---|---|
| `scripts/maps/river_junction_definition.gd` | 新增 `bridge_centers()`/`chokepoint_test()`/`chokepoint_labels()`/`route_purposes()` 与常量（余量 22 m、桥长 55 m、车道半宽 14 m） |
| `scripts/battle/team_coordinator.gd`（新，~120 行） | 队伍协调器：任务分配（复用分配器）+ 友好行发布 + 残骸动态障碍 + 七类归因 + 一局摘要 |
| `tests/run_team_traffic_checks.gd`（新，34 项） | 咽喉点/用途/覆盖/归因/让行/换边/残骸/脱困恢复 |
| `docs/wt/continuation/TACTICAL_MAP_AUDIT.md`、`TEAM_TRAFFIC_RULES.md` | 两张单的交付物 |
| 本页 | 设计页与剩余工作 |

**未改动**：地图几何与地形函数、导航图数据、AI 路径驱动、比赛规则、任何战斗参数。

## 3. 本轮发现并修正的真实缺陷

**10v10 布局没有任何侧翼路线标签**：旧 `route_purposes` 把"外侧"写死为 ±820 车道，而 10v10 只有 `[−520, 0, 520]` → 该布局标不出侧翼/观察路线（与 WT-019 验收"至少一种绕过主火线的路线"冲突）。现改为"**本布局最外侧车道**"，实测两布局均有侧翼路线（16v16 2 条、10v10 4 条）。

## 4. 自纠记录（我的操作缺陷）

1. 对 `river_junction_definition.gd` 的一次编辑误吞了 `road_lines()` 的签名换行 → 该文件解析失败并连带类解析失败；已修复。
2. 套件两处 GDScript 类型推断错误（`.assignments` 为 Variant）→ 显式声明 `Dictionary`；已修复。
3. 全程无既有行为改动被掩盖：修复后回归 `run_river_reachability_checks`、`run_river_engagement_checks` 均 **PASS**。

## 5. 验证

| 套件 | 结果 |
|---|---|
| `run_team_traffic_checks`（新） | **34/34 PASS** |
| `run_river_reachability_checks` / `run_river_engagement_checks` | **PASS / PASS** |

父项验收对应：三点任务覆盖 + 不全挤最近点 ✓；桥口对向车可复现处理 ✓；脱困后原目标恢复 ✓；换边不过分依赖出生侧 ✓。WT-019 侧：两队常规车辆无传送可达 ✓（WT-032-R1 + 本轮回归）；存在绕过主火线的路线且可反制（侧翼/观察路线 + 桥头掩体）✓；勘察与出生/占点一致 ✓。

## 6. 剩余工作（如实）

- **可破坏墙删除后不留隐形挡弹/导航墙** → 本单 `NOT_RUN`（应由结构破坏套件承担）
- 窄路段预占策略、出生出口排队策略、断带车辆专门避让 → 未实现
- 河谷枢纽作为 8 槽正式战斗图的整局归因摘要 → `NOT_RUN`
- 10v10/16v16 压力与网络、真人 → `NOT_RUN`；性能 `HOLD_BY_USER`

## 7. 回滚

删除协调器与套件、回退地图文件中的四个新增函数即可；新增均为**追加式**，未改既有函数体（`route_purposes` 为本轮新增，未影响既有调用）。
