# WT-027：人工／自动装填接入设计

2026-09-12。前半部分保留只读审计与设计；本轮获授权后形成的实现增量见文末。
主任务已运行并保存装填62项全通过证据，本子任务已只读核实，详见文末。
来源未知仍保留unknown；夹具不是实际现代车型参数。

## 目标与来源边界

让具备明确装配定义的三人自动装填车辆按装填设备工作，不因缺少本来就不存在的loader岗而
套人工装填手损失惩罚；保留人工车辆现有行为、有限库存和损伤/维修交易。

T-80B来源摘要明确三岗位，豹2A4明确四岗位。但两份TXT的通用模块列表均有装填手与自动装填机名称；
这些名字不是该车型装备证明。本轮不据此给任一候选配置automatic，也不创建假乘员。
T-80B的28+10、豹2A4的15+27仅为已定位的弹架数量候选；具体机械供弹架、待发标记、几何和
取弹顺序仍须明确。来源中的20s／13s是弹架补弹时间，8s／4s是相关补弹延迟，均不能充当
主炮射击装填时间。详见 `assets/reference_data/candidates/` 与 `docs/wt/WT030_REFERENCE_DATA.md`。

实现验证先使用明确game_rule的三人机械装填与四人人工装填夹具。
有证据且单位清楚的来源值仍标warthunder_reference；自行选择的规则/参数必须另标game_rule与理由。
不能以“工程validated”或文件hash代表历史verified。

## 现有真实流程与缺口

| 位置 | 已有行为 | 自动装填接入必须处理的地方 |
|---|---|---|
| `scripts/damage/vehicle_capabilities.gd:4` | 基于模块/岗位产生fire、reload_rate等；有乘员且loader不可用时乘以 `GameConfig.DAMAGE_MISSING_LOADER_RATE=1/1.6` | 未区分未安装loader岗和战损失去loader；未依赖装填机械模块。自动装填不能只全局删除人工惩罚。 |
| `scripts/gunner.gd:67` | 冷却以reload_rate推进，归零后finish_transfer并同步膛内弹定义 | 需要当前装填权限和完整事务状态；单改rate=0不足以防住其它直接完成入口。 |
| `scripts/gunner.gd:157`、`:183` | 选择空膛弹种可begin_transfer；try_fire还会finish_transfer；成功生成炮弹后扣膛弹、开始下一次transfer并设weapon.reload_time | 所有装填开始/完成入口必须遵守同一profile，保留实际发射成功才扣弹、选弹不替换膛内/在装弹。 |
| `scripts/damage/ammo_inventory.gd:125` | begin_transfer按字典顺序遍历所有架；一发从架到transfer再到chamber；总账守恒 | 没有供弹架/储备架分界、明确取弹顺序、装填设备可用性或储备→待发架搬运。不能为自动装填继续无条件跨架取弹。 |
| `scripts/damage/ammunition_supply.gd:9` | 补给区静止无火时按战前弹种清单补一发；INTERVAL_S=2是游戏规则；补空膛时直接begin_transfer | 外部补给不是车内补架，也不是射击装填。该直接装填入口必须改调Gunner统一入口；不能绕过损坏的机械或向不可用架补弹。 |
| `scripts/damage/vehicle_recovery.gd:10` | 非空ammo架被摧毁可殉爆；普通维修只恢复模块integrity，不补弹/复活乘员 | 装填机械是独立模块，不因为名字近似ammo而殉爆。维修后恢复装填能力，不重置库存或复制搬运中的弹。 |
| `scripts/damage/recovery_rules.gd:13` | 明确维修优先表，12秒维修至50%为game_rule；无装填机械项 | 增加明确装配的装填模块维修入口，保持旧模块相对顺序。不顺便把弹架变成可修复补弹器。 |
| `scripts/vehicle_actor.gd:300` | collect时推进Gunner时钟；begin阶段处理Recovery；mechanism阶段推进炮塔；finish阶段选弹/开火 | 新装填流程不能在Actor和Gunner/_process两处重复计时。需明确同帧火灾损坏/修复与装填完成的先后。 |
| `scripts/ui/hud_presenter.gd:44` | 直接根据role_available(loader)增加“缺装填手”信息 | 即使修正reload_rate，三人自动装填车仍会显示错误原因。HUD必须消费装填派生状态。 |
| `scripts/defs/vehicle_runtime_state.gd:64` | 初始化/重置增加generation并重建模块和岗位 | 装填时钟、搬运预留和旧generation回调必须一起失效，不能把进度放共享车型Resource。 |

