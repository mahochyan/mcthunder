# 第 3 阶段素材：**UI 可复现操作步骤**（仅写**已查证**的入口与动作 ✓）

> 原则 ✓：本文件**只写我核实过的名字**（文件/场景/套件 ✓）；**未核实的界面文字一律标注"待人工确认"** ✗（不虚构 ✗）。
> 对应 ✓：用户第 ⑤ 步"**走正常入口**"的完整流程 ✓；与 `run_app_flow_checks.gd` ✓、`run_app_match_cycle.gd` ✓ 所驱动的**同一套真实入口** ✓。

## 1. 启动（已核实 ✓）
| 方式 | 命令 |
|---|---|
| 推荐 ✓ | 双击 **`START_GAME.bat`** ✓（按脚本位置定位引擎与工程 ✓，缺引擎时给出明确提示 ✓ 不静默失败 ✓） |
| 中文入口 ✓ | 双击 **`启动主线试玩.bat`** ✓ |
| 本地双端 ✓ | **`START_LOCAL_SERVER.bat`** ✓ + **`START_LOCAL_CLIENT.bat`** ✓ |
| 引擎直启 ✓ | `<engine> --path <工程根>` ✓（应用入口场景 **`scenes/app.tscn`** ✓） |

## 2. 完整流程（**逐步** ✓；标注处需人工确认 ✓）
1. **进入应用** ✓ ⇒ `scenes/app.tscn` ✓ 由 `scripts/core/app_flow.gd` ✓（`AppFlow` ✓）驱动 ✓ —— 已由 `run_app_flow_checks.gd` ✓ 覆盖（车库 ✓ · 档案 ✓ · **有界等待的转场** ✓ · 缺资源可恢复 ✓）；
2. **科技树选车** ✓ ⇒ `scripts/content/tech_segment.gd` ✓（148 行 ✓），套件 `run_tech_segment_checks.gd` ✓；
3. **配弹 / 挂载** ✓ ⇒ `compatible_shells` ✓ 与挂载系统 ✓（脚本 25 ✓ / 测试 30 ✓）；
4. **进入对局** ✓ ⇒ 从**正常车库**开局 ✓ —— 与 `run_app_match_cycle.gd` ✓ **完全相同**的路径 ✓（该套件自述"**no injected outcome, damage, tickets or accelerated rule timers**" ✓）；
5. **交火** ✓ ⇒ 团队场景 `scenes/battle/team_range.tscn` ✓；地图 `scenes/maps/map_hill_village.tscn` ✓ · `map_industrial_edge.tscn` ✓；
6. **阵亡 / 再出击** ✓ ⇒ 重生系统 ✓（脚本 64 ✓ / 测试 67 ✓）；
7. **结算** ✓ ⇒ 等到 director 进入 `finished` ✓，原因 ∈ `{tickets, time_limit}` ✓（同 `run_app_match_cycle` ✓ 的判据 ✓）；
8. **下一局** ✓ ⇒ `run_app_match_cycle.gd` ✓ 逐图循环 ✓；
9. **重启保存** ✓ ⇒ 存档系统 ✓（脚本 5 ✓ / 测试 10 ✓）。

## 3. 独立可运行包（已核实路径 ✓）
1. **打包** ✓ ⇒ `tests/build_release.ps1` ✓（并生成 **`BUILD_MANIFEST.json`** ✓ —— `run_player_flow_checks.ps1` ✓ 会读它 ✓）；
2. **对导出包做玩家流程校验** ✓ ⇒
   `pwsh -File tests/run_player_flow_checks.ps1 -Executable <导出包路径> -SourceSha <40位提交号> [-Width 1280 -Height 720]` ✓
   （该脚本会**校验收据格式** ✓：`SourceSha` 必须是 40 位十六进制 ✓、分辨率在合法区间 ✓，否则**直接报错** ✓）；
3. **候选包** ✓ ⇒ `tests/build_team_candidate.ps1` ✓。

## 4. 与"两辆现代样车"的关系（诚实标注 ✓）
- 两车目前 **`admission=candidate_only`** ✓ 且 `VehicleCatalog.IDS` **只有 4 辆历史车** ✓ ⇒ **车库里不会出现 T-80B / 豹2A4** ✗（`run_modern_model_mount_checks` ✓ 明确断言这一点 ✓）；
- ⇒ 因此**第 ⑤ 步的两车流程**须待 ① 战斗包收口（**2 项几何修正已预验证** ✓ + **G–L 输入** ✓）与 ② **准入裁定** ✓ 之后才能端到端复现 ✓；
- ⇒ **在此之前**，"正常入口 + 完整流程"可在**现有 4 辆历史车**上复现 ✓（`run_app_flow_checks` ✓ 与 `run_app_match_cycle` ✓ 即为此路径 ✓）。

## 5. 未核实项（**不虚构** ✗，留待人工确认 ✓）
- 各界面**按钮/菜单的中文文字** ✗（本文件未核实其字面 ✓）；
- 车库内**具体点击顺序** ✗（以 `run_app_flow_checks.gd` ✓ 的驱动顺序为准 ✓，其源码即权威 ✓）。
