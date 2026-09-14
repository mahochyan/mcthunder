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
