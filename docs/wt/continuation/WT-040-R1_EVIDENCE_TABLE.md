# 第 4 阶段素材：**验证证据表**（每条数字 → 可复现出处 ✓）

> 用途 ✓：任何结论都能被**独立复核** ✓；本表在**对账中发现并更正**了我先前两处表述失准 ✗（已标注 ✓）。

## 1. 缺口轨迹（**出处**：`logs/WT-040-R1/package-gap-audit*.log` ✓）
| 阶段 | 日志 | T-80B | 豹2A4 |
|---|---|---|---|
| 初始（shape 门） | `package-gap-audit2.log` | **24** ✓ | **25** ✓ |
| 加事实键 | `audit3` | 23 | 24 |
| 修类别错误（runtime 进组件 ✓） | `audit4` | 20 | 21 |
| 武器/弹药（事实+组件 ✓） | `audit5` | 17 | 18 |
| 修 assembly 接线 ✓ | `audit6` | 14 | 15 |
| `crew.roles` ✓ | `audit7` | 13 | 14 |
| `variant` + `acceleration` ✓ | `audit8/9` | 11 | 12 |
| `crew` 组件 ✓ | `audit10` | 10 | 11 |
| `modules`（弹架配平 ✓） | `audit11` | **9** ✓ | **10** ✓ |
| 内容层（探针 ✓） | `audit14` | BEYOND=**4** ✓ | — |
| 修证据记录后 ✓ | `audit15` | BEYOND=**1** ✓ | — |

**更正** ✗：先前我把 9/10 与 1/1 的出处写成 `layer-probe10.log` ✗ —— 实为上述 `package-gap-audit*.log` ✓。

## 2. 各层校验（**出处**：`logs/WT-040-R1/layer-probe10.log` ✓）
| 层 | T-80B | 豹2A4 |
|---|---|---|
| `geometry.build` | ok ✓ parts=6 ✓ patches=56 ✓ | ok ✓ parts=6 ✓ patches=49 ✓ |
| `LayoutValidator.errors` | **4** ✓ | **7** ✓ |
| `VehicleShellCatalog` | `no admitted shell set` ✗（设计/资料 ✓） | 同类 ✓ |
| **`definitions`（车/炮/弹）** | **0 / 0 / 0** ✓✓ | **0 / 0 / 0** ✓✓ |

## 3. 其它证据 ✓
| 结论 | 出处 |
|---|---|
| `geometry` 自校验 ****50/0**** ✓ | `pipeline-geometry_check.log` ✓ |
| `run_modern_model_mount_checks` **41/0** ✓（回归已关闭 ✓） | `mount-recheck2.log` ✓ |
| `run_track_damage_checks` **单独 3s 通过** ✓ ⇒ 门禁停滞＝**并发** ✗ | `track-alone.log` ✓ |
| 流水线 **9 步全绿** ✓ | `pipeline-*.log` ✓ |

## 4. 改动范围对账（**更正后的精确版** ✓）
| 项 | 真实增删 | 判定 |
|---|---|---|
| `scripts/content/modern_model_mount_adapter.gd` | **0** ✓ | **逐字节等于基线** ✓ |
| `scripts/maps/river_junction_navigation.gd` | **0** ✓ | **逐字节等于基线** ✓ |
| `scripts/content/role_mapping_audit.gd` | **8** ✓ | **唯一**产品代码改动 ✓＝有意的 `GUN_MESH_HINTS` 修正 ✓（已回归 ✓） |
| `assets/vehicles/adapters/*`（8 个二进制 ✓） | — | **按设计** ✓：T-80B 新建 ✓ · 5 辆无炮车移除虚假原点标记 ✓ |

**更正** ✗：先前笼统称"产品代码处于基线" ✗ —— 精确表述见上表 ✓（1 处 8 行修正 + 产物按设计更新 ✓）。

---

## 5. **数据完整性验证**：armor 映射**逐条回查档案原文** ✓（独立核对 ✓）
方法 ✓：读 `modern_armor_draft.json` 的 17 个 zone ✓，按其 `location` 中的**行号与节点名** ✓，
回到 `assets/reference_data/candidates/<id>.json` 的 `armor_groups[].nodes[]` ✓ **重新取出**该行的
`armorThickness` ✓ 与 `id` ✓，与草案值逐条比对 ✓（**不信任我自己的转录** ✗）。

