# WT-040-R1 交付与交接（Stage 4/5 阶段性）

> 本文只写**有观测证据**的结论；未达成、未验证、以及**我自己犯过并已更正的错误**都在文内如实标注。
> 生成时机：最终候选构建（`361dc8fa`）运行期间；其结论将在构建返回后追加。

## 1. 交付物清单

| 交付物 | 路径 | 状态 |
|---|---|---|
| 两车**生产配置包** | `configs/vehicles/engineering/ussr_t_80b.json` · `germ_leopard_2a4.json` | ✅ 已落盘并由生产加载器准入 |
| **模型来源注册** | `configs/vehicles/model_sources.json` | ✅ 两车登记为 `delivered` / `authored_asset` / `modern_bound-engine-v1` + **真实 sha256** |
| **工程弹种集** | `configs/shells/modern_engineering_loadouts.json` | ✅ 每车 APFSDS 主弹 + HEAT 副弹，全 `design`/`game_rule` |
| **准入检查** | `tests/check_engineering_admission.gd` | ✅ 逐项 2/2 |
| **运行检查** | `tests/run_engineering_runtime_checks.gd` | ✅ 44/0 |
| **受损检查** | `tests/run_engineering_damage_checks.gd` | ✅ 29/0 |
| **河谷整局记录** | `tests/record_river_ai_match.gd` + `logs/WT-040-R1/river_ai_match_44001.json` | ✅ 7/0（`RIVER_AI_MATCH_PASS`） |
| **内部开发包** | `backups/builds/031/<sha>/<stamp>/…` | ⏳ 最终构建运行中 |

## 2. 已达成（均有可观测证据）

### 2.1 校验器可信
- 三态审计：`complete_no_gaps` / `complete_with_gaps` / `incomplete`；`ok=false` + 空错误表 ⇒ **判为不完整**（不再当作通过）。
- 生产边界：`crew.placement` / 装甲区与事实 / **三环契约** / `assembly.caliber_mm` / face ≥3 点 / `definitions` 空集 —— 全部**点名拒绝**，**不默认、不造值**。
- 反例夹具 `run_modern_audit_integrity_checks.gd`：**21/0** 且 **`SCRIPT ERROR = 0`**。
- 探针退出正式验收（需显式 `--diag-probe`）。
- 构建登记**逐项失败身份匹配**（共享模块 `tests/candidate_register_match.ps1`，构建**点源同一份**）：
  - 反例①"一条旧失败＋一条新失败、总数不变" ⇒ **拒收**
  - 反例②"已登记失败＋脚本错误/超时/退出码未观测/日志缺失" ⇒ **拒收**
  - 负例测试 **15/15**；并已由**一次真实构建**证明其生效（`Candidate build refuses an UNREGISTERED failing suite: run_historical_checks`）。

### 2.2 两车真正加载
- 生产准入：`tier=production` · **`admission=validated`**（由管线自动提升）· `display_name_key` 规范名。
- 运行：真实 Actor 安装 → 两枚工程弹安装且台账守恒（38/42 发）→ **APFSDS 真实炮口发射，初速 1700.0 / 1650.0 m/s**，`long_rod` → **自然装填**（683 / 362 帧，无手清冷却）后膛内换 HEAT → 发射，`chemical` 且曲线**平坦** → `reset_vehicle` 恢复授权弹册。
- 受损：`DamageResolver.resolve`（用该弹自身 0 m 数据）⇒ `module_destroyed` ⇒ `apply_damage_delta` 接受、**同事件重放被拒** ⇒ `fire=false` 且 `reasons` 指名 `breech` ⇒ 乘员伤亡使 `alive_count` 下降 ⇒ **真实修理**（`VehicleRecovery.step` + `repair_requested`）12.0 s 仿真修到 `REPAIR_TARGET=50%` ⇒ `reset_vehicle` 重建全部模块/能力/乘员。

### 2.3 河谷真正完成比赛
`RIVER_AI_MATCH_PASS`（7/0），真实物理/AI/弹道/时钟/票数：**`victory`** · **338 s** · **票数 107:0** · **`fired=6`** · **两队均抵达地图自身目标**（队1 A/B/C，队2 B/C）· 界限有限 · 仅阵亡者脱管 · 健康在驾驶者最长停滞 **5 s**。

## 3. 未达成 / 未验证（**不掩盖**）

| 项 | 现状 | 原因 |
|---|---|---|
| 河谷上"**死亡 → 再出击**" | ❌ **本局未发生**（`destroyed=0` · `respawns=0`） | 对局由**占点掉票**在 338 s 判定胜负，无击杀 |
| 地图战斗准入 | ⛔ 仍 `combat_admitted=false`（`design_preview`） | 依用户裁定①：**不得只翻转 `combat_admitted`**；本记录自述 **"measurement, not an admission claim"** |
| 两条已登记失败 | ⚠️ 仍在（`run_industrial_battle_checks` 1 · `run_challenge_checks` 2） | 已登记在先，按裁定④允许随**内部开发包**交付；**不得**忽略整个失败套件 |
| 真人验收 / 许可 | ⛔ 未做 | 依裁定⑥：**真人验收不得代签**；许可不明资产隔离 |
| 性能专项 | ⛔ `HOLD_BY_USER` | 依裁定⑥ |
| 独立包内玩家流程 | ⏳ 待最终构建后核验 | `run_player_flow_checks.ps1` + 6 张实拍截图 |

