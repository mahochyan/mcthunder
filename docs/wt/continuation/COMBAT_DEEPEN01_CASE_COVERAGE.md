# MCT-COMBAT-DEEPEN-01 case coverage: ninety six ids, mirrored rather than edited

The packaged list at `docs/wt/combat-deepen-01/original/08_ACCEPTANCE_CASES.json` is read-only. Its ninety six case ids are mirrored here with the evidence document this order keeps and the state it can actually show; a sub-order with no evidence document is recorded as NOT_RUN rather than assumed to pass. Every state below was regenerated from disk after WT-CD-015 and the packaged ids and titles were re-checked against the original before writing.

| sub-order | cases | state | executed | evidence document | result document | executors |
|---|---|---|---|---|---|---|
| CD01 | 6 | EVIDENCE_RECORDED | - | `docs/wt/continuation/COMBAT_DEEPEN01_CD001_EVIDENCE.md` | - | evidence document only (no runner) |
| CD02 | 6 | EVIDENCE_RECORDED | - | `docs/wt/continuation/COMBAT_DEEPEN01_CD002_EVIDENCE.md` | - | evidence document only (no runner) |
| CD03 | 6 | EVIDENCE_RECORDED | - | `docs/wt/continuation/COMBAT_DEEPEN01_CD003_EVIDENCE.md` | - | tests/probe_cd003_gap_baseline.gd |
| CD04 | 6 | EVIDENCE_RECORDED | - | `docs/wt/continuation/COMBAT_DEEPEN01_CD004_EVIDENCE.md` | - | tests/probe_cd004_ballistics_profile.gd + tests/probe_cd004_design4_audit.gd + tests/probe_cd004_longstep.gd + tests/probe_cd004_moving.gd + tests/probe_cd004_residual.gd + tests/probe_cd004_retention.gd + tests/probe_cd004_sampling_table.gd + tests/probe_cd004_shared_solver.gd + tests/probe_cd004_solver_e2e.gd + tests/probe_cd004_zero_drag.gd |
| CD05 | 6 | EVIDENCE_RECORDED | - | `docs/wt/continuation/COMBAT_DEEPEN01_CD005_EVIDENCE.md` | - | tests/probe_cd005_angle_series.gd + tests/probe_cd005_boundary.gd + tests/probe_cd005_era.gd + tests/probe_cd005_multilayer.gd + tests/probe_cd005_replay.gd + tests/probe_cd005_same_event.gd + tests/probe_cd005_seed_missing.gd + tests/probe_cd005_terminal.gd + tests/probe_cd005_three_channel.gd |
| CD06 | 6 | EVIDENCE_RECORDED | - | `docs/wt/continuation/COMBAT_DEEPEN01_CD006_EVIDENCE.md` | - | tests/probe_cd006_allocation.gd + tests/probe_cd006_fuze.gd + tests/probe_cd006_jet_ledger.gd + tests/probe_cd006_legacy_template.gd + tests/probe_cd006_occlusion.gd + tests/probe_cd006_replay_example.gd + tests/probe_cd006_replay_seed.gd + tests/probe_cd006_same_penetration.gd |
| CD07 | 6 | COMPLETE | 6/6 | `docs/wt/continuation/COMBAT_DEEPEN01_CD007_EVIDENCE.md` | `docs/wt/continuation/COMBAT_DEEPEN01_CD007_RESULTS.json` | tests/probe_cd007_bulkhead.gd + tests/probe_cd007_finality.gd + tests/probe_cd007_he_admission.gd + tests/probe_cd007_he_landed.gd + tests/probe_cd007_he_limit.gd + tests/probe_cd007_he_runtime.gd + tests/probe_cd007_he_spec.gd + tests/probe_cd007_heat_isolation.gd + tests/probe_cd007_hist_openings.gd + tests/probe_cd007_occlusion_target.gd + tests/probe_cd007_open_contrast.gd + tests/probe_cd007_open_top.gd + tests/probe_cd007_two_plates.gd + tests/probe_cd007_world_burst.gd |
| CD08 | 6 | COMPLETE | 6/6 | `docs/wt/continuation/COMBAT_DEEPEN01_CD008_EVIDENCE.md` | `docs/wt/continuation/COMBAT_DEEPEN01_CD008_RESULTS.json` | tests/run_cd008_scene_checks.gd + tests/probe_cd008_replacement.gd + tests/probe_cd008_t02_diag.gd |
| CD09 | 6 | COMPLETE | 6/6 | `docs/wt/continuation/COMBAT_DEEPEN01_CD009_EVIDENCE.md` | `docs/wt/continuation/COMBAT_DEEPEN01_CD009_RESULTS.json` | tests/run_cd009_scene_checks.gd + tests/probe_cd009_breech_request.gd |
| CD10 | 6 | COMPLETE | 6/6 | `docs/wt/continuation/COMBAT_DEEPEN01_CD010_EVIDENCE.md` | `docs/wt/continuation/COMBAT_DEEPEN01_CD010_RESULTS.json` | tests/run_cd010_scene_checks.gd |
| CD11 | 6 | COMPLETE | 6/6 | `docs/wt/continuation/COMBAT_DEEPEN01_CD011_EVIDENCE.md` | `docs/wt/continuation/COMBAT_DEEPEN01_CD011_RESULTS.json` | tests/run_cd011_scene_checks.gd + tests/probe_cd011_grounded_drive.gd + tests/probe_cd011_t05_escape.gd |
| CD12 | 6 | COMPLETE | 6/6 | `docs/wt/continuation/COMBAT_DEEPEN01_CD012_EVIDENCE.md` | `docs/wt/continuation/COMBAT_DEEPEN01_CD012_RESULTS.json` | tests/run_cd012_scene_checks.gd |
| CD13 | 6 | COMPLETE | 6/6 | `docs/wt/continuation/COMBAT_DEEPEN01_CD013_EVIDENCE.md` | `docs/wt/continuation/COMBAT_DEEPEN01_CD013_RESULTS.json` | tests/run_cd013_scene_checks.gd + tests/probe_cd013_ledger_behaviour.gd |
| CD14 | 6 | COMPLETE | 6/6 | `docs/wt/continuation/COMBAT_DEEPEN01_CD014_EVIDENCE.md` | `docs/wt/continuation/COMBAT_DEEPEN01_CD014_RESULTS.json` | tests/run_cd014_scene_checks.gd |
| CD15 | 6 | COMPLETE | 6/6 | `docs/wt/continuation/COMBAT_DEEPEN01_CD015_EVIDENCE.md` | `docs/wt/continuation/COMBAT_DEEPEN01_CD015_RESULTS.json` | tests/run_cd015_scene_checks.gd + tests/probe_cd015_feedback_behaviour.gd |
| CD16 | 6 | COMPLETE | 6/6 | `docs/wt/continuation/COMBAT_DEEPEN01_CD016_EVIDENCE.md` | `docs/wt/continuation/COMBAT_DEEPEN01_CD016_RESULTS.json` | tests/build_release.ps1 + tests/run_suite_checks.ps1 + tests/run_modern_player_flow.ps1 + tests/run_modern_package_checks.ps1 + tests/run_player_flow_checks.ps1 |