| 车 | 一致 | 不一致 |
|---|---|---|
| `ussr_t_80b` | **17** ✓ | **0** ✓ |
| `germ_leopard_2a4` | **17** ✓ | **0** ✓ |

⇒ 我**手写**的两份 17-zone 映射表**无转录错误** ✓✓：来源节点 ✓ · 行号 ✓ · 厚度值 ✓ **均与档案原文吻合** ✓。
（该检查正是为捕捉"**看似合理但实则错**"的数字而设 ✓ —— 本次结果为零错误 ✓。）

---

## 6. **第二项完整性验证**：facts **逐条回查档案候选层** ✓ —— 并**抓到一个真实问题** ✓✓
方法 ✓：读 `modern_facts_draft.json` 每条事实的 `location` 行号 ✓ → 回到档案 `fields[]` 取该行的 `candidate_value` ✓ → 比对 ✓。

| 标记 | 判定 |
|---|---|
| `mobility.engine` `power_hp:1100.0` vs `1100` ✓ | **仅 int/float 表示差异** ✗ ⇒ 非数据错误 ✓ |
| `forward_speed_mps` `20.8333333333333` vs `20.833333333333336` ✓ | **浮点精度损失（~1e-14）** ✓ ⇒ 可忽略但**如实记录** ✓ |
| **`runtime.acceleration` `4.0` vs 档案 L23 = 空** ✗✗ | **真实问题** ✓✓：档案自己的键名是 **`drive.acceleration_unspecified_units`** ✗ ⇒ **档案未标明单位** ✗ ⇒ 我取 **m/s²** 属**假设** ✗ ⇒ **已写入事实 `location` 与 `notes`** ✓ |
| `crew.roles` · `forward_max_speed` 跳过 ✓ | 属**派生**事实 ✓（非转录 ✓） |
| 其余（`hull_turn_speed` 等 ✓） | **每车 3 条精确一致** ✓ |

### 处理 ✓
在生成器中把该**假设显式化** ✓：`... the dossier's own key is drive.acceleration_unspecified_units (empty), so the unit is NOT stated; read as m/s^2 by assumption` ✓
（**不隐藏假设** ✗ —— 这正是本检查存在的意义 ✓。）

---

## 7. **第三项完整性验证**：crew / assembly / modules 回查档案 ✓ —— **全部一致** ✓✓
| 检查 | 结果 |
|---|---|
| **`crew.roles`** vs 档案 `crew_roster[].roles`（**手写扁平化** ⇒ 必须回查 ✓） | T-80B `tank_gunner,driver,commander` ✓ **一致**；豹2 `tank_gunner,driver,loader,commander` ✓ **一致** |
| **`assembly`** vs 档案 `weapon_references[primary].source_weapon_id` ✓ · `shell.reference.bulletName` ✓ · `shell.caliber_mm` ✓ · `primary.capacity` ✓ | T-80B `125mm_2A46_2_user_cannon` ✓ `125mm_3bk_18m` ✓ **125.0** ✓ **38.0** ✓；豹2 `120mm_Rheinmetall_L44_user_cannon` ✓ `120mm_dm12` ✓ **120.0** ✓ **42.0** ✓ |
| **`modules` 弹架之和** vs 草案声明（**独立复核**校验器已验的规则 ✓） | **38 = 38** ✓ · **42 = 42** ✓ |

### 数据层的验证总览（**三重** ✓）
1. **armor 17 zone** ⇒ 逐条回查档案原文 ✓（**17/17 ×2 零不一致** ✓）；
2. **facts** ⇒ 逐条回查候选层 ✓（每车 3 条精确 ✓；2 条表示差异无碍 ✓；**抓到并显式化 1 个隐藏假设** ✓：加速单位 ✓）；
3. **crew / assembly / modules** ⇒ 本次全部一致 ✓✓。
⇒ **草案数据层不含未声明的假设或转录错误** ✓（**除已显式标注的那一处单位假设** ✓）。

---

## 8. **独立交叉验证**：`hull_rings` vs 校验器的车体 AABB ✓（并发现一处已知偏差 ✓）
两条**不同**测量路径 ✓：我的**分带顶点扫描**（生成器 ✓）对比校验器的**网格 AABB**（`check_modern_geometry` ✓，且经 adapter↔source 双向一致 ✓）。

| 量 | 草案环 | 校验器 AABB | 判定 |
|---|---|---|---|
| **y 范围** | `−0.258 → 1.857` | `−0.2576 → 1.8573` | **一致到 0.4 mm** ✓✓ |
| **z 最小（车头）** | `−6.489` | `−6.4890` | **一致** ✓✓ |
| **z 最大（车尾）** | `3.214` | **`3.5185`** | **差 0.30 m** ✗ |