当前AmmoInventory的供弹账本值得保留：
`racks + chamber + in_transfer + fired + lost == supplied`。
`shell_counts()`包含膛内与在装弹；外部补给增加supplied，车内移架不增加supplied。
现容量约定总携弹量包含膛内一发，不能把38/42额外加一变成39/43。
该约定是当前工程规则，不能据此反推来源中每个实车弹架是否包含膛内弹。

## 最小定义接口（拟新增，尚未实现）

建议新增 `LoadingProfile extends Resource`，由VehicleDefinition持有不可变配置。
`WeaponDefinition.reload_time`继续是**唯一主炮射击装填周期秒数**；不在profile另存第二份同义时钟。
补架的delay/interval属于不同动作，单独命名并验证。

```text
LoadingProfile
  schema_version: 1
  mode: "crew" | "automatic"
  crew_role: String                         # crew必须指向已装配岗位；automatic为空
  missing_crew_rate: float                  # 人工损失倍率，旧包适配为1/1.6；不是史料值
  required_module_ids: Array[String]        # 准确实际模块ID；automatic至少一个装填机械
  shot_feed_rack_ids: Array[String]         # 有序，射击装填只从这些物理弹架取弹
  supply_rack_ids: Array[String]            # 外部补给允许目的架，有序
  replenishment:
    enabled: bool
    reserve_rack_ids: Array[String]         # 与shot_feed_rack_ids不重叠
    delay_s: float                         # 持续满足条件后才能开始；不是reload_time
    interval_s: float                      # 储备→供弹架每发搬运时间
    required_role: String                  # 明确岗位；无人工需求须明确说明设计依据
    required_module_ids: Array[String]
    requires_stationary: bool
  evidence_keys: PackedStringArray          # 装备存在性、架子映射、条件与规则的字段记录
```

`LoadingProfile.validate(layout, weapon, field_evidence)`应拒绝：未知mode、NaN/INF/负时间、
空供弹集合、重复/错车型模块ID、非ammo供弹架、供弹/储备重叠、无容量架、未装配岗位、
声明automatic但缺装填设备/设备存在性字段、启用补架却缺必要时间/路径/条件。
自动模式的crew_role必须为空；不能以假loader岗掩盖错误mode。
引用的是主动布局内的模块/岗位，不能解析TXT“通用模块清单”的名称自动生成引用。

初版机械模块种类建议使用显式 `autoloader`，位置/体积/part和来源必须跟其它内构一样校验。
模块种类本身不授予能力；只有profile.required_module_ids准确绑定才生效。
有其它已实施动力依赖时也必须逐ID列明，不默认发动机损坏等于整套装填电源消失。

旧包未声明profile时走显式兼容适配：crew、原loader损失倍率、全部已声明ammo架按旧顺序供弹、
不启用新车内补架、沿用weapon.reload_time。新game_reference自动模式必须完整声明，
不能用默认兼容profile吞掉缺字段。对新profile增加 `loading.profile`（实际结构相等）和
`equipment.loading`（设备/模式/岗位存在性）字段证据，再接入现有参考来源门；不降低历史门。

## 运行接口与派生能力

建议由Gunner持有独立 `LoadingRuntime`，只存本实体的进度、阻断原因、搬运事务ID及generation；
配置仍由VehicleDefinition持有。保留AmmoInventory作为唯一弹药数量所有者，不在LoadingRuntime复制库存。

