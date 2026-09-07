# 工程边界与数据契约（按需实现，不是一次重构要求）

## 现有基线
资料显示已有 scripts/game_config.gd、world_builder.gd、target_board.gd、tank.gd、turret_rig.gd、camera_rig.gd、gunner.gd、hud.gd、main.gd，及tests/run_checks.gd。
这些名称来自交付资料，本次未逐行审查所有脚本；实施前由Codex核对实际文件。
沿用能工作的实现，逐步提取职责；无需为了计划强行改全部目录。

## 1. 唯一状态来源
配置（可共享）→ 实例状态（不能共享）→ 控制命令 → 真实战斗结算 → 只读事件/回放/UI。
配置资源可能被多个实例共同使用，所有可变状态单独存放；此处参考Godot官方Resources文档。
禁止HUD维护第二份装填计时、回放维护第二份伤害、AI维护特权版命中。

## 2. 数据定义
### VehicleDefinition
id/schema_version/display_name_key；外观/碰撞/部件坐标；movement；turret（射界/角速度）；weapon_id；armor_surfaces[]；module_defs[]；crew_roles[]；ammo_capacity。
速度m/s，加速度m/s²，长度m，装甲/穿深mm，外部配置角度degree，内部数学可用radian但入口必须转换。
定义只读，加载时校验ID和范围；无法加载就明确报错，不能随机换车。

### VehicleRuntimeState
entity_id/team_id/definition_id；transform/velocity；turret_yaw/gun_pitch；module_states；crew_assignments；ammo_racks/chamber/selected_next_shell；reload/repair/fire timers；destroyed与death_event_id。
新实例必须完全独立，重置不会修改车型定义或其他实例。持久化战绩不保存此类局中状态。

### VehicleCommand
throttle[-1,1]、steer[-1,1]、aim_world_point（或明确的瞄准方向）、fire_requested、select_shell、repair_requested、extinguish_requested。
PlayerController与AIController只生成命令；VehicleActor负责限制输入并调用相同驱动/武器系统。不开通网络接口。

### ArmorSurface / ModuleDefinition
面：稳定ID、所属部件、本地有限多边形/平面、外法线、thickness_mm、可选材质标签。
模块：稳定ID、类型、本地有向盒、所属部件、局部尺寸、游戏耐久、路径阻力、所属弹药架/成员或邻接关系。
视觉/行驶粗碰撞/装甲逻辑/模块几何是不同职责，但使用同一尺寸和部件变换。

### ProjectileState
shot_id/shooter_id/team_id/shell_id/seed；position/velocity/total_distance_m；cumulative_resistance_mm；ricochet_count；armed/inside_distance_m；lifetime；termination_reason。
首版是线段弹体，没有完整弹丸体积，没有真实弹体断裂、流体或材料强度模型。
APHE是有限碎片射线的游戏规则，不提供爆药工程仿真。

### OrderedHit
kind(world/armor/module)；entity_id/part_id/surface_or_module_id；distance_m；entry/exit world与local坐标；normal；是否进入。
查询服务仅给几何候选；能否伤到内部模块由穿透解析决定。

### ShotRecord
schema_version/rules_version/shot_id/seed/source；撞击瞬间vehicle与turret变换快照；有序交点；armor_before/after预算；module_before/after；最终停止/死亡原因。
UI、音效、特效、回放只读；保存有限环形缓冲。需要回放时可序列化Vector3等为普通数组；不能假设JSON直接支持Godot全部类型。

### MatchConfig / MatchState
配置：mode/map/vehicle_loadouts/AI_difficulty/seed/票数和时间规则快照。
状态：phase/team_tickets/capture/active_entities/respawn_queue/match_id/result。
唯一结算入口保证幂等；场景卸载取消所有旧回调。

### ProfileData
schema_version/tutorial_checkpoint/challenge_bests/match_summary/processed_recent_match_ids。
用户设置与成绩分文件保存，读取ID白名单，不从存档任意指定路径加载脚本。无云端、无中途战斗快照。

## 3. 推荐职责拆分
VehicleActor：拥有单车状态；VehicleDrive：地面/运动；TurretController：射界/转速；WeaponController：装填/射击合法性。
ShotQueryService：世界与车内几何；ArmorResolver：穿透近似；DamageResolver：模块变化；VehicleCapabilities：从模块推导功能。
ProjectileSystem：推进与限额；ShotRecordBuilder：记录已发生结果；ReplayView：显示副本。
AIController：决策/命令；MatchDirector：队伍、票、出生、胜负；UI/Audio/FX：事件订阅。
SettingsService/ProfileStore：局外持久化；AppFlow：菜单/加载/对局/结算切换。
这些可先是少量类/脚本，不强求每个概念一个Autoload，不建设通用事件框架。

## 4. 接口不变量
一发炮弹只由真实开火入口产生；每次开火只扣一发，冷却/损伤对玩家和AI都有效。
每层装甲消耗剩余穿透，不在下一层恢复；同层重入容差不能靠排除整车解决。
所有车内判定使用部件当时的世界变换；所有回放使用命中时快照而非当前变换。
每辆车死亡一次只发一个终结事件；比赛结算一次只提交一个结果；显示重播不得改变世界。
自己不打自己不等于所有同型号/同视觉层坦克都被排除。
物理空间查询在实际引擎允许的安全物理阶段执行；资源释放、场景切换和延迟任务都检查所属match/entity是否仍有效。

## 5. 测试形态
纯逻辑：角度、穿透预算、模块能力、票数、状态迁移、存档校验。
带场景集成：炮口遮挡、碰撞、旋转部件、真实武器入口、暂停/重置、8车生命周期。
图形实测：模型对齐、炮镜、中文、UI布局、特效、帧时间。
用户试玩：手感、能否理解、是否有策略选择。
前两类不能替代后两类，任何尚未执行的类别保留“待验证”。