### 诚实解读 ✓
- **y 与车头 z 亚毫米吻合** ✓ ⇒ **分带扫描与 AABB 自洽** ✓（方法可信 ✓）；
- **车尾差 0.30 m** ✗ ⇒ 三个截面高度（地板/中线/车顶 ✓）的 z 跨度**未覆盖**车体**真实最尾点** ✓（最尾点可能落在**截面之间**的其它高度 ✓ ⇒ **不必然是缺陷** ✓，但**确为偏差** ✓）；
- **影响** ✓：校验器的包络长度取"各环 z 跨度最大值" ✓ ⇒ 本条给出约 **3 %** 长度偏差 ✓ ⇒ **远在 ≤16 % 容差内** ✓ ⇒ **可接受且已登记** ✓；
- **未采取** ✗：**不**为消除这 0.3 m 而改分带策略（那会牵动已验证的几何 ✓）；**如实记录** ✓，留给作者复核 ✓。

---

## 9. ⚠️ **新发现**：`run_historical_road_checks` 会**卡在同一个 tick** ✗（证据确凿 ✓）
观察时段 ✓：`gate-solo-20260915-182541` 运行中（HEAD=`99afbe5c` ✓）。

| 观测 | 值 |
|---|---|
| 日志大小 | **2.81 MB** ✗，且 **15 秒内增长 353,519 B** ✗✗（≈ 23 KB/s ✓） |
| 行数与重复 | **49,681 行** ✓；同一行出现 **6,759 次** ✗（`[cmd-trace] submit entity=ROAD throttle=1.00 fire=false` ✓） |
| 尾部内容 | 反复 **`tick=73`** ✗（`consume/execute/submit` 三段循环 ✓，throttle 缓慢 1.00 → 0.34 ✓） |
| 判定 | **模拟未推进过 `tick=73`** ✗ ⇒ **在单 tick 内打转** ✓（**反馈循环** ✓） |

### 影响与处置 ✓
- 该套件**不是"跑得久"** ✗，而是**卡住** ✓ ⇒ 它解释了门禁"看起来很慢"的一部分 ✓；
- runner 自带 **`-TimeoutSeconds 1500`**（25 分钟 ✓）⇒ **终会被杀** ✓ 并继续后续套件 ✓；
- **本会话未对其做任何改动** ✗；**不去手动杀进程** ✗（会破坏本次运行 ✓）⇒ **等 runner 超时** ✓；
- **未做定论** ✗：**未**断定它是否为**既存问题** ✓ —— 判定需**单独复跑** ✓（3–5 分钟即知 ✓），待引擎空闲后执行 ✓；
- 另记 ✓：`[cmd-trace]` 为**调试追踪** ✗，产出 **≈23 KB/s** ✗ ⇒ 建议核查其**默认开关** ✓（不擅自改 ✗）。

---

## 10. **更正**第 9 节 ✗→✓：`run_historical_road_checks` **并未卡死，它通过了** ✓
| 事实 | 值 |
|---|---|
| 该套件最终结果 | **`run_historical_road_checks: checks=33 exit= passed=True unexpected_errors=0`** ✓✓ |
| 同批通过 | `run_blender_asset_checks: checks=16` ✓ · `run_shell_checks: checks=193` ✓ |
| 门禁进度 | **119 / 127** ✓ · **0 failed** ✓ |

### 更正内容 ✓
第 9 节我把 `tick=73` 的刷屏**解读为"卡在单 tick 的反馈循环"** ✗ —— **该解读错误** ✗✓：
该套件**运行完毕后通过** ✓ ⇒ 那是**模拟阶段内的海量调试追踪** ✓，**不是死锁** ✓。

### 仍然成立的**量化观测** ✓（性质由"故障"改为"冗余" ✓）
- 日志 **2.81 MB** ✓ · **49,681 行** ✓ · 单行重复 **6,759 次** ✓ · 增速 **≈23 KB/s** ✓；
- ⇒ 属**输出冗余** ✓：`[cmd-trace]`（调试追踪 ✓）在**通过的套件**中产出 ~23 KB/s ✓ ⇒ 建议核查其**默认开关** ✓（**不擅自改** ✗）。

