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

## 021 实际接口增量
AmmoInventory._rack_shells保存按架/弹种分组的唯一库存；racks、chamber、in_transfer、shell_counts为该库存与两个互斥搬运位置的视图。select_next只改变下次取弹，begin_transfer固定搬运弹种，complete_load把同一发移入膛内。Gunner冻结膛内弹的标识、曲线、作用策略与种子后交给ProjectileManager；拒绝发射不扣弹。
HistoricalShellCatalog校验车型/火炮/口径及来源后建立正式ShellDefinition，覆盖020包原始弹道初值；原始档案不删除。VehicleActor重建/重生恢复initial_shell_counts。
ShellEffectPolicy跟踪已穿透目标的实际内部行程；FragmentSystem每发最多12条、每条3m/8次查询，使用共同查询、装甲和伤害入口。内部开口的封口仅用于内部范围判断，不生成阻力或碰撞。真实结果先提交到ProjectileState，再通知可重入监听者；回放只读burst/fragments，不重新生成随机方向。
AmmunitionSupply由TeamRange的实际物理循环推进，VillageRange提供队伍补给圆心。补给使用同一库存事务，补齐出战清单后停止；旧单弹种工程夹具仍使用兼容账本。

## 022 实际接口增量
GarageService.build_loadout使用已准入车型/弹种和AmmoInventory.configure_loadout验证配弹，并返回同一真实分配的预览快照。GaragePreparation只编辑局外配置；VehiclePreviewModel无AI、Gunner或伤害状态，具体面片/内构选择显示实际定义及依据状态，空架可见性来自库存快照。
Lineup.validate验证1—3个唯一车型、首发归属和正式模式解锁；MatchConfig.build冻结车型/每车数量与首发/编成/模式/地图/难度，公开读取返回深拷贝。AppFlow在正常入口验证并保存；BallisticsRange初次出生和TeamRange再出击使用GarageService.install，AI难度仅交给AIDifficulty。
ProfileStore是局外持久化入口，当前schema1保存研究点、解锁、车库配置及比赛收据。每次事务先完整校验，再写临时文件并重读校验，最后替换两个交替槽中较旧的一个；内存只在提交成功后更新。revision和临时目录锁拒绝并发覆盖，读取损坏槽时恢复前一有效槽并提示，两槽损坏则保留文件并禁止写入。空路径明确表示自动检查的隔离内存档案。029在本接口扩展迁移与恢复，不另建战斗快照存档。
ResearchGraph.unlock在一次ProfileStore事务中扣点并开放依赖满足的车型。ProgressionService.register_match先持久化profile_id:sequence唯一编号，再绑定本次真实TeamMatchDirector；apply_result_once只承认该导演的finished结果，奖励与消费pending及写入收据同一事务。重复收据奖励0；未知编号拒绝。写入失败保留已核实的只读结果，场景释放后仍可重试，新正式比赛不会覆盖待重试结果。未完成上次进程的比赛不补造结果。收据保留128份，已消费pending的旧编号即使移出收据窗口也不会重新获奖。
# 023地图目录增量

MapRegistry是两图的稳定ID、场景、标题和布局描述目录，definition(id)每次创建独立MapDefinition，未知ID返回null；MatchConfig.map_id()读取冻结出战配置。AppFlow选图和重开通过目录解析场景；历史工程默认仍进入hill_village。ProfileStore继续经MatchConfig验证，旧档无需改版本。

IndustrialRange继承VillageRange的通用地图数据接线并覆写定义/世界构建，最终复用TeamRange对局。工业NavigationBakePipeline、SpawnSelector、小地图、补给位置均读取该实例definition，不保留跨场景路网或节点。新增村落补给路点是地图数据修补，不改变车辆执行器或AI权限。
# 025 追加契约

ArtPalette/StaticArtBatch/WorldArtKit/WorldLighting 管理原创公共美术。HistoricalVehicleModel 的三组 Skin 合批只复用实际布局顶点，不更改装甲或模块数据。GLB 外饰继续跟随原部件轴。GeometryOverlay 独立比较当前世界空间三角形和法线。

ProjectileManager 在实际最近世界接触处调用 DestructibleSection，提交可见结构与同步碰撞变更，再将纯数据 world_damage 写入终止记录；HUD/瞄准预览不调用破坏逻辑。临时尘土和碎片无伤害权限。

VehicleActor 的死亡提交按实际原因启动 WreckTurretMotion（权威炮塔姿态/碰撞）；RecoveryVisuals 只读取状态。炮塔节点重挂后 QuerySnapshotBuilder 继续跟随同一实际节点，结束冻结、重置恢复、实体清理释放。殉爆视觉不可再次触发死亡事件或增加杀伤。存档不保存渲染节点。
