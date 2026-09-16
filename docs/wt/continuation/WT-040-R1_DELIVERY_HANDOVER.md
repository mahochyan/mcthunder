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
## 11. 玩家流程缺陷的**定位、修复与包内结果**（实测）

### 11.1 定位链（每一步都被测量，且**推翻了我 6 次推断**）
| # | 我的推断 | 实测结果 | 结论 |
|---|---|---|---|
| 1 | `outcome={}` 说明未登记穿透 | `outcome` 是**对局结果**字段 | **推翻** ✓ |
| 2 | 未发生穿透 | `contacts` 显示 `turret_wall_4` **penetrated** | **推翻** ✓ |
| 3 | 包内特有（同 profile 类） | **开发树同样失败**（同种子、逐字节相同） | **推翻** ✓ |
| 4 | 硬编码绝对瞄点过时 | 该点**就是**靶标炮塔系的 `(0,0.08,0.7)` | **推翻** ✓ |
| 5 | 等待相机 intent 收敛即可 | intent 是**首个命中面** ⇒ 40 轮后仍差 **0.90 m** | **推翻** ✓ |
| 6 | 换射击位姿即可 | 移动 2 m ⇒ 残余仅变 **0.008 m** | **推翻** ✓ |

**成立机制**：相机 `intent_point()` = 射线**首个命中面** ⇒ 瞄墙后点时炮管被顶高 **~0.13 m**（> `ammo_ready` 半高 0.06）⇒ 穿近壁后被**远壁**拦停 ⇒ `damage=[]` ⇒ 无归属死亡 ⇒ 无最佳成绩。
**对照**：树内夹具用 `VehicleCommand.has_aim_point` **直接给炮塔下指令** ⇒ 一发 `penetrated` + `damage=[["ammo_ready", true]]` ⇒ 通过。

### 11.2 修复（**测试侧、有界、不碰任何游戏数值**）
`scripts/diagnostics/player_flow_verifier.gd` 的 `aim_at`：以**炮管线实测偏差**为反馈平移相机目标 ✓（最多 60 轮 × 20 帧 ✓），判据为**几何垂距 ≤ 0.03 m** ✓，仍为**真实鼠标**射击 ✓。
**树内实测**：收敛残余 **0.0080 m**（第 19 轮）✓ ⇒ 单接触穿透 + `ammo_ready` 伤害 ✓ ⇒ 挑战通过 ✓ 星数 3 ✓ ⇒ **45/8 → 46/2** ✓（仅剩"非 Release"与级联标记 ✓）。

### 11.3 含修复的交付包（`ad6620f0`）
| 项 | 值 |
|---|---|
| 包 | `…-Windows-x64-ad6620f0-devcandidate.zip`（132189 KB） |
| 类型/就绪 | `PACKAGE_KIND=devcandidate` · **`RELEASE_READY=False`** |
| 已知失败 | **2**（`run_industrial_battle_checks` 1 · `run_challenge_checks` 2），逐条 detail 入 manifest |
| 回归 | **43 套件 · 3195 项 · 失败 3**（= 两条已登记的内部失败数） |
| 验证步 | 导出 0 · `engine_notices` 0 · `independent_default_start` 0 · **`independent_content` 34/0** · **`independent_window` 35/0** |
| 绑定 | `source_sha=ad6620f0` · `human=PENDING` · `public_release=false` |
| 包内文件 | 7 个（含三个**中文名**文档），逐项 bytes + sha256 |

### 11.4 包内玩家流程：**52 项 · 4 失败**（原 45 项 · 7 失败）
- **已通过** ✓：侧翼挑战完成 · 归属死亡 · 最佳成绩保存 · 存储重载 · 任务选择显示 · **退其他挑战不覆盖** · **达到最终步** · `05_real_shot_replay` 已实拍
- **仍失败** ✗：`normal UI control is visible before click` ×4 · `normal garage button enters complete map 0`
- **缺截图** ✗：`09_battle_0/1.png` · `10_settled_0/1.png`
- **结论**：**不得宣布包内玩家流程通过** ✗；失败点已从侧翼链**后移**到后续的 M36 路线/入库步骤 ⇒ 记为**开放项**，下一轮按同一方法（测量 + 对照，**不**猜测）定位

## 12. 2026-09-17 追加裁定（A/B/C/D）执行结果（**均有实测证据**）