### 教训（**本会话第二次同类** ✓）
**"看起来卡住" ≠ 卡住** ✗ —— 判定必须看**最终结果**或**进程 CPU 累积** ✓，**不能**只看日志形态 ✓；
（前一次同类 ✓：据 `LastWriteTime` 判"门禁停滞" ✗，实为**长套件** ✓。）

---

## 11. [`cmd-trace] 冗余输出] **已闭环** ✓（只读追查 ✓，结论：**按需、由套件自选、需改 ✗**）
| 证据 | 内容 |
|---|---|
| `scripts/vehicle_actor.gd:34` | **`var debug_command_trace := false`** ✓，注释："**003-R2：提交/消费/执行三处调试记录（默认关）**" ✓✓ |
| 三处产出 | 均受 `if ok and debug_command_trace …` / `if debug_command_trace:` 保护 ✓ |
| 谁开启 | **套件自身** ✓：`tests/run_historical_road_checks.gd:33` ⇒ `actor.debug_command_trace = id == "us_m26_m3_1945"` ✓（**仅一辆车** ✓） |

⇒ **判定** ✓：该 **≈23 KB/s** 输出是**该套件有意开启的诊断追踪** ✓（单车辆范围 ✓）⇒ **非产品缺陷** ✗ · **非默认行为** ✗ ⇒ **无需改动** ✗。
⇒ 若未来要收敛日志体积 ✓，**应由该套件自行决定** ✓（例如仅在失败时保留 ✓）—— **本轮不改** ✗（属测试代码 ✓，且与当前目标无关 ✗）。

---

## 12. 🏁 **官方门禁：干净运行 = 基线（126 PASS / 2 FAIL）** ✓✓✓
三次运行**全部跑完** ✓（各约 20–90 分钟 ✓，均未被我干扰 ✓）：

| 运行（HEAD） | 完成 | 通过 | 失败 | 红项 |
|---|---|---|---|---|
| `gate-final`（`d95cbc36`） | 128 | 125 | **3** | **`run_modern_model_mount_checks`** ✗（**我的回归，当时未回退**）+ `industrial_battle` + `challenge` |
| `gate-verdict`（`c032345a`） | 128 | 125 | 3 | **`run_world_vehicle_phase_checks: checks=0`** ✗（**0 检查的抖动**）+ 同两项 |
| **`gate-solo`（`99afbe5c`，最干净）** | **128** | **126** ✓ | **2** ✓ | **`run_industrial_battle_checks`** ✓ + **`run_challenge_checks`** ✓ |

### 结论 ✓
1. **干净运行精确复现基线** ✓✓：**126 PASS / 2 FAIL** ✓，且两红**正是已登记的非回归** ✓
   （`industrial_battle` 到点红 ✓ 与 `challenge` **140 项**夹具边界 ✓ —— 您已裁定 **B4** ✓）；
2. **我的回归由门禁自身确认已修复** ✓✓：`run_modern_model_mount_checks` ✗ **仅在回退前那次**出现 ✓，后两次**均无** ✓；
3. **有效总数 128** ✓：runner 在含 `run_art_checks` 时**追加** `run_menu_fire_handoff_checks` ✓（其源码如此 ✓）；
4. **新增已知抖动** ✓：`run_world_vehicle_phase_checks: checks=0` ✗（**0 检查却判失败** ✓）出现在**中间那次** ✓、**干净那次未现** ✓ ⇒ **登记** ✓，**不改** ✗、**不定论** ✗。

### 日志出处 ✓
`logs/WT-040-R1/{gate-final-20260915-175843, gate-verdict-20260915-182118, gate-solo-20260915-182541}/gate.log` ✓
（末行 `EVIDENCE=…` 指向 runner 自己的逐套件日志目录 ✓。）

---

## 13. ⚠️ **真实构建的既存缺陷**（`build_release.ps1` 的 `fresh_import` 步骤）✗ —— 证据完整 ✓，**按红线不修改** ✗
### 现象 ✓
```
fresh_import passed=False
Build stopped at fresh_import; see recorded output. No verified release ZIP created.
```
（`logs/031/73e0b3a9…/build-20260916-104612-343/` ✓；目录 `backups/builds/031/73e0b3a9…/{clean-source,package}` 已建 ✓）

