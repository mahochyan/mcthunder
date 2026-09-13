# 测试入口清单与本地门禁接口（WT-001-R2）

- 依据：`02_首轮10张执行单.md` §02「核心快验/相关/整合/导出测试列表」；`03` WT-001 行 31（最小架构索引与测试入口清单）
- 无 CI 的短期处理 = **准备本地门禁接口**；云 CI 接入不在本单范围，也不推送。

## 1. 统一命令约定（实测）

```
tools/godot/Godot_v4.7.2-stable_win64_console.exe \
  --path . --fixed-fps 60 [--headless | --resolution 1280x720] \
  -s res://tests/<suite>.gd --log-file <log> -- <suite-args>
```
来源：`logs/WT032-navigation/RESULTS.json` 的 `command` 字段（其中 `Set process APPDATA to logs/<order>/<appdata>` 表示每次运行都使用隔离的用户数据目录，避免污染真实进度）。单套最小形式见 `README.md:46`。

## 2. 四层入口

### 2.1 核心快验（headless，无窗口，秒级~分钟级）
共 **131** 个 `tests/run_*_checks.gd`。以下为实测体量最小的一批（文件越小通常越聚焦，适合做提交前快验）：

| 入口 | 关注的既有能力 |
|---|---|
| `run_diagnostic_budget_checks` | 诊断/预算 |
| `run_industrial_obstruction_checks` | 工业图遮挡 |
| `run_long_rod_damage_checks` | 长杆毁伤 |
| `run_query_metrics_checks` | 查询指标 |
| `run_save_lock_checks` | 存档锁（029 项） |
| `run_menu_fire_handoff_checks` | 菜单/开火交接 |
| `run_model_showroom_checks` | 模型展厅 |
| `run_composite_binding_checks` | 复合装甲绑定 |
| `run_hull_frame_checks` | HullFrame |
| `run_turret_tick_checks` | 炮塔固定步 |
| `run_multi_objective_checks` | 三点占点规则（WT-032） |
| `run_simulation_phase_checks` | 模拟阶段顺序 |
| `run_river_navigation_checks` | 河谷道路可达（22 项，`--river-navigation-check`） |
| `run_river_driving_checks` | 河谷驾驶（34 项，`--river-driving-check`） |

### 2.2 相关（按本单/模块选择）
按 `ARCHITECTURE_RESPONSIBILITY_INDEX.md` 的模块→套件对应关系挑选；例：改 `drive/` 跑 `run_drive_checks` + `run_terrain_*`；改 `battle/` 跑 `run_team_*` + `run_multi_objective_checks`；改 `projectiles/` 跑 `run_projectile_checks` + `run_long_rod_damage_checks` + `run_spall_content_checks`。

### 2.3 整合（多场景/多进程/多局）
| 入口 | 类型 |
|---|---|
| `tests/run_match_batch_checks.ps1` / `run_match_batch_checks.gd` | 多局批测（固定种子） |
| `tests/run_player_flow_checks.ps1` | 玩家流程（新档→一局→存档） |
| `tests/run_network_slice.ps1`、`run_network_view.ps1` | 本地权威服务器 + 客户端多进程 |
| `tests/run_suite_checks.ps1` | **全量套件运行器**（`-Order <编号> -TimeoutSeconds <秒>`，记录源码 SHA/命令/stdout/stderr/退出码/超时/错误扫描） |

### 2.4 窗口与正常输入（headless 会快失败，必须真实窗口）
共 **27** 个 `run_*demo*.gd` / `*player*.gd` 入口，例如 `run_hud_player_checks`、`run_garage_player_checks`、`run_village_player_checks`、`run_industrial_player_checks`、`run_optics_player_checks`、`run_team_player_checks`、`run_river_route_ui_checks`（14 项，`--river-route-ui-check --shot-dir …`）。
**判读规则**：headless 下这些入口属于"环境限定失败"，不得记为代码失败；真实窗口运行才可写 PASS。

### 2.5 导出/打包
| 入口 | 说明 |
|---|---|
| `export_presets.cfg` | 3 个预设：`Village Resource Check`、`Windows Team Slice`、`Windows Release`（**本单不改**） |
| `addons/bound_model_export/{plugin.gd,source_export.gd}` | 模型绑定源导出插件（解决原始 GLB 缺失于导出包的问题） |
| `tests/package_candidate.ps1`、`build_release.ps1`、`build_team_candidate.ps1`、`install_export_templates.ps1` | 候选打包与发布构建脚本 |

## 3. 本地门禁接口（建议的最小实现，本单只定义不接管 CI）

```
# 提交前快验（示例，后续按模块裁剪）
pwsh -File tests/run_suite_checks.ps1 -Order <当前单编号> -TimeoutSeconds 600
```
门禁判读规则（沿用仓库既有约定，`README.md:44`）：
1. 退出码非 0 即失败；
2. **任何 ERROR / SCRIPT ERROR 即使退出 0 也判失败**（既有例外：布局套件三条指定负例）；
3. 停止/超时/未拿到完整结果 = `INCOMPLETE`，不是 `PASS`；
4. 分批 PASS 不得冒充"最终 SHA 全量 PASS"。

## 4. 未运行与限制（如实登记）

| 项 | 状态 |
|---|---|
| 全量 39/62 套回归在当前分支重跑 | `NOT_RUN`（本单只整理入口，不重跑历史长测） |
| 性能/容量（003B、036B） | `HOLD_BY_USER`，禁止采样 |
| 真人体验 | `NOT_RUN`（不代签） |
| 云 CI | 未接入（无 `.github/workflows`、无 `.gitlab-ci.yml`） |