### 12.1 A —— 入口错位修复并关闭 ✓
- **做法**：验证器改走**当前真实界面**（`tabs[1]` 车辆配装页选车 → `tabs[0]` 作战页选模式/地图 → 点击 `frontend.deploy`）；**不**强行显示旧界面、**不**直接切页、**不** emit 出战信号；隐藏/禁用/不可达控件**立即停止点击**（`window_input_driver.click` 的可见性与启用断言 ✓）；控件一律用**稳定引用**，不做运行期名称或全树文本搜索。
- **实测**：树内 **96 项 · 0 失败** ✓ · 打印 `PLAYER_FLOW_CHECKS_PASS` ✓ · 缺图清单**为空** ✓ · **13 张实拍** ✓。
- **状态**：**已关闭** ✓（提交 `1e37e5f0`）。

### 12.2 B —— 工程车贯通同一条受控路径 ✓
- **契约**：`load_all` **保持历史专用** ✓（其"恰为四包"断言仍被独立强制执行 ✓）；工程车经**显式** `load_engineering` 准入 ✓。
- **接线（由直接检查证明，非推断）**：`tests/check_engineering_wiring.gd` 逐辆核对 **六项** —— 请求 id ✓ · 实际 `definition.id` ✓ · 武器/弹种属**本车** ✓ · 布局 id = 自身定义 ✓ · 模型绑定已注册 ✓ · 移动碰撞尺寸 = 自身（**非**训练盒 ✓）；另断 **未知 id 明确拒绝**（空 id ✓）与**训练车保留自身训练弹** ✓。
- **实测**：`ENGINEERING_WIRING_PASS` · **141 项 · 0 失败** ✓✓ · `preview_only` 警告 **0** ✓。
- **该检查抓到的三处真实缺陷**（每一处都由"请求↔实际"对照定位）：①`ballistics_range` 的载入被"只认历史车"的闸门挡住 ⇒ 工程车**无法初生**；②就绪闸用**新建空 catalog** ⇒ `admitted` 退回历史 id ⇒ **AI 槽全取 M4A3**；③主判定误用 `training` 模式 ⇒ 每个工程车请求被判 `preview_only` 再由兜底救回（结果正确但语义错位、噪声满屏）。
- **包内回归（由包内核验抓出，重要）**：工程车是**候选**，其**模型工件不随包发布** ⇒ `load_engineering` **致命化**导致**包内整场起不来**（车库地图 0 · 三个挑战 · 教学共 **5 项 FAIL**）⇒ 已修为：**历史准入仍强制且致命** ✓；**工程准入改为响亮 `push_warning` 且非致命** ✓ ⇒ 包内工程车**不可用**（符合候选定位 ✓），**树内照常可用** ✓，**门槛未放宽** ✓。

### 12.3 C —— 五项分列 + 现代两车记录 ✓
- **记录分列**（`tests/record_river_ai_match.gd`）：`fired_slots`（**槽位数**，附 note ✓）· `shots_total` · `contacts_total` · `damage_events` · `deaths_total`；`respawns` 标 **`WITHDRAWN`** 且**打印亦为 WITHDRAWN**（不再把旧计数的 0 当有效测量 ✓）。
- **历史局实测**：`victory` · 338 s · 票 107:0 · **fired_slots=6（槽位）· shots_total=16 · contacts=25 · damage=6 · deaths=0** ✓ · `RIVER_AI_MATCH_PASS` 7/0 ✓ · 两队均抵达地图自身目标 ✓。
- **现代两车记录**（`--vehicle ussr_t_80b --opposing germ_leopard_2a4`，历史默认不变 ✓）：`defeat` · 370 s · **contacts=19 · damage=18** ✓ · 8/8 槽位均为工程车 ✓（由接线检查证）；记录新增 `scenario` 标注（**内部工程入口**、`combat_admitted=false`、**仅队伍编成、不改规则** ✓）。
- **同一条记录测出的限制（如实登记）**：`advance_limitation` —— 8 个 actor 中 5 个以 8.0 m/s 正常行驶 ✓，而 **A2 全程 `to_goal=696`、`driver_reason=path_ready`、`spd=0.0`** ✗、A3 `spd=0.1` ✗（**有合法路径却不前进**）；分类指标进一步证明**既不是队友排队**（`queued peak 0 s`）**也不是无路**（`no_path peak 0 s`）⇒ **判定项保持 FAILING** ✗（**不改**判据 ✓）。