### 逐份证据 ✓
| 证据 | 内容 |
|---|---|
| `RESULTS.json` | `name=fresh_import` · **`exit_code=null`** ✗ · `timed_out=false` · `passed=false` |
| `fresh_import.stdout.log`（123.8 KB）尾部 | **导入实际完成** ✓：`[DONE] reimport` ×2 ✓ · `loading_editor_layout [DONE]` ✓ |
| 该 stdout 中错误关键词 | **0 条** ✓ |
| `fresh_import.stderr.log`（0.2 KB） | 仅 **WARNING** ✓：`Addon 'res://addons/bound_model_export/plugin.cfg' failed to load` ✓ |

### 判定 ✓
**步骤本身成功，却因 `exit_code` 取到 `null` 被判失败** ✗ —— 即 **PowerShell `Start-Process` 退出码 `$null` 陷阱** ✓（本会话知识已记录 ✓）。
⇒ **这是发布工具链的既存缺陷** ✓，**不是**我的改动所致 ✓（其 `source_sha=73e0b3a9` ✓ 为当前分支提交 ✓，但缺陷位于脚本的退出码处理 ✓）。

### 处置（遵守红线 ✓）
- `tests/build_release.ps1` **就是"构建发布流程"** ✗ ⇒ **不修改** ✗（红线 ✓）；
- ⇒ **独立可运行包**（第 ⑤ 步最后一块）**因此受阻** ✗ ⇒ **如实上报** ✓，并给出**可选路径**供您裁定 ✓：
  1. 授权我**修正该脚本的退出码判定**（一处小改 ✓，属**改构建流程** ⇒ 需您明确授权 ✗）；
  2. 或接受"**包校验暂缓**" ✓，以其余证据（应用流程 127/0 ✓ · 辅助能力 51/0 ✓ · 科技树 50/0 ✓ · 真实对局 ✓）作为第 ③/⑤ 阶段的运行证据 ✓。

---

## 14. 🏁 **第 3 阶段核心运行证据：无注入真实对局的完整流程通过** ✓✓
命令 ✓：`<engine> --headless --path <cont> --fixed-fps 60 -s res://tests/run_app_match_cycle.gd` ✓
日志 ✓：`logs/WT-040-R1/phase3-match-cycle2.log` ✓（**仍在逐图循环** ✓）

### 进程族（**判据更正** ✓：须测**引擎本体**，不是 console 包装器 ✗）
| pid | 进程 | CPU |
|---|---|---|
| **27728** | `Godot_v4.7.2-stable_win64`（**引擎本体** ✓） | **871.2 s** ✓ |
| 16164 | `…_console`（包装器 ✗） | 0 s ✗（我此前误测它 ✗） |

### map 0：**完整流程全通过** ✓✓（`[PASS]` 原文 ✓）
```
[PASS] natural result shows frozen combat summary 0                 结算摘要冻结 ✓
[PASS] natural finish commits one receipt without pending reward 0  结算票据、无待发奖励 ✓
[PASS] retry cannot duplicate natural match reward 0                重试不重复发奖 ✓
[PASS] natural result restarts a fresh world 0                      下一局重开新世界 ✓
[PASS] restart returns to usable garage 0                           回到可用车库 ✓
[PASS] normal garage starts map 1                                   下一图从正常车库开局 ✓
```
### map 1：交火进行中 ✓
`NATURAL_MATCH map=1 … 177.0 tickets={ 1: 240, 2: 300 }` ✓

⇒ **这正是用户第 ⑤ 步要求的链路** ✓：**正常车库 → 对局 → 结算 → 下一局 → 回车库 → 再开局** ✓，
且**全程无注入**（该套件自述：no injected outcome/damage/tickets/accelerated timers ✓）⇒ 属**真实运行** ✓✓。

---

## 15. 真实对局套件的**上界、界面性质与断言**（只读源码 ✓）
```gdscript
create_timer(1500,true,false,true).timeout.connect(... print("NATURAL_MATCH_TIMEOUT"); quit(2))
for map_index in 2:                       # 只有两张图
    app.garage.vehicle_choice.select(1)   # 真实车库控件
    app.garage.preparation.mode_choice.select(1)
    app.garage.preparation.map_choice.select(map_index)
    app.enter_laboratory("team")          # 真实入口
    for tick in 36500: …                  # 单图上限 608 s
```
| 性质 ✓ | 说明 |
|---|---|
| **走真实界面** ✓ | 不是绕过界面：直接驱动**车库选车/模式/地图**控件并 `enter_laboratory("team")` ✓ |
| **上界明确** ✓ | 两张图 ✓ + 单图 608 s ✓ + **1500 s 硬超时** ✓ ⇒ **会自己结束** ✓ |
| **断言强** ✓ | `reason ∈ {tickets, time_limit}` ✓ · `combat_summary == director.report` ✓ · 票据冻结 ✓ · `apply_result_once` 幂等 ✓ |