| 拟接口 | 责任 |
|---|---|
| `LoadingCapabilities.compute(profile, vehicle_state)` | 纯读，返回mode、can_load、reload_rate、replenishment_allowed、reasons；不创建弹/改时钟 |
| `Gunner.request_load()` | 空膛、无在装弹、profile与依赖允许时，按供弹架顺序领取选定类型一发并启动完整周期 |
| `Gunner.advance_loading(delta)` | 权威物理阶段唯一计时，使用当前派生能力；完成时再核对generation、模块、搬运弹和剩余时间 |
| `Gunner.try_complete_load()` | 原子完成入口，不能因cooldown=0就完成未授权/阻断的transfer；多次调用只完成一次 |
| `AmmoInventory.begin_transfer_from(rack_id, shell_id)` | 只负责经验证的指定架→原有transfer位置交易；不自行判断机械或乘员 |
| `AmmoInventory.reserve_rack_move(from, to, shell_id)`／`commit_rack_move(token)`／`cancel_rack_move(token)` | 车内补架的有界预留与原子移架；不增加supplied，不从外部补给伪造转移 |
| `LoadingRuntime.reset_for_generation(generation)` | 取消旧事务和时钟，重置后不允许旧完成回调重新装弹 |

保留旧`VehicleCapabilities.compute(state)`调用兼容性，增加可选profile参数，Actor传真实配置；
由该函数调用LoadingCapabilities并转发reload_rate及装填原因，避免HUD和Gunner另算两套规则。
独立状态调用的旧测试仍走兼容人工策略。

建议首批清楚固定的game_rule行为：

- crew：已装配loader健在时倍率1；其失能时沿用1/1.6。旧无乘员测试车保持倍率1。
- automatic：不检查不存在的loader岗；全部绑定机械模块integrity>0时倍率1，任一依赖失效则can_load=false、倍率0。暂不臆造受伤连续降速曲线。
- 机械损坏暂停在装弹和剩余进度，弹仍在transfer中且只计一次；不瞬移回架、不替换弹种。维修达到既有可工作阈值后续接剩余进度。
- 已经在膛内的弹，机械损坏本身不抹掉该弹；若炮手、炮闩等原fire条件仍允许，可以发射这一发，但不能自动装下一发。这是明确工程规则，不声称所有实车均如此。
- 自动循环与人工岗位替补分别结算。炮手失能仍阻止射击；自动模式不凭空创建乘员，也不改变现有最少存活人数和死亡条件。
- 没有选定类型供弹时显示“供弹架无此弹”，不跨到储备架、不自动变成另一类型、不显示虚假的已开始装填倒计时。

`select_shell`、成功发射后的续装、外部补给后的空膛续装都改调同一个request_load。
try_fire不得通过无条件inventory.finish_transfer绕过机械停机；只能调用受门控的try_complete_load
或读取已经完成状态。发射仍先由ProjectileManager接受，再扣膛弹，不改变既有反复开火/遮挡规则。

## 车内补架、容量与战损恢复

最小补架方案保留“架→炮膛”的原有transfer位置，另允许最多一个车内移架预留。
预留阶段该发仍属于来源架，计数和受击语义不改变；来源数量被锁定不能同时取走，目的架容量被预留，
经过独立补架时间后原子完成 `来源-1、目的+1`。这是明确的延时搬运近似，不声称弹丸空间轨迹已模拟。

这样无需在首增量新增第二种悬空弹体积，且不会把弹架补充误报为外部新增弹。
必须同时检查：来源可用量扣除预留、目的已占量加预留、原有炮膛transfer所占回退空间、类型是否合法、
部件存活及token所属generation。`conserved()`除总数外应加强每个架的有限容量检查；
预留不是额外库存，不能计入total_available第二次。

供弹顺序先满足空膛真实射击装填，再尝试储备→供弹架预留；同一发不能被两动作领取。
预留过程中改变下一弹选择不改变预留弹种。补架条件中断时取消预留并重置等待delay；
由于尚未移出来源架，取消不加弹。建议首批固定单一作业顺序：射击装填活跃时暂停车内补架时钟，
保留其唯一预留，射击装填完成后继续；供弹架空、未能开始射击装填时则允许补架完成后再装膛。
这是明确game_rule的作业简化，应写入规则版本和测试，不暗示已模拟各型人工/机械动作并行能力。

