# 门禁扩容日志（D 类试跑记录）

| 批次 | 套件 | 结果 |
|---|---|---|
| 1 | model_binding · suspension · track_drive · powertrain · query_cache · simulation_phase · turret_mechanism · loading | **8/8 绿** ✓（247 项检查，~14 s）→ 已入默认门禁 |
| 2 | landing_contact · landing_response · moving_contact · **partial_support** · surface_drive · hull_frame · chassis_recoil · track_damage · ammo_compartment · fire_control | 9 绿 + **`partial_support` 1 红（＝我引入的回归，已修 `c26ac2c1`）** ✓ → 10 项全部入默认门禁 |
| 3 | suspension_network · optics · moving_target_tick · world_vehicle_phase · vehicle_readiness · command_contract · track_assembly · sight_ballistics · observation_policy · role_mapping · support_actions | **11/11 绿** ✓ → 已入默认门禁 |
| 3（未入） | **`run_turret_tick_checks`** | 日志仅 152 B、**零检查输出** ⇒ 与窗口/演示类同因 ⇒ **NOT_RUN**（不入默认门禁）✓ |

## 价值（本会话两次实证）
补跑"默认门禁之外"的套件**直接抓到两个我引入的回归**：
1. `run_ai_drive_checks`（让行/僵持类 ✗ → 已修 `6937e684`）
2. `run_partial_support_checks`（转向支撑下限类 ✗ → 已修 `c26ac2c1`）
⇒ 两者现已**同时被默认门禁看住** ✓

## 默认门禁规模
**32 → 40 → 50 → 61** 条（每批均先试跑、全绿或修好后才入列表 ✓）
（`run_turret_tick_checks` 等零输出类保持 NOT_RUN，不入列表 ✓）

| 4 | engagement_distance · ballistic_intercept · material_response · long_rod_damage · spall · chemical · era · composite · fuze · content_record · reference_admission · match_rules | **12/12 绿** ✓（1,007 项检查，0.3–2.6 s）→ 已入默认门禁 |

**小发现（不影响判定）**：`run_composite_checks` 打印的标记是 `CHEMICAL_CHECKS_PASS`（疑似复制粘贴 ✗）——按日志正则 `^[A-Z_]*CHECKS_PASS$` 仍可识别 ✓，但人工读日志易混淆 ⇒ 建议作者统一标记名（**仅命名，语义与断言无关** ✓）。

**默认门禁规模**：32 → 40 → 50 → 61 → **73**

| 5 | team_traffic · authority_state · diagnostic_budget · tech_segment · asset_registry · match_event · modern_equipment · modern_candidate · equipment_package · composite_content · composite_binding | **11/11 绿** ✓（~18 s）→ 已入默认门禁 |
| 5（未入） | **`run_multi_objective_checks`** | exit=0 但 **零检查输出**（13.4 s、无结果行）⇒ 与窗口/演示类同因 ⇒ **NOT_RUN** ✓ |

**标记名不一致（累计 3 处，纯命名问题 ✓）**：`run_composite_checks`→`CHEMICAL_CHECKS_PASS` · `run_composite_content_checks`→`CHEMICAL_CONTENT_CHECKS_PASS` · `run_composite_binding_checks`→`BOUND_MODEL_PACKAGE_CHECKS_PASS`
⇒ 日志正则 `^[A-Z_]*CHECKS_PASS$` 均可识别 ✓，**不影响判定** ✓，但建议作者统一命名 ✓

**默认门禁规模**：32 → 40 → 50 → 61 → 73 → **84**

| 6 | **ai_recovery · ai_intercept · ai_tactics** · loading_mechanism · long_rod_content · chemical_content · spall_content · era_binding · bound_model_package · model_binding_probe | **10/10 绿** ✓（~22 s）→ 已入默认门禁 |
| 6（待定） | `run_match_batch_checks` | 超过单次命令 600 s 上限 ⇒ **待单独定性**（慢或挂起）✓ |

**AI 类全绿的意义**：`ai_recovery`（16）· `ai_intercept`（106）· `ai_tactics`（39）**全部通过** ✓ ⇒ 我在 `ai_path_driver.gd` 的让行/僵持改动**不扰动 AI 的恢复、拦截与战术行为** ✓（这是比单个用例更强的证据 ✓）

**默认门禁规模**：32 → 40 → 50 → 61 → 73 → 84 → **94**

| 7（部分） | **airborne_drive（13/0）** · **app_flow（127/0，42 s）** | **2/2 绿** ✓ → 已入默认门禁；同批其余因单次命令 600 s 上限未跑完 ⇒ 下一轮继续 ✓ |

**`airborne_drive` 全绿的意义**：它与我的**支撑/转向改动**最相关（空中/悬空行驶 ✓）⇒ 与 `partial_support` 一起**双向确认**了修正后的"无支撑不转向、单侧有支撑仍可枢轴"行为 ✓

**剩余未覆盖**：85 项；其中疑似逻辑类 **28**（本轮筛选中误含 `render/export` 类 ⇒ 下轮细化过滤 ✓）

**默认门禁规模**：32 → 40 → 50 → 61 → 73 → 84 → 94 → **96**