| case | sub-order | title | state | executors |
|---|---|---|---|---|
| CD01-T01 | CD01 | 同一路径满架与空架 | EVIDENCE_RECORDED | evidence document only (no runner) |
| CD01-T02 | CD01 | 半装与分区占用 | EVIDENCE_RECORDED | evidence document only (no runner) |
| CD01-T03 | CD01 | 最后一发在搬运或已装膛 | EVIDENCE_RECORDED | evidence document only (no runner) |
| CD01-T04 | CD01 | 同一物理步两发先后到达 | EVIDENCE_RECORDED | evidence document only (no runner) |
| CD01-T05 | CD01 | 切弹、补弹、重生及回放 | EVIDENCE_RECORDED | evidence document only (no runner) |
| CD01-T06 | CD01 | 缺少占用与旧缓存 | EVIDENCE_RECORDED | evidence document only (no runner) |
| CD02-T01 | CD02 | 关键部位叠加 | EVIDENCE_RECORDED | evidence document only (no runner) |
| CD02-T02 | CD02 | 姿态与机构 | EVIDENCE_RECORDED | evidence document only (no runner) |
| CD02-T03 | CD02 | 同板拆三角 | EVIDENCE_RECORDED | evidence document only (no runner) |
| CD02-T04 | CD02 | 真实多层与开口 | EVIDENCE_RECORDED | evidence document only (no runner) |
| CD02-T05 | CD02 | LOD与显示开关 | EVIDENCE_RECORDED | evidence document only (no runner) |
| CD02-T06 | CD02 | 脱塔重生与无效数据 | EVIDENCE_RECORDED | evidence document only (no runner) |
| CD03-T01 | CD03 | 静态窄缝 | EVIDENCE_RECORDED | tests/probe_cd003_gap_baseline.gd |
| CD03-T02 | CD03 | 大缝与切向擦边 | EVIDENCE_RECORDED | tests/probe_cd003_gap_baseline.gd |
| CD03-T03 | CD03 | 同板/真双层 | EVIDENCE_RECORDED | tests/probe_cd003_gap_baseline.gd |
| CD03-T04 | CD03 | 子步拆分与容量 | EVIDENCE_RECORDED | tests/probe_cd003_gap_baseline.gd |
| CD03-T05 | CD03 | 平移目标 | EVIDENCE_RECORDED | tests/probe_cd003_gap_baseline.gd |
| CD03-T06 | CD03 | 旋转炮塔与车体运动 | EVIDENCE_RECORDED | tests/probe_cd003_gap_baseline.gd |
| CD04-T01 | CD04 | 零阻力基准 | EVIDENCE_RECORDED | tests/probe_cd004_ballistics_profile.gd + tests/probe_cd004_design4_audit.gd + tests/probe_cd004_longstep.gd + tests/probe_cd004_moving.gd + tests/probe_cd004_residual.gd + tests/probe_cd004_retention.gd + tests/probe_cd004_sampling_table.gd + tests/probe_cd004_shared_solver.gd + tests/probe_cd004_solver_e2e.gd + tests/probe_cd004_zero_drag.gd |
| CD04-T02 | CD04 | 经验阻力配置 | EVIDENCE_RECORDED | tests/probe_cd004_ballistics_profile.gd + tests/probe_cd004_design4_audit.gd + tests/probe_cd004_longstep.gd + tests/probe_cd004_moving.gd + tests/probe_cd004_residual.gd + tests/probe_cd004_retention.gd + tests/probe_cd004_sampling_table.gd + tests/probe_cd004_shared_solver.gd + tests/probe_cd004_solver_e2e.gd + tests/probe_cd004_zero_drag.gd |
| CD04-T03 | CD04 | 预测与真实炮弹 | EVIDENCE_RECORDED | tests/probe_cd004_ballistics_profile.gd + tests/probe_cd004_design4_audit.gd + tests/probe_cd004_longstep.gd + tests/probe_cd004_moving.gd + tests/probe_cd004_residual.gd + tests/probe_cd004_retention.gd + tests/probe_cd004_sampling_table.gd + tests/probe_cd004_shared_solver.gd + tests/probe_cd004_solver_e2e.gd + tests/probe_cd004_zero_drag.gd |
| CD04-T04 | CD04 | 贯穿后引信 | EVIDENCE_RECORDED | tests/probe_cd004_ballistics_profile.gd + tests/probe_cd004_design4_audit.gd + tests/probe_cd004_longstep.gd + tests/probe_cd004_moving.gd + tests/probe_cd004_residual.gd + tests/probe_cd004_retention.gd + tests/probe_cd004_sampling_table.gd + tests/probe_cd004_shared_solver.gd + tests/probe_cd004_solver_e2e.gd + tests/probe_cd004_zero_drag.gd |
| CD04-T05 | CD04 | 移动射手与目标 | EVIDENCE_RECORDED | tests/probe_cd004_ballistics_profile.gd + tests/probe_cd004_design4_audit.gd + tests/probe_cd004_longstep.gd + tests/probe_cd004_moving.gd + tests/probe_cd004_residual.gd + tests/probe_cd004_retention.gd + tests/probe_cd004_sampling_table.gd + tests/probe_cd004_shared_solver.gd + tests/probe_cd004_solver_e2e.gd + tests/probe_cd004_zero_drag.gd |
| CD04-T06 | CD04 | 长步、无效值和暂停 | EVIDENCE_RECORDED | tests/probe_cd004_ballistics_profile.gd + tests/probe_cd004_design4_audit.gd + tests/probe_cd004_longstep.gd + tests/probe_cd004_moving.gd + tests/probe_cd004_residual.gd + tests/probe_cd004_retention.gd + tests/probe_cd004_sampling_table.gd + tests/probe_cd004_shared_solver.gd + tests/probe_cd004_solver_e2e.gd + tests/probe_cd004_zero_drag.gd |
| CD05-T01 | CD05 | 正面/斜面普通板 | EVIDENCE_RECORDED | tests/probe_cd005_angle_series.gd + tests/probe_cd005_boundary.gd + tests/probe_cd005_era.gd + tests/probe_cd005_multilayer.gd + tests/probe_cd005_replay.gd + tests/probe_cd005_same_event.gd + tests/probe_cd005_seed_missing.gd + tests/probe_cd005_terminal.gd + tests/probe_cd005_three_channel.gd |
| CD05-T02 | CD05 | 长杆与全口径分离 | EVIDENCE_RECORDED | tests/probe_cd005_angle_series.gd + tests/probe_cd005_boundary.gd + tests/probe_cd005_era.gd + tests/probe_cd005_multilayer.gd + tests/probe_cd005_replay.gd + tests/probe_cd005_same_event.gd + tests/probe_cd005_seed_missing.gd + tests/probe_cd005_terminal.gd + tests/probe_cd005_three_channel.gd |
| CD05-T03 | CD05 | 真复合多层 | EVIDENCE_RECORDED | tests/probe_cd005_angle_series.gd + tests/probe_cd005_boundary.gd + tests/probe_cd005_era.gd + tests/probe_cd005_multilayer.gd + tests/probe_cd005_replay.gd + tests/probe_cd005_same_event.gd + tests/probe_cd005_seed_missing.gd + tests/probe_cd005_terminal.gd + tests/probe_cd005_three_channel.gd |
| CD05-T04 | CD05 | ERA两次命中 | EVIDENCE_RECORDED | tests/probe_cd005_angle_series.gd + tests/probe_cd005_boundary.gd + tests/probe_cd005_era.gd + tests/probe_cd005_multilayer.gd + tests/probe_cd005_replay.gd + tests/probe_cd005_same_event.gd + tests/probe_cd005_seed_missing.gd + tests/probe_cd005_terminal.gd + tests/probe_cd005_three_channel.gd |
| CD05-T05 | CD05 | 边界等值与背面 | EVIDENCE_RECORDED | tests/probe_cd005_angle_series.gd + tests/probe_cd005_boundary.gd + tests/probe_cd005_era.gd + tests/probe_cd005_multilayer.gd + tests/probe_cd005_replay.gd + tests/probe_cd005_same_event.gd + tests/probe_cd005_seed_missing.gd + tests/probe_cd005_terminal.gd + tests/probe_cd005_three_channel.gd |
| CD05-T06 | CD05 | 种子和缺资料 | EVIDENCE_RECORDED | tests/probe_cd005_angle_series.gd + tests/probe_cd005_boundary.gd + tests/probe_cd005_era.gd + tests/probe_cd005_multilayer.gd + tests/probe_cd005_replay.gd + tests/probe_cd005_same_event.gd + tests/probe_cd005_seed_missing.gd + tests/probe_cd005_terminal.gd + tests/probe_cd005_three_channel.gd |
| CD06-T01 | CD06 | 不同APHE同穿深 | EVIDENCE_RECORDED | tests/probe_cd006_allocation.gd + tests/probe_cd006_fuze.gd + tests/probe_cd006_jet_ledger.gd + tests/probe_cd006_legacy_template.gd + tests/probe_cd006_occlusion.gd + tests/probe_cd006_replay_example.gd + tests/probe_cd006_replay_seed.gd + tests/probe_cd006_same_penetration.gd |
| CD06-T02 | CD06 | 未启动/延期/穿出 | EVIDENCE_RECORDED | tests/probe_cd006_allocation.gd + tests/probe_cd006_fuze.gd + tests/probe_cd006_jet_ledger.gd + tests/probe_cd006_legacy_template.gd + tests/probe_cd006_occlusion.gd + tests/probe_cd006_replay_example.gd + tests/probe_cd006_replay_seed.gd + tests/probe_cd006_same_penetration.gd |
| CD06-T03 | CD06 | 母弹与剥落预算 | EVIDENCE_RECORDED | tests/probe_cd006_allocation.gd + tests/probe_cd006_fuze.gd + tests/probe_cd006_jet_ledger.gd + tests/probe_cd006_legacy_template.gd + tests/probe_cd006_occlusion.gd + tests/probe_cd006_replay_example.gd + tests/probe_cd006_replay_seed.gd + tests/probe_cd006_same_penetration.gd |
| CD06-T04 | CD06 | 隔板和空架遮挡 | EVIDENCE_RECORDED | tests/probe_cd006_allocation.gd + tests/probe_cd006_fuze.gd + tests/probe_cd006_jet_ledger.gd + tests/probe_cd006_legacy_template.gd + tests/probe_cd006_occlusion.gd + tests/probe_cd006_replay_example.gd + tests/probe_cd006_replay_seed.gd + tests/probe_cd006_same_penetration.gd |
| CD06-T05 | CD06 | HEAT多层及失去能量 | EVIDENCE_RECORDED | tests/probe_cd006_allocation.gd + tests/probe_cd006_fuze.gd + tests/probe_cd006_jet_ledger.gd + tests/probe_cd006_legacy_template.gd + tests/probe_cd006_occlusion.gd + tests/probe_cd006_replay_example.gd + tests/probe_cd006_replay_seed.gd + tests/probe_cd006_same_penetration.gd |
| CD06-T06 | CD06 | 同seed与回放 | EVIDENCE_RECORDED | tests/probe_cd006_allocation.gd + tests/probe_cd006_fuze.gd + tests/probe_cd006_jet_ledger.gd + tests/probe_cd006_legacy_template.gd + tests/probe_cd006_occlusion.gd + tests/probe_cd006_replay_example.gd + tests/probe_cd006_replay_seed.gd + tests/probe_cd006_same_penetration.gd |
| CD07-T01 | CD07 | 封闭舱无破口 | COMPLETE | tests/probe_cd007_bulkhead.gd + tests/probe_cd007_finality.gd + tests/probe_cd007_he_admission.gd + tests/probe_cd007_he_landed.gd + tests/probe_cd007_he_limit.gd + tests/probe_cd007_he_runtime.gd + tests/probe_cd007_he_spec.gd + tests/probe_cd007_heat_isolation.gd + tests/probe_cd007_hist_openings.gd + tests/probe_cd007_occlusion_target.gd + tests/probe_cd007_open_contrast.gd + tests/probe_cd007_open_top.gd + tests/probe_cd007_two_plates.gd + tests/probe_cd007_world_burst.gd |
| CD07-T02 | CD07 | 开放舱与遮盖对照 | COMPLETE | tests/probe_cd007_bulkhead.gd + tests/probe_cd007_finality.gd + tests/probe_cd007_he_admission.gd + tests/probe_cd007_he_landed.gd + tests/probe_cd007_he_limit.gd + tests/probe_cd007_he_runtime.gd + tests/probe_cd007_he_spec.gd + tests/probe_cd007_heat_isolation.gd + tests/probe_cd007_hist_openings.gd + tests/probe_cd007_occlusion_target.gd + tests/probe_cd007_open_contrast.gd + tests/probe_cd007_open_top.gd + tests/probe_cd007_two_plates.gd + tests/probe_cd007_world_burst.gd |
| CD07-T03 | CD07 | 薄板破口与隔板 | COMPLETE | tests/probe_cd007_bulkhead.gd + tests/probe_cd007_finality.gd + tests/probe_cd007_he_admission.gd + tests/probe_cd007_he_landed.gd + tests/probe_cd007_he_limit.gd + tests/probe_cd007_he_runtime.gd + tests/probe_cd007_he_spec.gd + tests/probe_cd007_heat_isolation.gd + tests/probe_cd007_hist_openings.gd + tests/probe_cd007_occlusion_target.gd + tests/probe_cd007_open_contrast.gd + tests/probe_cd007_open_top.gd + tests/probe_cd007_two_plates.gd + tests/probe_cd007_world_burst.gd |
| CD07-T04 | CD07 | 世界触发与墙后 | COMPLETE | tests/probe_cd007_bulkhead.gd + tests/probe_cd007_finality.gd + tests/probe_cd007_he_admission.gd + tests/probe_cd007_he_landed.gd + tests/probe_cd007_he_limit.gd + tests/probe_cd007_he_runtime.gd + tests/probe_cd007_he_spec.gd + tests/probe_cd007_heat_isolation.gd + tests/probe_cd007_hist_openings.gd + tests/probe_cd007_occlusion_target.gd + tests/probe_cd007_open_contrast.gd + tests/probe_cd007_open_top.gd + tests/probe_cd007_two_plates.gd + tests/probe_cd007_world_burst.gd |
| CD07-T05 | CD07 | HEAT通道隔离 | COMPLETE | tests/probe_cd007_bulkhead.gd + tests/probe_cd007_finality.gd + tests/probe_cd007_he_admission.gd + tests/probe_cd007_he_landed.gd + tests/probe_cd007_he_limit.gd + tests/probe_cd007_he_runtime.gd + tests/probe_cd007_he_spec.gd + tests/probe_cd007_heat_isolation.gd + tests/probe_cd007_hist_openings.gd + tests/probe_cd007_occlusion_target.gd + tests/probe_cd007_open_contrast.gd + tests/probe_cd007_open_top.gd + tests/probe_cd007_two_plates.gd + tests/probe_cd007_world_burst.gd |
| CD07-T06 | CD07 | 复数目标与终局 | COMPLETE | tests/probe_cd007_bulkhead.gd + tests/probe_cd007_finality.gd + tests/probe_cd007_he_admission.gd + tests/probe_cd007_he_landed.gd + tests/probe_cd007_he_limit.gd + tests/probe_cd007_he_runtime.gd + tests/probe_cd007_he_spec.gd + tests/probe_cd007_heat_isolation.gd + tests/probe_cd007_hist_openings.gd + tests/probe_cd007_occlusion_target.gd + tests/probe_cd007_open_contrast.gd + tests/probe_cd007_open_top.gd + tests/probe_cd007_two_plates.gd + tests/probe_cd007_world_burst.gd |
| CD08-T01 | CD08 | 低/中/高剂量同目标 | COMPLETE | tests/run_cd008_scene_checks.gd + tests/probe_cd008_replacement.gd + tests/probe_cd008_t02_diag.gd |
| CD08-T02 | CD08 | 人和岗位分离 | COMPLETE | tests/run_cd008_scene_checks.gd + tests/probe_cd008_replacement.gd + tests/probe_cd008_t02_diag.gd |
| CD08-T03 | CD08 | 渐进累积与重复事件 | COMPLETE | tests/run_cd008_scene_checks.gd + tests/probe_cd008_replacement.gd + tests/probe_cd008_t02_diag.gd |
| CD08-T04 | CD08 | 恢复与失能 | COMPLETE | tests/run_cd008_scene_checks.gd + tests/probe_cd008_replacement.gd + tests/probe_cd008_t02_diag.gd |
| CD08-T05 | CD08 | 岗位能力契约 | COMPLETE | tests/run_cd008_scene_checks.gd + tests/probe_cd008_replacement.gd + tests/probe_cd008_t02_diag.gd |
| CD08-T06 | CD08 | 旧档和新生命 | COMPLETE | tests/run_cd008_scene_checks.gd + tests/probe_cd008_replacement.gd + tests/probe_cd008_t02_diag.gd |
| CD09-T01 | CD09 | 发动机部分损伤 | COMPLETE | tests/run_cd009_scene_checks.gd + tests/probe_cd009_breech_request.gd |
| CD09-T02 | CD09 | 传动/履带/驾驶员 | COMPLETE | tests/run_cd009_scene_checks.gd + tests/probe_cd009_breech_request.gd |
| CD09-T03 | CD09 | 炮闩故障单次请求 | COMPLETE | tests/run_cd009_scene_checks.gd + tests/probe_cd009_breech_request.gd |
| CD09-T04 | CD09 | 炮管与轴机构 | COMPLETE | tests/run_cd009_scene_checks.gd + tests/probe_cd009_breech_request.gd |
| CD09-T05 | CD09 | 修理与中断 | COMPLETE | tests/run_cd009_scene_checks.gd + tests/probe_cd009_breech_request.gd |
| CD09-T06 | CD09 | 无模块车型与重生 | COMPLETE | tests/run_cd009_scene_checks.gd + tests/probe_cd009_breech_request.gd |
| CD10-T01 | CD10 | 自动装填机构毁坏 | COMPLETE | tests/run_cd010_scene_checks.gd |
| CD10-T02 | CD10 | 待发耗尽 | COMPLETE | tests/run_cd010_scene_checks.gd |
| CD10-T03 | CD10 | 炮弹/装药分账 | COMPLETE | tests/run_cd010_scene_checks.gd |
| CD10-T04 | CD10 | 隔舱完好与被穿 | COMPLETE | tests/run_cd010_scene_checks.gd |
| CD10-T05 | CD10 | 搬运与起火 | COMPLETE | tests/run_cd010_scene_checks.gd |
| CD10-T06 | CD10 | 重生和并发事件 | COMPLETE | tests/run_cd010_scene_checks.gd |
| CD11-T01 | CD11 | 起步/制动/倒车 | COMPLETE | tests/run_cd011_scene_checks.gd + tests/probe_cd011_grounded_drive.gd + tests/probe_cd011_t05_escape.gd |
| CD11-T02 | CD11 | 转向损速与单侧履带 | COMPLETE | tests/run_cd011_scene_checks.gd + tests/probe_cd011_grounded_drive.gd + tests/probe_cd011_t05_escape.gd |
| CD11-T03 | CD11 | 坡顶与侧坡 | COMPLETE | tests/run_cd011_scene_checks.gd + tests/probe_cd011_grounded_drive.gd + tests/probe_cd011_t05_escape.gd |
| CD11-T04 | CD11 | 后坐对比 | COMPLETE | tests/run_cd011_scene_checks.gd + tests/probe_cd011_grounded_drive.gd + tests/probe_cd011_t05_escape.gd |
| CD11-T05 | CD11 | 碰撞和脱困 | COMPLETE | tests/run_cd011_scene_checks.gd + tests/probe_cd011_grounded_drive.gd + tests/probe_cd011_t05_escape.gd |
| CD11-T06 | CD11 | 玩家/AI和显示率 | COMPLETE | tests/run_cd011_scene_checks.gd + tests/probe_cd011_grounded_drive.gd + tests/probe_cd011_t05_escape.gd |
| CD12-T01 | CD12 | 观察与炮塔分离 | COMPLETE | tests/run_cd012_scene_checks.gd |
| CD12-T02 | CD12 | 稳定范围与机构 | COMPLETE | tests/run_cd012_scene_checks.gd |
| CD12-T03 | CD12 | 测距/装定/遮挡 | COMPLETE | tests/run_cd012_scene_checks.gd |
| CD12-T04 | CD12 | 烟幕与AI | COMPLETE | tests/run_cd012_scene_checks.gd |
| CD12-T05 | CD12 | 侦察与最后目击 | COMPLETE | tests/run_cd012_scene_checks.gd |
| CD12-T06 | CD12 | 低画质/缺装备/改键 | COMPLETE | tests/run_cd012_scene_checks.gd |
| CD13-T01 | CD13 | 单发多模块 | COMPLETE | tests/run_cd013_scene_checks.gd + tests/probe_cd013_ledger_behaviour.gd |
| CD13-T02 | CD13 | 多射手与持续火灾 | COMPLETE | tests/run_cd013_scene_checks.gd + tests/probe_cd013_ledger_behaviour.gd |
| CD13-T03 | CD13 | 同tick致死与重复回调 | COMPLETE | tests/run_cd013_scene_checks.gd + tests/probe_cd013_ledger_behaviour.gd |
| CD13-T04 | CD13 | 射手先死与新目标生命 | COMPLETE | tests/run_cd013_scene_checks.gd + tests/probe_cd013_ledger_behaviour.gd |
| CD13-T05 | CD13 | 玩家实弹死亡再出击 | COMPLETE | tests/run_cd013_scene_checks.gd + tests/probe_cd013_ledger_behaviour.gd |
| CD13-T06 | CD13 | 回放缓存与终局 | COMPLETE | tests/run_cd013_scene_checks.gd + tests/probe_cd013_ledger_behaviour.gd |
| CD14-T01 | CD14 | 旧模式回归 | COMPLETE | tests/run_cd014_scene_checks.gd |
| CD14-T02 | CD14 | 个人SP与队票 | COMPLETE | tests/run_cd014_scene_checks.gd |
| CD14-T03 | CD14 | 出击失败与重复请求 | COMPLETE | tests/run_cd014_scene_checks.gd |
| CD14-T04 | CD14 | 编成次数与资格 | COMPLETE | tests/run_cd014_scene_checks.gd |
| CD14-T05 | CD14 | 结算重试与存盘失败 | COMPLETE | tests/run_cd014_scene_checks.gd |
| CD14-T06 | CD14 | 重启与不同规则版本 | COMPLETE | tests/run_cd014_scene_checks.gd |
| CD15-T01 | CD15 | 表现开关 | COMPLETE | tests/run_cd015_scene_checks.gd + tests/probe_cd015_feedback_behaviour.gd |
| CD15-T02 | CD15 | 各弹族事件 | COMPLETE | tests/run_cd015_scene_checks.gd + tests/probe_cd015_feedback_behaviour.gd |
| CD15-T03 | CD15 | 回放旧新版本 | COMPLETE | tests/run_cd015_scene_checks.gd + tests/probe_cd015_feedback_behaviour.gd |
| CD15-T04 | CD15 | 同发三进程 | COMPLETE | tests/run_cd015_scene_checks.gd + tests/probe_cd015_feedback_behaviour.gd |
| CD15-T05 | CD15 | 乱序/重复/旧生命 | COMPLETE | tests/run_cd015_scene_checks.gd + tests/probe_cd015_feedback_behaviour.gd |
| CD15-T06 | CD15 | 情报权限 | COMPLETE | tests/run_cd015_scene_checks.gd + tests/probe_cd015_feedback_behaviour.gd |
| CD16-T01 | CD16 | 版本锁定与证据完整性 | COMPLETE | tests/build_release.ps1 + tests/run_suite_checks.ps1 + tests/run_modern_player_flow.ps1 + tests/run_modern_package_checks.ps1 + tests/run_player_flow_checks.ps1 |
| CD16-T02 | CD16 | 两车入口与配装 | COMPLETE | tests/build_release.ps1 + tests/run_suite_checks.ps1 + tests/run_modern_player_flow.ps1 + tests/run_modern_package_checks.ps1 + tests/run_player_flow_checks.ps1 |
| CD16-T03 | CD16 | 正常完整对局 | COMPLETE | tests/build_release.ps1 + tests/run_suite_checks.ps1 + tests/run_modern_player_flow.ps1 + tests/run_modern_package_checks.ps1 + tests/run_player_flow_checks.ps1 |
| CD16-T04 | CD16 | 同生命实弹再出击 | COMPLETE | tests/build_release.ps1 + tests/run_suite_checks.ps1 + tests/run_modern_player_flow.ps1 + tests/run_modern_package_checks.ps1 + tests/run_player_flow_checks.ps1 |
| CD16-T05 | CD16 | 历史与开放舱兼容 | COMPLETE | tests/build_release.ps1 + tests/run_suite_checks.ps1 + tests/run_modern_player_flow.ps1 + tests/run_modern_package_checks.ps1 + tests/run_player_flow_checks.ps1 |
| CD16-T06 | CD16 | 关闭重启和独立路径 | COMPLETE | tests/build_release.ps1 + tests/run_suite_checks.ps1 + tests/run_modern_player_flow.ps1 + tests/run_modern_package_checks.ps1 + tests/run_player_flow_checks.ps1 |