## 4. 已知风险

1. **AABB 包络**：豹2 `hull_rings` 为**明确标注**的 AABB 包络（非扫描截面）；若参与实际受击，需按裁定②验证空隙/斜面/侧裙/炮塔下方不成为大块不可见装甲。
2. **设计值**：弹道/复合响应/装填/射界均为**项目规则**（`design`/`game_rule`），**非**历史性能。
3. **模型来源**：两车模型来自 `assets/vehicles/modern_bound/`（项目内、`authored_asset`）；`MuzzlePoint` 节点缺失（校验器不需要它）。
4. **构建**：`release_ready=false`，仅内部开发包；不得对外分发。

## 5. 回滚方式

- 生产配置包与注册表为**新增文件** ⇒ `git rm` 即可，**不影响**历史车。
- `VehicleCatalog.load_engineering()` 为**新增入口** ⇒ 不调用即回到原状；`load_all` 已复原为**历史专用**。
- 诊断/检查脚本（`record_river_ai_match.gd` 等）与套件追加均为**新增**，删除或从 `run_suite_checks.ps1` 移除即可。
- 工作分支 `work/continuation-20260913`；`main` 全程未动（`a1bac406`）。

## 6. 我自己犯过并已更正的错误（记录在案）

1. 修注释时**覆盖 `func build` 签名** ⇒ 编译失败（已复原）。
2. 批量补丁**误伤** gap 审计文件 **684 处** ⇒ 从**我自己上次提交**恢复（未丢弃用户内容）。
3. 正则留下多余 `]]` ⇒ 解析失败（已修）。
4. 新 reader **返回失效 Node 键** ⇒ 38 回归（已修：free 前算成纯值）。
5. **先算位置后改 part** ⇒ 位置与部件不匹配（数据自证：`-0.85 = 0.6 − 1.45`）。
6. 插入新函数时**吞掉 `_accumulate` 签名** ⇒ 11 处解析错误（已修）。
7. **未加保护的属性访问**导致进程滞留，且**两次误导我的归因**（先误作"导入争用"）⇒ 日志才是权威。
8. **把工程车并入 `load_all`** ⇒ 破坏历史车注册契约 ⇒ **由构建自身的回归抓到**（已改为独立 `load_engineering`）。
9. 登记守卫按**假设的字段形状**读证据 ⇒ 在真实数据上**空转**（真实文件**没有** `unexpected_errors` 字段）⇒ 改为**扫套件日志**。
10. `-File` 传数组参数踩坑**两次**；`RESULTS.json` 的**数组打印**误读**两次**；补丁脚本自身含中文被 ANSI 毁**两次**。

## 7. 交接要点

- **继续验证**：河谷"死亡→再出击"（延长对局或提高交战概率，**不得**强造命中）；AABB 包络的受击几何专项。
- **生产路径**：`VehicleCatalog()` → `load_all(defs)`（历史车）→ `load_engineering(defs)`（两车）⇒ `defs.resolve_vehicle(id)`。
- **工程弹册**：`configs/shells/modern_engineering_loadouts.json`；`assembly.shell` 必须等于弹集 `default`，`compatible_shells` 必须**精确等于**弹集 id。
- **模型绑定**：`ModelBindingValidator` 六角色 + `axes`（+Y 偏航 / +X 俯仰）+ `units`（含探针实测包络）+ `internal_attachments`（锚点取自模型）。
## 8. 构建结论（**实测**，`b829449a`）

| 项 | 值 |
|---|---|
| 命令 | `tests/build_release.ps1 -Candidate` |
| 退出码 | **0** ✓ |
| `PACKAGE_KIND` | `devcandidate` ✓ |
| `RELEASE_READY` | **false** ✓ |
| 已知失败 | **2**（`run_industrial_battle_checks` 1 · `run_challenge_checks` 2），逐条 detail 原文已入 manifest ✓ |
| 产物 | `…/20260916-184222-475/PixelArmor-1.0.0-rc.3-dev-Windows-x64-b829449a-devcandidate.zip`（132188 KB）· `package/BUILD_MANIFEST.json`（14 KB） |
| 清单绑定 | `source_sha=b829449a…` ✓ · `version=1.0.0-rc.3-dev` ✓ · `engine=4.7.2.stable.official.ed1daf0bf` ✓ · `template_sha256` ✓ |
| 回归 | `regression_checks=3195` · `regression_failed_checks=3` · suites **43** ✓ |
| 验证步（各自真实退出码 ✓） | fresh_import 0 · regression 1（已知）· export_release 0 · engine_notices 0 · independent_default_start 0 · **independent_content 0** · **independent_window 0** |
| 包内文件 | 7 个，含**中文名**文档（`开始游戏.txt` · `数据与恢复说明.md` · `素材与许可.md`）✓，每项带 bytes+sha256 ✓ |
| 声明 | `human=PENDING` ✓（真人未代签）· `public_release=false` ✓ |

