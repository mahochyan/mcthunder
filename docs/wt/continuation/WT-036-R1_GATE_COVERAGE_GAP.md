# WT-036-R1：门禁**覆盖缺口**报告（179 套件 vs 默认 32）

> `tests/` 下 `run_*.gd` 共 **179** 个；`tests/run_suite_checks.ps1` 默认列表 **32** 个；**未覆盖 147** 个。

## 1. 未覆盖套件分类（脚本生成）

| 类别 | 数量 | 建议 |
|---|---|---|
| A_窗口/演示类（需真实窗口或抓帧） | 35 | 维持"窗口/演示类"，与 4 个环境依赖套件同因 → NOT_RUN，不入默认门禁 ✓ |
| B_网络类 | 12 | 网络类：多进程/端口依赖 → 单独"网络档"运行，需显式授权或专用入口 ✓ |
| C_河谷类 | 6 | 河谷类：可并入默认门禁（逻辑型）✓ 建议补入 |
| D_逻辑/集成类（无窗口，可并入门禁） | 90 | **逻辑/集成类：建议补入默认门禁** ✓（本会话已验证同类可稳定运行） |
| E_其他 | 4 | 逐项判定后归类 ✓ |

## 2. 本会话对缺口的两次实测（说明"未覆盖"的真实风险）
- `run_chassis_response_checks`（**未覆盖**）：分支 **21/2**，两项失败 `muzzle and damage query follow authoritative braking tilt A/B` —— **与未改动基线完全一致** ⇒ **既有基线红**（非本分支引入）✓
- `run_industrial_checks` / `run_industrial_battle_checks`（**已覆盖**）：本会话据此发现并修复了我引入的 `ai_drive` 回归 ✓ ⇒ 覆盖与否直接决定能否发现回归 ✓

## 3. 建议（无需授权即可做，属测试侧）
1. 把 **D 类**（逻辑/集成）逐个试跑，能稳定绿者**补入默认门禁**（本会话已证实同类套件可稳定运行 ✓）；
2. **C 类（河谷）**同法补入；
3. **A 类**保持 NOT_RUN 并记录原因（窗口/抓帧/演示）；
4. **B 类（网络）**建立"网络档"专用入口（多进程/端口），与本机默认门禁分离 ✓

## 4. 附：D 类清单（90 项，建议优先补入）

- `run_ai_intercept_checks`
- `run_ai_recovery_checks`
- `run_ai_tactics_checks`
- `run_airborne_drive_checks`
- `run_ammo_compartment_checks`
- `run_app_flow_checks`
- `run_art_battle_render_checks`
- `run_asset_registry_checks`
- `run_authority_state_checks`
- `run_balance_match_checks`
- `run_balance_matrix_checks`
- `run_ballistic_intercept_checks`
- `run_bound_model_package_checks`
- `run_build_identity_checks`
- `run_chassis_recoil_checks`
- `run_chassis_response_checks`
- `run_chemical_checks`
- `run_chemical_content_checks`
- `run_command_contract_checks`
- `run_composite_binding_checks`
- `run_composite_checks`
- `run_composite_content_checks`
- `run_content_record_checks`
- `run_diagnostic_budget_checks`
- `run_engagement_distance_checks`
- `run_equipment_package_checks`
- `run_era_binding_checks`
- `run_era_checks`
- `run_era_network_checks`
- `run_export_checks`
- `run_fire_control_checks`
- `run_flank_crest_traversal_checks`
- `run_free_look_checks`
- `run_fuze_checks`
- `run_garage_frontend_checks`
- `run_hull_frame_checks`
- `run_input_binding_checks`
- `run_landing_contact_checks`
- `run_landing_response_checks`
- `run_loading_checks`
- `run_loading_mechanism_checks`
- `run_long_rod_checks`
- `run_long_rod_content_checks`
- `run_long_rod_damage_checks`
- `run_map_pack_checks`
- `run_match_batch_checks`
- `run_match_event_checks`
- `run_match_rules_checks`
- `run_material_replay_checks`
- `run_material_response_checks`
- `run_menu_fire_handoff_checks`
- `run_model_binding_checks`
- `run_model_binding_probe_checks`
- `run_model_showroom_checks`
- `run_modern_candidate_checks`
- `run_modern_equipment_checks`
- `run_modern_model_mount_checks`
- `run_moving_contact_checks`
- `run_moving_target_tick_checks`
- `run_multi_objective_checks`
- `run_observation_policy_checks`
- `run_optics_checks`
- `run_partial_support_checks`
- `run_powertrain_checks`
- `run_query_cache_checks`
- `run_query_metrics_checks`
- `run_reference_admission_checks`
- `run_research_tree_checks`
- `run_role_mapping_checks`
- `run_save_lock_checks`
- `run_settings_checks`
- `run_sight_ballistics_checks`
- `run_simulation_phase_checks`
- `run_spall_checks`
- `run_spall_content_checks`
- `run_support_actions_checks`
- `run_surface_drive_checks`
- `run_suspension_checks`
- `run_suspension_network_checks`
- `run_team_traffic_checks`
- `run_tech_segment_checks`
- `run_track_assembly_checks`
- `run_track_damage_checks`
- `run_track_drive_checks`
- `run_traffic_telemetry_checks`
- `run_turret_mechanism_checks`
- `run_turret_tick_checks`
- `run_tutorial_checks`
- `run_vehicle_readiness_checks`
- `run_world_vehicle_phase_checks`

---

## 最终归类（全部 **179** 个 `run_*.gd` 套件，可审计全景）
| 类别 | 数量 | 说明 |
|---|---|---|
| **默认门禁（headless 稳定绿）** | **123** | 见 `tests/run_suite_checks.ps1` ✓ |
| 慢档（单次 >240 s） | 4 | balance_match · traffic_attribution · traffic_telemetry（521 s 通过 ✓）· match_batch（>40 分钟判挂起 ✗） |
| 诊断电池（按设计有已知失败） | 1 | `run_flank_crest_traversal_checks`（T039-D ✓） |
| 零输出（需实参/窗口/输入） | 17 | 2 个零输出套件 + 2 个网络入口套件 + 4 个河谷入口套件 + 9 个 `*_player_checks` ✓ |
| 环境依赖（窗口/渲染/导出/设置/教程） | 8 | 与 4 个 DEFERRED 类同因 ✓ |
| **其余（未逐项试跑）** | **26** | 多为 `*_demo` / `*_overview` / `*_showcase` / `*_window` 变体与渲染类 ✓；如需可继续按同一方法试跑 ✓ |

> 方法：**先试跑、按证据归类**；**只有 headless 稳定绿且语义完整者**才入门禁 ✓；诊断电池与慢档**永不入门禁** ✓。