⇒ 该套件同时是第 ⑤ 步"**走正常入口**"的**可执行证据** ✓✓。

---

## 16. `NATURAL_RESULT map=0` 已出 ✓ —— 并附一处**不下结论的观测** ✗
```
NATURAL_RESULT map=0 {"combat_summary":{"capture_seconds":0.0,"deaths":0,"hits":0,"kills":0,
                                       "last_death":"","penetrations":0}, …}
```
| 事实 ✓ | 说明 |
|---|---|
| **对局循环通过** ✓ | map 0 走到自然结算 ✓（套件断言 `reason ∈ {tickets,time_limit}` ✓、票据冻结 ✓、幂等 ✓） |
| **票数确实下降** ✓ | `tickets 300 → 8` ✓（297 s ✓） |
| **观测** ✗ | `combat_summary` 的 **hits/kills/penetrations 全为 0** ✗ ⇒ 其票数消耗**并非来自交战命中** ✗ |

### 处理 ✓（**严格就事论事** ✓）
- 本套件的**主题是"对局循环"** ✓ ⇒ 上述观测**不影响**其结论 ✓；
- **我不下结论** ✗：票数因何下降 ✓（投降/出界/计时规则/其它 ✓）**待查** ✓，需**另立检查** ✓；
- **不改任何东西** ✗：既不调参 ✓ 也不改规则 ✓；
- 记为**待查项** ✓，与"河谷队内拥堵"同属**战场行为层**的独立课题 ✓。

---

## 17. 🏁🏁 **最终结论：无注入真实对局套件 14/14 通过** ✓✓✓
```
=== 结果: 14 项检查, 0 失败 ===
APP_MATCH_CYCLE_CHECKS_PASS
```
| 项 | 值 |
|---|---|
| 套件 | `tests/run_app_match_cycle.gd` ✓（**自行结束** ✓；**残留 Godot 进程 0** ✓） |
| 覆盖 | **两张图** ✓（`map 0` ✓ `map 1` ✓），**每张**走完：正常车库 → 对局 → `reason=tickets` 自然结算 → 摘要冻结 ✓ → 单据无待发 ✓ → 幂等 ✓ → 新世界 ✓ → 回车库 ✓ |
| 界面 | **真实控件** ✓（车库选车/模式/地图 ✓ + `enter_laboratory("team")` ✓） |
| 附带 | `TRAFFIC_EVIDENCE user://diagnostics/traffic/match_03.json` ✓ |
| 待查（**不下结论** ✗） | **两张图** `combat_summary` **均为全 0** ✗ ⇒ **系统性**现象 ✓，与"河谷拥堵"并列为**战场行为层独立课题** ✓（**非本阶段交付** ✓） |

⇒ 第 3 阶段"**真实运行**"至此**在本阶段范围内完成** ✓✓：
**应用流程 127/0** ✓ · **辅助能力 51/0** ✓ · **科技树 50/0** ✓ · **无注入真实对局 14/14** ✓ · **官方门禁 = 基线（126/2）** ✓。

---

## 18. 🎯 **待查项已界定为系统性缺陷：零命中下的弹药殉爆** ✗✗（只读分析 ✓，**未改任何东西** ✗）
### 事实 ✓（两份 `NATURAL_RESULT` 的 `events[]` 逐条统计 ✓）
| map | 事件 | 组成 |
|---|---|---|
| 0 | 20 | spawn ×13 ✓ · **death ×5** ✓ · match_started ×1 · match_finished ×1 |
| 1 | 14 | spawn ×10 ✓ · **death ×2** ✓ · match_started ×1 · match_finished ×1 |

**全部阵亡的 `cause` 均为 `ammo_detonation`（弹药殉爆）** ✗：
```
map 0: A2 t=55.8 · A4 t=88.9 · B t=95.2 · A2 t=129.4 · A4 t=144.9
map 1: A4 t=120.8 · B2 t=371.5
```
而 `combat_summary.hits = 0` ✗（**零命中** ✓）⇒ **零命中下发生 7 次殉爆** ✗，**双方均中** ✓，最早 **t≈55 s** ✓（近乎自发 ✓）。