| 扫查（19 项批量，240 s/项） | balance_matrix · build_identity · era_network · garage_frontend · input_binding · long_rod · map_pack · material_replay · menu_fire_handoff · model_showroom · modern_model_mount · query_metrics · research_tree · save_lock · telemetry_measures | **15/15 绿** ✓ → 已入默认门禁 |
| 扫查（非 PASS） | **`run_balance_match_checks`** TIMEOUT（241 s 上限）⇒ **慢档** ✓ · **`run_flank_crest_traversal_checks` 18/8 FAIL** | 后者＝**我自己的 T039-D 诊断电池** ✓，其失败正是**已登记**的"M26 坡上起步（调校冲突）"与夹具限制 ⇒ **本就不应入门禁**（诊断电池 ≠ 门禁套件）✓ 已在文档中显式说明 ✓ |

**默认门禁规模**：32 → … → 96 → **111**

## 扫查总结（19 项批量，240 s/项）
| 判定 | 数量 | 明细 |
|---|---|---|
| **PASS → 入默认门禁** | **15** | 见上一节 ✓ |
| **TIMEOUT（慢档，不入）** | **3** | `run_balance_match_checks`（241 s）· `run_traffic_attribution`（241 s）· `run_traffic_telemetry_checks`（241 s 时 3 项）⇒ 后者**早前在 521 s 下曾 8/0 通过** ✓ ⇒ 属**慢但通过**，非失败 ✓ |
| **FAIL（诊断电池，不入）** | **1** | `run_flank_crest_traversal_checks`（**我的 T039-D**）8 项失败＝已登记的 **M26 坡上起步**与夹具限制 ✓ |

**门禁口径补充**：慢档套件（单次 >240 s）**不入门禁**，但应在"长时档"或按需运行 ✓；诊断电池**永不入门禁** ✓

## 工具修复：运行器默认超时 900 → **1500 s**
实测：`run_industrial_checks` 需 **962 s**（595/0 ✓）、`run_industrial_battle_checks` 需 **~1001 s**（与基线一致 15/1 ✓）⇒ **默认 900 s 会把这两个"已证通过/与基线一致"的套件误判为 TIMEOUT** ✗ ⇒ 默认超时提高至 **1500 s** ✓
（另有慢档：`balance_match` · `traffic_attribution` · `traffic_telemetry`（521 s 下通过 ✓）· `match_batch`（>40 分钟，判挂起 ✗））

## 网络类 11 套件**实测分类**（本轮，推翻我先前的笼统假设）
| 判定 | 数量 | 明细 |
|---|---|---|
| **headless PASS → 入默认门禁** | **9** | authority 62 · controller 11 · event_journal 64 · event_recovery 58 · fault 42 · fire_control 35 · frame 21 · identity 60 · pose 26 ⇒ **合计 379 项检查全绿** ✓ |
| **需三进程角色参数** | 1 | `run_network_slice`（`<role> <port> <output>`；**项目已有** `tests/run_network_slice.ps1` ✓）⇒ "网络档" ✓ |
| **需服务端 + 真实窗口** | 1 | `run_network_view_checks`（`get_cmdline_user_args()[0]` 为截图路径；**项目已有** `tests/run_network_view.ps1` ✓）⇒ 窗口/网络档 ✓ |

**更正我先前的结论**：覆盖报告里写"网络/房间类 ⇒ 需多进程专用入口" ✗ 过于笼统 —— 实测 **9/11 可 headless 独立运行并与门禁兼容** ✓，仅 2 个需要专用入口 ✓（且**入口已存在** ✓）。

**默认门禁规模**：32 → 40 → 50 → 61 → 73 → 84 → 94 → 96 → 111 → **120**

## `*_player_checks` 类试跑（本轮）
| 判定 | 数量 | 明细 |
|---|---|---|
| **headless PASS → 入门禁** | **1** | `run_turret_mechanism_player_checks` **41/0** ✓（有正规结束标记 ✓） |
| **零检查输出 ⇒ NOT_RUN** | **9** | core · drive · damage · duel · hud · landing · optics · recovery · replay 的 `*_player_checks` ⇒ 需**真实窗口/输入** ✓（headless 下不产出任何检查 ✓） |

**我的分类器缺陷（自查）**：当套件**无输出**时，PowerShell 的 `(Select-String ...)` 结果为 `System.Object[]` ✗ ⇒ 我脚本中的 `$marker` 非空 ⇒ **误判为 PASS** ✗。
⇒ 正确判据应同时要求 **`pass>0` 或 `fail>0` 或存在正规 `_PASS$/_FAIL$` 标记** ✓；本轮 9 项按此**改判 NOT_RUN** ✓。
（120 套件全量脚本中使用同类逻辑 ⇒ 待该跑完后**复核**是否存在同类误判 ✓）

**默认门禁规模**：32 → … → 120 → **121**

## 河谷类试跑（本轮）
| 判定 | 数量 | 明细 |
|---|---|---|
| **headless PASS → 入门禁** | **2** | `run_river_reachability_checks` **34/0** ✓ · `run_river_engagement_checks` **36/0** ✓（均有正规标记 ✓） |
| **零输出 ⇒ NOT_RUN** | **4** | `run_river_junction_checks` · `run_river_route_ui_checks` · `run_river_navigation_checks` · `run_river_driving_checks` ⇒ 需实参/窗口 ✓（与此前记录一致 ✓） |

**默认门禁规模**：32 → … → 120 → 121 → **123**
