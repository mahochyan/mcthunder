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