外部AmmunitionSupply只按战前弹种配额向profile.supply_rack_ids补弹，检查实际目的模块可用性及
容量预留；不能直接灌膛或直接调用inventory.begin_transfer。补给完成后调用request_load，
必要时还要先经历车内补架，再经历射击装填。现外部补给2秒/发是独立game_rule，与TXT的补架数值无关。

维修仍由VehicleRecovery执行，显式把autoloader加入维修名单，最小可追加末尾以保持旧模块排序。
恢复机械integrity不改变rack/chamber/transfer/supplied/fired/lost，已耗弹不会复活。
损坏ammo架不自动获得机械维修能力；空的损坏架不能因为外部补给而再次带弹，除非另有明确修复规则。
非空弹架现有殉爆规则继续作用；机械模块被命中只按机械受损结算，不因关联弹架就凭空殉爆。
车辆死亡调用lose_all一次并取消预留；reset/重开先清旧事务，再按保存配弹重建账本并绑定新generation。

## 统一时序、界面与网络

建议新LoadingRuntime的唯一推进放在Actor的mechanism阶段：本tick Recovery提交之后、finish选弹/开火之前。
同一时钟若从collect移至mechanism必须删除旧入口；不能保留两处各扣delta。
单车standalone和VehicleSimulationDriver共用此阶段；_process、HUD、回放、远端副本不得计时。
维修本tick刚完成可从其后的机械阶段续装；火灾本tick损坏依赖应先阻止装填完成。
炮弹造成的新损伤仍遵循已有ProjectileManager晚于车辆阶段的顺序，不回改已经合法发射的本tick炮弹。

HUDPresenter读取loading.mode/phase/reasons，不对所有车型硬加缺loader提示；区分人工装填手失能、
机械装填故障、供弹架空、车内补架、正在射击装填。显示的是权威进度，剩余秒数不能把rate=0伪装成正常倒数。

当前网络stats只有cooldown/ammo等；后续需以有界版本字段传loading phase/reason、供弹状态和实际选定弹种，
客户端只显示。普通车库存档继续保存战前弹种数量/首发，不把临时进度塞入共享profile或假设已实现中途存档。
新字段的快照校验、断线/重建generation拒绝属于真实联网验收，不由本地夹具代签。

## 原始测试方案（制定时未运行；本轮已验证范围见文末）

建议新增 `tests/run_loading_checks.gd`，依赖当前真实VehicleDefs/Actor/Gunner/ProjectileManager与
损伤/维修接口；另扩展reference admission反例。用TEST ONLY抽象布局与AP/APHE弹族，避免现代候选尚缺的
弹族和几何成为伪证据。下表中的2发供弹架、4发储备、3秒周期均仅可作为标明game_rule的夹具值。