> **Evidence form difference, user-ruled and accepted:** CD03, CD04 and CD06 were closed as PREREQUISITES of this continuation package before it began, so their evidence is a substantial evidence document (185 / 297 / 284 lines) rather than a `RESULTS.json`. The user accepted this form and asked that the difference be stated here rather than presented as an identical delivery. An earlier revision of this note dated that ruling 2026-09-11; the ruling was recorded in this session and the correct date is 2026-09-19, which is corrected here rather than left standing. The same evidence-document form is also what CD01, CD02 and CD05 carry - they are left as EVIDENCE_RECORDED and are NOT presented as user-accepted, because the ruling named only CD03, CD04 and CD06.

> **CD07, closed by measurement under the same ruling:** its result file first declared `COMPLETE_WITH_GAPS` with five of six cases executed, so CD07-T04 was never run. The user ruled that it be BUILT AND MEASURED FIRST, and it was: `tests/probe_cd007_occlusion_target.gd` puts a real second vehicle six metres behind the wall, confirms `terminal=internal_burst`, `contact_kind=world_contact`, three channels with `external=true`, the overpressure channel NOT applied, and the target behind the wall intact with ten of ten modules, crew 3 to 3 and no death record. CD007 now stands at `COMPLETE`, six of six.

> **What a state means here:** `COMPLETE` means a result file exists with six executed cases and status COMPLETE; `EVIDENCE_RECORDED` means the order carries an evidence document and no result file, which is the form the user accepted for CD03, CD04 and CD06; `NOT_RUN` means neither exists. The evidence state for the package as a whole stays the engineering self-consistent version only, so nothing here is a claim of numeric agreement with any external title.