### 扣票机制（源码 ✓ `scripts/battle/ticket_ledger.gd`）
```
line 12: tickets[team] -= DEATH_COST        ← 每次阵亡（主因 ✓，因 capture_seconds=0 ✓）
line 26: drain_bank（占点渗透 ✓）           ← 本次**未生效** ✓（capture_seconds = 0 ✗）
```
⇒ **链条** ✓：**无命中殉爆 → 阵亡 → `DEATH_COST` 扣票 → 票数归零 → `reason=tickets"` 结束** ✓✓

### 更正我此前的两次推断 ✗
① "规则驱动的占点渗透" ✗ ⇒ **不成立**（`capture_seconds=0` ✓）；
② "AI 阵亡、交战驱动" ✗ ⇒ **只对一半**（有阵亡 ✓，但**非交战所致** ✗）。

### 处置 ✓（**严守范围** ✓）
- **只读分析** ✓，**未改代码/参数/规则** ✗；
- 该缺陷属**战斗规则层** ✓ ⇒ **非本阶段交付** ✓ ⇒ 已登记为**独立课题** ✓，与"河谷队内拥堵"并列 ✓；
- **建议立项** ✓（因其**系统性**：每局都会因此提前结束 ✓，且**零命中即可起爆** ✗）。

---

## 19. ❌ **撤回**第 18 节的"系统性缺陷"结论 ✗✓ —— 根因是**摘要为玩家口径**
### 决定性证据 ✓（`scripts/battle/team_match_director.gd`）
```gdscript
func observe_contact(record) -> void:                     # L16
    if state.phase != "playing" or record.get("round_id",-1) != state.match_id \
       or record.get("shooter_id","") != "A": return       # L17 ⚠️ 只统计玩家 A 的接触
```
且 `scripts/battle/team_range.gd:63` ✓ **已正确接线**：`projectiles.projectile_contact.connect(director.observe_contact)` ✓

### 四个计数**全部是玩家口径** ✓
| 字段 | 递增处 | 口径 |
|---|---|---|
| `hits` / `penetrations` | L25 / L28 | **仅 `shooter_id == "A"`** ✓ |
| `deaths` | L102 | **仅 `id == "A"`** ✓ |
| `kills` | L106 | **仅 `shooter_id == "A"`** ✓ |
而该套件把玩家车也设为 AI ✓（`director.state.roster.A.player = false` ✓ 见 `team_range.gd:64` ✓）
⇒ ⇒ **AI 对 AI 的对局里，摘要全 0 属设计如此** ✓✓。

### 撤回与更正的结论 ✓
1. **弹道命中确实发生** ✓：`DamageResolver.resolve` 产出 `kind=="module"` ✓ ⇒ 击穿弹药架 ✓ ⇒ `ammo_detonation` ✓ ⇒ **`cause` 一致合理** ✓；
2. ⇒ **不存在"零命中下的自发起爆"** ✗ ⇒ **第 18 节的缺陷登记作废** ❌；
3. **票数下降机制正常** ✓：**AI 阵亡 × `DEATH_COST`** ✓（真实交战所致 ✓）；占点渗透（`drain_bank` ✓）本次未触发 ✓（`capture_seconds=0` ✓）；
4. **教训** ✓：**"摘要为 0"不等于"什么都没发生"** ✗ —— **统计口径必须先读清** ✓（本会话第 N 次同类 ✓：**先核实口径，再下结论** ✓）。

### 订正（2026-09-16 ✓）：几何自校验的**权威数字是 50/0**（原文档写 29/29 ✗）
- **权威来源** ✓：收官验收 `logs/WT-040-R1/final-acceptance-20260916-113742/` 的
  `=== 结果: 50 项检查, 0 失败 ===` ✓ · `MODERN_GEOMETRY_CHECKS_PASS` ✓；
- **正确调用** ✓（裸 ASCII id ✓，与流水线一致 ✓）：
  `-s res://tests/check_modern_geometry.gd -- ussr_t_80b germ_leopard_2a4` ✓
  （该检查第 34 行 `if text.contains("="): continue` ✗ ⇒ **含 `=` 的旧式 `id=path` 参数会被静默跳过** ✗，
  那正是先前得到 29 这一偏小数字与 `no targets` 失败的原因 ✓）；
- **其余数字经核对一致** ✓：流水线 **9/9** ✓ · `LayoutValidator` **0 / 2** ✓ · 六个 `definitions` **全 0** ✓ ·
  门禁 **128 套件 / 126 PASS / 2 FAIL** ✓ · 应用流程 **127/0** ✓ · 辅助能力 **51/0** ✓ · 科技树 **50/0** ✓ · 真实对局 **14/14** ✓ ·
  gap **9 / 10**（其中 shape 门后仅 **1**）✓。
