# 拟议接口契约

这是设计字段，不保证当前API已经同名存在。优先扩展原类、适配原字段，不复制业务系统。

1. 扩展现有生产类和数据，名称可适配；不为匹配本文件而重命名全仓。
2. 定义资源只读，运行状态每实例独立；前台/AI/网络共用权威规则。
3. Snapshot是某个tick及约定subtick的事实集合；模型、装甲、乘员、库存占用不得跨时刻拼接。
4. 所有新数值标reference/estimated/design及来源；未知不是0。
5. 有限预算返回incomplete而非默认miss/pass；诊断夹具不能改写正式包。

## CombatIdentity

责任方：现有车辆/比赛/弹丸权威对象

字段：`match_id`, `entity_id`, `life_id`, `generation`, `shot_id`, `projectile_id`, `root_effect_id`, `event_id`, `rules_version`, `content_version`

1. life_id标识新生命，不以life_id>1推断重生次数
2. 同event_id重复只能读取原结果，不再次变更
3. 不同版本回放不重新求解旧伤害

## CombatQuerySnapshotV2

责任方：QuerySnapshotBuilder及权威模拟阶段

字段：`identity`, `physics_tick`, `motion_fraction`, `layout_id`, `layout_revision`, `part_world_transforms`, `damage_revision`, `occupancy_revision`, `ammo_contents`, `fixed_structures`, `validity`, `diagnostics`

1. ammo_contents来自AmmoInventory真实状态
2. 存弹耗尽的逻辑体积不参与弹药窄相位；固定结构独立
3. 提交前revision过期要重查或拒绝，不能承认旧目标
4. 动态状态不能只用layout_id缓存

## ProjectileShapeProfile

责任方：ShellDefinition/具体弹药配置

字段：`version`, `origin`, `reason`, `bore_caliber_mm`, `effective_shape`, `shape_dimensions_m`, `sampling_policy`, `error_bounds`, `supported_motion`

1. 炮口径不等于长杆弹芯直径
2. 缺必需shape的新弹拒绝；legacy只能显式选择
3. 接触板episode独立于采样线编号和渲染帧

## TerminalResponseV2

责任方：ArmorResolver/ProjectileManager

字段：`contact_episode_id`, `plate_id`, `layer_id`, `time_of_impact`, `result`, `budget_unit`, `before_budget`, `consumed_budget`, `after_budget`, `incoming_velocity_mps`, `outgoing_velocity_mps`, `effect_allocations`, `normal`, `rules_version`

1. 毫米等效穿深、游戏伤害量、m/s不是可相加的同一种量
2. 各通道分配守恒只在已声明同单位模型内验证
3. 同板重采样不重复扣，真实新层或离开后重入不被吞掉

## CrewAndModuleCondition

责任方：VehicleRuntimeState与VehicleCapabilities

字段：`person_id_or_module_id`, `station_id`, `role`, `condition`, `integrity_or_health`, `response_profile_version`, `functional_effects`, `recovery_target`, `reasons`

1. UI颜色不生成伤势
2. 伤势人随换位移动，不能复制人数
3. 模块按类型选择线性/阈值/概率，不统一乘数
4. 实际修理比例与外观损伤颜色可不同，不伪装满修

## ExplosionEffectV1

责任方：弹丸终端→统一效果/伤害服务

字段：`root_effect_id`, `trigger`, `origin_world`, `trigger_tick`, `channel`, `game_profile_id`, `portal_or_breach_path`, `affected_identities`, `budget_state`, `seed`, `completion`

1. blast/fragment/overpressure独立
2. HEAT jet不自动触发压力通道
3. 固定世界遮挡与内部舱室使用真实允许路径
4. incomplete不等同于某目标免伤或整条通过

## CombatContributionReceipt

责任方：TeamMatchDirector/贡献账本

字段：`match_id`, `rules_version`, `source_events`, `owner`, `target_life`, `damage_contributions`, `fatal_source`, `assists`, `team_ticket_delta`, `personal_sp_delta`, `reward_delta`, `receipt_id`, `commit_state`

1. 一死亡一次票池变化
2. 结束后的旧事件不追加奖励
3. 回放环形缓存不是全场权威统计来源
4. 写盘/重连重复提交不能再入账

## SpawnTransaction

责任方：RespawnService及原编成服务

字段：`request_id`, `match_id`, `player_or_slot_id`, `vehicle_id`, `loadout_hash`, `content_version`, `reserved_cost`, `status`, `new_life_id`, `failure_reason`

1. validate→reserve→spawn_commit→charge_commit或rollback
2. 出生受阻不得丢预留
3. 未就绪车型不能回退默认车来成功扣款

## BackendViewForFIELDWORK

责任方：原HUDPresenter/VehicleDamageView/BattleUI适配

字段：`own_identity`, `condition_snapshot`, `crew_roles`, `ammo_chamber`, `ammo_next`, `rack_occupancy`, `capability_reasons`, `repair_state`, `effect_summary`, `spawn_state`, `permitted_intel`, `result_receipt`

1. 只读与当前生命绑定
2. 不公开敌方实时内构
3. 界面没有值时显示未知/不可用，不填演示数字
4. 布局/颜色由UI线维护，后端不覆盖整个界面文件

## AuditResultV2

责任方：测试/诊断运行器

字段：`suite_id`, `tested_sha`, `case_ids_expected`, `case_ids_executed`, `status`, `failures`, `incomplete_reasons`, `exit_code`, `log_errors`, `evidence_paths`

1. status=complete_no_gaps必须所有必需项执行完毕
2. ok=false+errors=[]不得PASS
3. exit_code未知/脚本异常/超时不能豁免
4. 测试原始预期与生产输出独立