### 12.4 D —— 实弹死亡与正常 UI 再出击 ✓（**专项 / 自然局分开登记**）
- **专项夹具**：`tests/check_live_fire_respawn.gd`（**明确标注 SPECIAL FIXTURE** ✓）· 窗口化运行 ✓（真实鼠标事件）· 看门狗 ✓ · 实拍 ✓。
- **实测：`LIVE_FIRE_RESPAWN_PASS` · 16 项 · 0 失败** ✓✓
  - **段 1（实弹链条，记录）**：真实团队局 ✓ · **3 秒倒计时完成 → `playing`** ✓ · `enemy wrecks=**2**` ✓（真实弹丸 → 伤害 → 死亡 → 残骸 ✓）· `A travelled=44 m` ✓ · 比赛 291 s 由票数终止 ✓。
  - **段 2（正常 UI 再出击，判定）**：全新真实局 ✓ → `playing` ✓ → **游戏内 `abandon_vehicle()` ⇒ 真实阵亡** ✓ → **真实 `waiting_panel`** ✓ → **真实等待期 8 s 满** ✓ → **真实 `respawn_button` 可见可点** ✓ → **【真实鼠标点击】⇒ 新生命 `life 11 → 19`** ✓✓ → 存活 ✓ → **保持工程车 `ussr_t_80b`** ✓ → 面板收起 ✓ → **驱动自身可见/启用断言全过** ✓。
  - **死亡来源在输出中明写** ✓：段 2 的死亡来自**游戏自身"放弃"命令**，**不是实弹**；实弹链条由**段 1 的 2 个残骸**单独举证 ✓✓（两类证据**各自独立、各自真实**，**未**调 `request_respawn` ✗ · **未** emit 信号 ✗）。
- **河谷侧限制（自然局）**：正式规则下 291 s 内玩家槽**未被实弹击毁** ✗（A 起步 38 m 后 **284 s 仅 19 m** ✗ ⇒ 与 12.3 的通行限制同源）⇒ **不改**票池/占领/伤害/装填/终止 ✓。

### 12.5 候选失败登记（**窄签名、附证据、仅候选**）✓
- `run_checks` 的 `R3-A` 慢收敛：**约四次一遇**，数值**逐字节复现**（`max_err=58.553°` · `final_err=10.987°` · `first_cross=-1`），且在 **300 帧与 900 帧**两种观测窗下**完全相同** ⇒ 属**产品侧行为**，**非**帧噪声、**非**窗口不足 ⇒ 登记签名 `R3-A.*58\.55`（**不**锚在套件、**不**锚在 `R3-A` 泛称 ✓）；**任何额外或不同的失败仍会拦住构建** ✓；**阈值逐字未动** ✓（0.5° · 保持 1 秒 ✓）。
- 匹配器自测 **15/15 负例全过** ✓（含"旧失败+新失败总数不变"✗、"伴随脚本错误/超时/退出码未知"✗、"空集合冒充 1 项"✗ 等反例 ✓）。

### 12.6 仍未完成 / 未验证（**不掩盖**）
- **包内核验的独立内容步骤**：`ad6620f0` 版曾 **34/0** ✓；本轮因**我引入的工程准入致命化**一度在 `independent_content` 失败 ✗（**包内核验正确地拦下了它** ✓）⇒ 已修为非致命 ✓ ⇒ **重建中，结论待本轮构建输出** ✓。
- **通行/推进限制** ✗（12.3/12.4 同一现象）：**未修**，**已登记**（**不**改规则、**不**改数值以掩盖 ✓）。
- **真人验收**：`human=PENDING` ✓（**不代签** ✓）· **公开发布**：`public_release=false` ✓ · **性能**：`HOLD_BY_USER` ✓。
- **旧包保留**：`3e6c3523` 等**全部不覆盖** ✓。

### 12.7 方法学补记（本轮我犯过并已更正的错误，**记录在案**）
- PowerShell here-string 形式错误 ×3（整篇解析失败 ⇒ **零副作用** ✓）⇒ 改为**独立 here-string + `'@` 独占一行** ✓，其后**改代码一律用 `edit`/`write` 工具**（**不再**用 PS 拼字符串 ✓）。
- 夹具三连错（**直接写车体状态** ✗ · **用不存在的动作名 `forward`** ✗（引擎自己给出 `move_forward` ✓）· **属性归属错**（`cam_rig` 在车辆上而非场景 ✓））⇒ 纪律：**证据必须走生产输入路径；属性归属以源码为准** ✓。
- 归因被自己的指标**三次**推翻（"目标点排队" ✗ → "途中排队" ✗ → **"有合法路径却不前进"** ✓）⇒ 纪律：**先读到"在等什么"，再定性** ✓。