| 用例组 | 实际调用及应观察到的结果 |
|---|---|
| 定义反例 | 验证错mode、未知/异车型模块、空feed、非ammo架、重复ID、容量/单位/NaN、缺装备来源、自动模式假loader、未解决来源不能准入；旧四车包仍通过原门 |
| 三岗自动／四岗人工 | 两种真实Actor使用相同测试周期；自动三岗健康按1推进，人工loader损失按1/1.6推进；自动不会多出第4人，HUD不报不存在loader |
| 正常真实发射 | 玩家边沿命令发射→ProjectileManager真实冻结弹种→一发进入transfer→自然物理帧走完整周期→第二发；对比弹量、时长、发射记录，禁止直接设cooldown=0代签 |
| 弹种切换 | 1/2/循环选择第三弹、原膛弹首发、在装期间改选仍装原transfer弹；机械暂停/恢复后不改弹种、不重复扣弹 |
| 供弹有限 | 发完2发供弹架后，即使储备有4发也不得直接取储备；明确blocked原因、无假倒计时；完成独立补架后才允许再走射击装填 |
| 模块受击 | 通过Actor真实损伤事务破坏绑定机械：装填立即停止；已膛弹可合法发射一次，随后不再装；未绑定同类模块损坏不误停 |
| 部分装填→维修 | 自然装填一段后命中机械，足够物理帧后进度与库存保持；真实停车维修达到阈值，续接剩余时间；repair不补库存/复活乘员 |
| 同帧边界 | 火灾tick恰好破坏机械与装填结束同tick不越权完成；机械刚修好按规定阶段恢复；standalone/团队物理调度同结果且无双倍计时 |
| 补架守恒 | 真实reservations/commit/cancel重复调用、目的满、来源末发、并发选择/外部补给均不可复制或超架；车内移架不改变supplied，类型计数不变 |
| 补架中战损 | 来源/目的损坏、起火/移动条件中断、死亡/重置取消旧token；不从坏架取弹/向坏架补弹；旧generation完成无效 |
| 外部补给 | 真实AmmunitionSupply补已耗类型至战前配额，坏机械不因补给绕路装膛；储备目的架需再补架再装膛；整车/单架/每种弹均有限 |
| 人员替补 | 四人车loader捐岗位后按人工规则降速；三人车换炮手不生成loader；机械修复不复活人；死亡最少人数规则不变 |
| 暂停与重置 | 实际暂停冻结射击装填/补架延迟/搬运时间，恢复不补射；Actor.reset恢复自定义配弹、新generation，不让旧任务完成 |
| 旧行为回归 | 当前run_recovery_checks、run_damage_checks、run_shell_checks、run_reference_admission_checks、run_garage_checks、玩家循环弹与网络命令专项按影响复跑；保留失败/退出码/SCRIPT ERROR扫描 |

库存纯交易边界可用确定delta和直接事务验证；涉及游戏时钟、发射、维修、暂停的用例必须另走
真实物理帧与角色命令，不把纯函数证明扩大为真人操作证明。需有实际窗口演示三岗自动装填、机械受击停装、
维修续装及供弹耗尽/补架，人工体验保持NOT_RUN直至真正执行。

## 有界实施顺序

1. 定义profile/布局绑定/来源门、派生能力、所有Gunner与外部补给的统一装填入口；用抽象三岗自动夹具验证，旧人工行为不变。
2. 实现按供弹架取弹、有限车内补架预留、死亡/维修/重置事务及HUD原因；补齐容量和同帧测试。
3. 接入玩家/网络权威快照及窗口验证；之后才根据补齐的证据作者化T-80B/豹2A4完整配置。

首个工程增量可完成自动装填前置，但缺真实车型装配证据、主炮装填参数、供弹架几何/顺序、现代弹族时，
两款真实车型仍不能标完整可战。性能优化继续按用户要求暂停。

## 已写入的最小实现与真实验证

新增 `scripts/defs/loading_profile.gd`、`scripts/damage/loading_rules.gd`；
VehicleDefinition持有 `loading_profile`，VehicleCapabilities接受可选profile，Actor传当前车辆配置。
Gunner直接拥有本实例装填/补架进度和generation，不另外创建复制状态的LoadingRuntime。
这保留了设计要求的不可变配置与实例状态分离。

车辆包新增可选 `packet.loading_profile`，未声明的历史包仍使用人工兼容配置。
显式配置按字段白名单解析，验证类型、有限数、当前布局模块/岗位/弹架绑定；
`loading.profile` 与实际配置整体相等，`equipment.loading` 与实际
`{mode,crew_role,required_module_ids}`相等。参考来源门将两项列为必要、非unknown的structured字段。
自动模式必须显式写mode/crew_role/required_module_ids/shot_feed_rack_ids/origin/note，
并准确绑定至少一个主动布局中的autoloader模块；不扫描TXT通用名字授予能力。

当前序列化使用扁平字段：`schema_version/mode/crew_role/missing_crew_rate/required_module_ids/`
`shot_feed_rack_ids/supply_rack_ids/replenishment_enabled/reserve_rack_ids/`
`replenishment_delay_s/replenishment_interval_s/replenishment_role/replenishment_module_ids/`
`replenishment_stationary/origin/note`。**没有另一个shot_reload_time**；未知字段明确拒绝。