**两处修复使此构建得以走通**：
1. `configs/player_tank_vehicle.tres` 原**只靠脚本默认值**提供四份 profile ⇒ 包内为 null ⇒ 进图/挑战失败；改为用 **Godot 自身 `ResourceSaver`** 写入四个**显式子资源** ⇒ `independent_content` 由 FAIL 转 **34/0** ✓。
2. `build_release.ps1` 含**中文字面量**，被 Windows PowerShell 按 ANSI 读取 ⇒ `Illegal characters in path`；中文名移入 **UTF-8 数据文件** `tests/package_doc_names.json` ⇒ 脚本**非 ASCII 行数 0** ✓，打包与**中文临时目录**均走通 ✓。

**登记表两次真实验证**：未登记失败的那次**被拒收** ✓；恰好两条已登记的那次**被接受**（且含**日志健康判据**）✓。

## 9. 包内玩家流程核验（**实测，未通过**）

```
45 checks, 7 failed        （实拍 8 张：00,01,02,03,04,06,07,08）
[FAIL] quitting other challenges cannot overwrite or invent personal bests
[FAIL] normal challenge player flow reached its final step
```
- 通过项：正常选择器进入 M36 路线并装载其**实际四发弹册** ✓ · 窗口实拍 ✓ · 点击前 UI 可见 ✓ · 实时对局确认后返回车库 ✓
- 未通过 ⇒ 缺 `05_real_shot_replay.png` · `09_battle_0/1.png` · `10_settled_0/1.png`（**必需截图**）⇒ 与"未达最终步"一致
- **结论**：**不得宣布玩家流程通过** ✗；构建自身的 `independent_content`/`independent_window` **未覆盖**该路径 ⇒ 记为**开放项**，下一步定位（**不提前宣布根因**）
- 证据：`logs/034/b829449a…/20260916-194312/`（`RESULTS.json` · `stdout.log` · 8 张 PNG）
## 10. 包内玩家流程失败的**归因更正与定位**（实测）

### 10.1 决定性对照（同一路径、同一代码、同一种子）
在**开发树**运行与包内**完全相同**的验证路径：
`Godot --path <dev> --resolution 1280x720 -- --verify-player-flow`

| 环境 | `contacts`（三发一致） | 失败数 |
|---|---|---|
| **包内** | `turret_wall_4` **penetrated** ✓ → `turret_wall_10` **stopped** ✗，`damage=[]` ✗ | **7** |
| **开发树** | **逐字节相同**（种子同为 2392720991/1024/1057） | **8** = 同样的 7 + `actual rendered Release player-flow verification`（开发树非 Release 导出 ⇒ **预期 +1**） |

⇒ **结论**：该缺陷**在开发树中同样成立** ⇒ **不是导出/打包问题** ✗。
⇒ **更正**：先前"包内特有、与 profile 同类"的推断 **被证伪**（本轮第 3 次基于证据的更正）。
⇒ 构建自身的 `independent_content` / `independent_window` **不覆盖**该路径 ⇒ 故**不得**宣布玩家流程通过。

### 10.2 已确立的机制（源码层）
- verifier 驾驶到姿位后瞄 `(0, 1.99, -20.28)` ⇒ 该射线上有**两块装甲壁**
- 命中点 `x` 由 **-0.868** 变到 **+0.895** ⇒ 弹丸**横穿炮塔内部**后在**另一侧壁**被拦停
- 结果 `damage=[]` ⇒ **内部模块/乘员未被命中** ⇒ 无归属死亡 ⇒ `flank_hits`/`kills` 空 ⇒ 挑战无法完成
- 而**树内夹具** `tests/run_challenge_checks.gd:133`（`real historical side shots complete flank objective`）**通过**，其瞄点为 `snapshot.part_world_transforms.turret*Vector3(0,0.08,0.7)`（与 verifier **不同**）
⇒ 即：**游戏本身能完成该挑战** ✓，是**这条被驾驶出来的瞄准线**不能 ✓

### 10.3 待判分支（**不提前宣布唯一根因**，按④继续）
- **(a) 测试侧**：verifier 的瞄准线/姿位不当（应改瞄点或改靠近方式）
- **(b) 产品侧**：该点位存在**非预期**的第二道壁，或炮塔内部在 y≈1.99 处**没有可命中的内构**
判决方法：取该靶标在该点位**逐层 patch 与内构盒**的实测清单，与"通过瞄点"作同靶标对照。
- **不做**：不放宽判据 ✗ · 不注入伤害以造出成功 ✗ · 不改战斗数值掩盖 ✗