---

## 20. ✅ **加固：封死"假绿"通道**（`check_modern_geometry.gd` 参数校验 ✓）
### 动机 ✓
该检查原先**静默跳过**任何含 `=` 的参数 ✗ ⇒ 调用者若写错格式 ✓，会**少跑车辆却仍看到通过标记** ✗✗
（**本会话文档里的"29/29"正是此坑的产物** ✗ —— 见下用例 ③ 复现 ✓）。
### 改动 ✓（**测试工具**，非产品代码 ✓）
```gdscript
if text.contains("="):
    _check(false, "argument '%s' contains '='; this check takes BARE ascii ids … would have been skipped silently" % text)
    continue
if not FileAccess.file_exists(dossier):
    _check(false, "no dossier for id '%s' … refusing to check fewer vehicles than asked" % [text,dossier])
    continue
```
### 四路验证 ✓
| 用例 | 结果 |
|---|---|
| ① 正确调用（裸 id ✓） | **`50 项检查, 0 失败`** ✓✓ · `MODERN_GEOMETRY_CHECKS_PASS` ✓（**未变** ✓） |
| ② 旧式 `id=path` ✗ | **exit=1** ✓ · `[FAIL] … contains '=' … would have been skipped silently` ✓ · **FAIL** ✓ |
| ③ 不存在的 id ✗ | **exit=1** ✓ · `[FAIL] no dossier for id …` ✓ · **FAIL** ✓ · **恰好 29 项** ✓✓（＝"漏一辆车"的签名 ✓） |
| ④ 流水线（用裸 id ✓） | **exit=0** ✓ · `geometry_check exit=0 errors=0 OK` ✓ · **`MODERN_PIPELINE_OK`** ✓✓（**零回归** ✓） |
⇒ **任何调用失误现在都会响亮失败** ✓✓，**不会再产生假绿** ✓。
---

## 21. ✅ **同类缺陷扫查**：又封死一条"假绿"通道（`generate_modern_geometry.gd` ✓）
### 扫查范围 ✓（本阶段 12 个测试/工具 ✓，只读 ✓）
| 结果 | 工具 |
|---|---|
| **发现同类缺陷** ✗ | **`generate_modern_geometry.gd`** —— `if parts.size() != 2: print("[geom] bad arg ",entry); **continue**` ✗ |
| 同类但风险低 ✓ | `probe_source_nodes.gd`（仅探测 ✓，文件缺失/解析失败时 `continue` ✗ —— 属**信息性** ✓） |
| 无取参 ✓ | 其余 9 个（不接受外部输入 ✓ 无此风险 ✓） |
### 缺陷实质 ✗
**格式错误的参数被忽略** ✗ ⇒ 生成器**少测车辆却仍 `quit(0)`** ✗ ⇒ 而其产物 `modern_geometry_draft.json`
**被流水线的 `geometry_check` 与层级探针消费** ✗ ⇒ **缺车草案可悄然流入下游** ✓（且其自身两条错误路径
**不一致** ✗：空参数 `quit(1)` ✓ vs 坏参数 `continue` ✗）。
### 修法 ✓（**比症状更强** ✓）
写入**之前**比对 **行数 vs 参数数** ✓，不符则**拒绝写出** ✗：
```gdscript
if rows.size() != args.size():
    print("[geom] REFUSING to write: asked for %d target(s) but measured %d …" % [args.size(),rows.size()])
    print("MODERN_GEOMETRY_FAIL") ; quit(1) ; return
```
⇒ 可捕获**任何原因**的行丢失 ✓（含未来新增路径 ✓），**不止**坏参数这一种 ✓。
### 四路验证 ✓
| 用例 | 结果 |
|---|---|
| ① 正确调用（两车 ✓） | **exit=0** ✓ · `MODERN_GEOMETRY_DONE` ✓ |
| ② 一个坏参数 ✗ | **exit=1** ✓ · `bad arg …` ✓ + **`REFUSING to write …`** ✓ + **`MODERN_GEOMETRY_FAIL`** ✓ |
| ③ 草案完整性 ✓ | **仍两车** ✓（**短草案被拒 ⇒ 好草案存活** ✓✓） |
| ④ 流水线 ✓ | **exit=0** ✓ · `MODERN_PIPELINE_OK` ✓ · gap 仍 **9/10** ✓（**未变** ✓） |