Gunner增加 `request_load/try_complete_load/loading_capabilities/loading_profile/supply_racks/rack_usable`。
机械停机保持在装弹和剩余进度；已膛弹可按原射击条件射出。补给、选弹、成功发射后的续装均调用中央入口。
AmmoInventory增加按架领取、唯一预留/commit/cancel、预留快照及单架容量校验；膛内来源架和
在装弹回退空间也占容量。补架预留仍属来源架，内部移架不增加supplied；取消/死亡/重置不复制弹。
补架只在射击装填不活跃时推进，移动/火灾/依赖失效取消预留并重置独立等待。

主任务已经统一阶段为 **Recovery → Drive → Loading → Aim → Turret mechanism → Fire**。
这比初稿中的mechanism内计时更精确：同帧新装入的弹先更新弹道定义，再由FireControlState求解，
同时本tick运动和火灾/维修已提交。standalone与VehicleSimulationDriver共用该Loading阶段。

HUD区别人工缺装填手、自动机构故障和供弹架空；Recovery在旧维修顺序末尾加入autoloader；
AmmunitionSupply遵守允许目的架、模块可用性、预留容量以及暂停，补给不能绕过机械停机装膛。
HUD新增三条文字与自动装填机名称均已接入 `assets/localization/zh_CN.json`。
暂停恢复后的静态复核已确认新增类、序列化入口与唯一Loading阶段引用齐备；
默认人工配置允许旧null布局，原四车配置未新增强制装填字段。新增JSON键与差异空白检查已完成。
能力查询当前每次执行绑定校验；性能改动继续暂停，不在本增量调整。

新增 `tests/run_loading_checks.gd`，实际运行62项全部通过，均明确game_rule：完整序列化参考包与反例、
原四车不放宽、6发有限库存/预留/取消/死亡、3/4岗实际Actor与ProjectileManager发射、
人工1/1.6倍率、自动机械实际损伤/自然12秒维修/续装、已膛弹一次发射、储备不能直接装膛、
独立补架后完整射击装填、暂停及Recovery火灾恰在装填完成tick的边界。
首次真实运行57项、11失败，日志位于
`logs/WT-parallel/5787094-resume-wip2/20260912-165906/run_loading_checks_stdout.log`。
随后的诊断确认：`Array(typed_array)`共享底层数组，装配排序追加储备架污染了供弹配置，
布局校验由此报供弹/储备重叠，按规则停止装填。已将排序副本改为`duplicate()`，并加入
实际Actor装配、重配和重置不修改五组配置数组的回归断言。

修复后的真实证据目录为 `logs/WT-parallel/5787094-resume-wip4/20260912-170419/`。
`RESULTS.json`记录Godot 4.7.2的import和`run_loading_checks`均exit_code=0，
装填checks=62、passed=true、script_error=false；stdout有62条PASS、0条FAIL及
`LOADING_CHECKS_PASS`，装填stderr为0字节。已核对14个装填生产/语言/专项文件的当前SHA256
与同目录`SOURCE_MANIFEST.json`一致；该证据对应5787094基线上的冻结未提交工作树，不能冒称提交本身已含改动。

实值诊断确认健康人工4岗与自动3岗均rate=1，人工装填手伤亡后rate=0.625；
自动机构故障时在装弹保持1发、剩余进度约0.3667秒且rate=0，外部补给没有装膛；
自然维修到50完整度后续装恢复。独立补架完成后的总账为4发可用+2发已射=6发外部输入，
没有增加supplied。装配/重配/重置配置不变、有限供弹、已膛弹单次射击、暂停及同tick火灾边界均有PASS断言。
诊断输出保留实际能力、绑定错误、库存与维修状态供审阅。
这证明最小装填前置的工程行为；关联整体回归与人工体验分别记账，不据此标整车或整条WT-027完成。
T-80B、豹2A4继续是candidate_only，未新增可战车型或发布模型。
