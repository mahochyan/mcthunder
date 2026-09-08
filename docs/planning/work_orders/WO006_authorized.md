正式授权 006：有限速度炮弹、重力与连续路径检测。

新建分支：

work/006-projectile-flight

起点：
3650cc510eccbcb2b7791dd8ef59dc8957736517

我已核对远程登记提交和 REVIEW_005_ACCEPTANCE.md。005 签收保持有效，不重新开启其修订循环；本轮不合并 main，不开始 007。

下面是完整工作单及实现方案。原 WO006 的有限速度、重力、沿路径检测、暂停回收等要求继续保留；具体实现与边界以本消息为准。

参考代码与独立数学检查包

关键代码也在正文中，桥接端不需要下载附件才能实施。

一、006 要让玩家真正体验到什么

本轮完成后：

按下开火 → 炮口生成飞弹并开始装填 → 飞弹实际飞行和下坠 → 到达目标后才出现命中反馈 → 碰到第一处装甲或墙停止 → 可以查看该发的飞行时间、路程和接触结果。

不能保留隐藏的即时命中，再播放一条延迟动画。

本轮必须完成	明确留到后续
有限初速、重力、飞行状态	空气阻力、风、旋转稳定等进一步弹道模型
每段完整路径的扫掠查询	任意高速移动目标的双物体连续碰撞
实际撞击时才登记命中	穿透、跳弹、模块损伤
发射扣弹、自然装填、容量限制	配弹界面、弹药架消耗分布、科技树
暂停冻结、重开清理、身份校验	联网与跨平台位级确定性
可操作的弹道训练入口及 HUD	正式历史弹道性能认证

006 先实现“点弹丸沿分段曲线扫掠”。 显示出来的小球大小不参与碰撞，caliber_mm 暂不等于一个实际扫掠球体。这个近似必须写进技术说明，不能宣传成已经完整复现体积炮弹。

历史车辆与未知厚度继续保持研究状态。此阶段命中 UNKNOWN 装甲时，只表示“碰到该几何表面并停止”，不能显示“未击穿某毫米装甲”。

二、先接对现有工程：哪些改、哪些不改

当前工程已经解析了 ShellDefinition，但 VehicleActor 调用的仍是 gunner.setup(tank, turret, weapon)；默认弹种初速为零，Gunner 在发射函数内立即登记命中。006 要连接已有弹种定义，替换即时结算，而不是旁边另做一个只供演示的炮弹脚本。

建议增加：

scripts/projectiles/
    ballistic_math.gd
    projectile_state.gd
    projectile_manager.gd
    projectile_visual.gd

scenes/training/
    ballistics_range.tscn

tests/
    run_projectile_checks.gd

保留并复用：

WorldQueryAdapter
ShotQueryService
ExternalContactSelector
QuerySnapshotBuilder
VehicleCommand / CommandMailbox
TrialHitGate

职责分工：

模块	职责
Gunner	校验发射条件、请求生成、扣弹与装填、发射反馈
ProjectileManager	唯一推进飞弹的物理执行器、逐段查询、终止与回收
ProjectileState	单发炮弹的独立运行数据，不持有车辆 Node
BallisticMath	无碰撞的运动计算与分段规划
ProjectileVisual	读取状态显示位置和已经飞过的轨迹，不决定命中
Main	装配服务、处理终止事件、查找仍有效的目标、重置与场景清理

不要把飞弹挂到射手的 Gunner 下面。 射手被销毁后，已经飞出去的弹丸不应因为父节点释放而凭空消失。管理器由当前战斗场景拥有。

三、配置和状态设计
3.1 弹种配置：使用现有字段，不重复造初速

修改 ShellDefinition：

gdscript
# 现有字段，006 开始真正用于运动。
@export var muzzle_velocity_mps: float = 300.0

# 本轮新增。
@export var gravity_scale: float = 1.0
@export var max_flight_time_s: float = 8.0

运行弹种必须满足：

muzzle_velocity_mps：有限且 > 0
gravity_scale：有限且 >= 0
max_flight_time_s：有限且 > 0

默认 configs/ap_75_shell.tres 同步改为正初速。取消“0 表示即时命中”的运行约定；旧记录可以保留，但不能装配成可发射的战斗弹种。当前这条占位约定确实存在于定义和配置中。

本轮默认值锁定：

参数	006 默认值与口径
初速	300 m/s，TEST ONLY
重力向量	Vector3(0, -9.81, 0) × gravity_scale
最大飞行时间	8 秒模拟时间
最大累计路程	取发射时的 WeaponDefinition.gun_range
单武器初始弹数	30 发，测试配额，不是历史携弹量
活动炮弹上限	64，包含已接收但尚未开始推进的炮弹
每发每物理步子段上限	32

既有默认武器的装填为 2 秒、射程字段为 200 米，本轮保留这些默认值；弹道训练专用配置可增加路程上限，不直接修改所有车辆的共享配置。

gun_range 本轮明确作为累计分段路程上限，不是射手当前位置到炮弹的直线距离。该路程是模拟折线长度，属于有误差界限的近似，不冒充精确曲线弧长。

3.2 弹药：只做必要闭环

在 WeaponDefinition 增加：

gdscript
@export var initial_rounds: int = 30

在 Gunner 中维护：

rounds_remaining
cooldown_left
shots_fired
shot_id

配置可以共享，剩余弹数不能共享。VehicleRuntimeState 和 HUD 只读取显示快照，不能另外维护一个可修改的弹药账本。

合法发射扣一发；拒绝发射不扣弹、不装填、不增加射击计数。

本轮没有自动补弹。整场重开恢复测试配额；普通暂停、F6 打开关闭不能补弹。

3.3 ProjectileState

建议为 RefCounted，至少保存：

projectile_id                       # 管理器生成的单调编号
round_id
shooter_id
shooter_life_id
shooter_team_id
shot_id
shell_id
seed                                # 预留；006 不加入随机散布

born_physics_tick
position_world
previous_position_world
velocity_world
gravity_world

age_s
travelled_m
max_age_s
max_distance_m
status                              # pending / flying / terminal
terminal_reason

发射时冻结初速、重力、路程上限等数值，不让飞到一半的炮弹突然读取后来修改的配置。

初速度本轮采用：

velocity_world
= 真实炮管单位方向 × muzzle_velocity_mps
+ 发射瞬间 tank.velocity

只继承车体平移速度；炮口因车体／炮塔旋转产生的切向速度暂不实现，作为明确的弹道近似记录。炮弹离膛后不再读取相机目标，也不追踪炮管方向。

四、发射与物理执行顺序
4.1 try_fire() 的返回值变成“是否成功发射”

新流程：

检查暂停／实体／输入
→ 检查冷却、恢复宽限、火键门、弹药
→ 保留炮根—炮口遮挡检查
→ 冻结真实炮口、方向、速度、身份
→ 管理器接收该发
→ 扣弹、开始装填、增加编号与发射次数
→ 发射特效
→ 返回 true

这里不查远处目标并登记命中。

管理器接收接口建议：

try_spawn(spec) → {ok, projectile_id, reason}

它在当前调用中只校验、复制数据、占用容量和加入待推进集合，不推进、不撞击、不发命中信号。

只有返回 ok=true 后，Gunner 才一次性提交扣弹、冷却和计数。这个过程不使用 await，也不在中间触发可能重入开火的外部信号。

必须拒绝：

invalid_shell
invalid_spawn
no_ammo
cooldown
barrel_occluded
projectile_capacity
duplicate_launch

达到容量上限时不能删除一发旧炮弹来“腾位置”，也不能播放成功开炮却没有实际弹丸。

4.2 明确新炮弹何时开始推进

出生所在物理 tick 不推进；下一物理 tick 推进第一个 delta。

这样 try_fire() 返回时一定没有提前命中，也不会因管理器节点位置不同而让新炮弹多跑一步。

tick N：命令消费 → 接收发射，age=0，目标未加分
tick N+1：飞弹第一次推进
后续 tick：逐段检测，接触后才终止和反馈

碰撞时刻在子段内估算，事件会在所属物理步送达。记录 flight_time_s，不要把日志写出时间当成飞行时间。

4.3 唯一推进入口与装填时钟

ProjectileManager 显式设置：

gdscript
process_mode = Node.PROCESS_MODE_PAUSABLE
process_physics_priority = 100

车辆保持现有命令执行方式，管理器在本步车辆更新之后运行。Godot 的物理回调按 process_physics_priority 从小到大执行；物理空间查询也应在物理阶段进行。
Godot Engine documentation
+1

当前冷却和恢复宽限还在 Gunner 的 _process() 中扣减。006 将其迁到一个：

Gunner.advance_timers(delta)

由 VehicleActor._physics_process() 在消费命令前调用一次，删除原 _process() 中的相同扣减，不再从其他回调重复调用。画面更新只保留表现工作。

这一处属于本单授权的时钟迁移，不重写已有驾驶与瞄准公式。

五、重力与连续路径：关键参考代码

无空气阻力、恒定重力下，每个子步采用：

p
1
	​

=p
0
	​

+v
0
	​

h+
2
1
	​

gh
2
,v
1
	​

=v
0
	​

+gh

碰撞查询使用 p0 → p1 的整条有限线段，不只检查终点小球。

对于恒定加速度，子步曲线与端点弦线的最大偏差为：

8
∥g∥h
2
	​


据此，本轮选择单段长度不超过 5 米、曲线偏差不超过 2 毫米的分段策略。这是本项目的数值精度设定，不是历史武器参数。

下面代码已经附在参考包内。我运行了对应的 107 项独立 Python 数学检查；没有在审核环境解析或运行 Godot，执行端仍须完成 GDScript 解析和生产接入验证。

gdscript
class_name BallisticMath
extends RefCounted
## Constant acceleration; point-projectile motion.
## Reference implementation, not Godot-tested in the review environment.

const MAX_CHORD_M := 5.0
const MAX_SAG_M := 0.002
const MAX_SUBSTEPS := 32
const TIME_EPS := 1.0e-10


static func advance_free(
		p: Vector3,
		v: Vector3,
		a: Vector3,
		dt: float
	) -> Dictionary:

	if not p.is_finite() or not v.is_finite() or not a.is_finite():
		return {"ok": false, "reason": "non_finite_state"}
	if not is_finite(dt) or dt < 0.0:
		return {"ok": false, "reason": "invalid_dt"}

	var next_p := p + v * dt + a * (0.5 * dt * dt)
	var next_v := v + a * dt

	if not next_p.is_finite() or not next_v.is_finite():
		return {"ok": false, "reason": "state_overflow"}

	return {
		"ok": true,
		"position": next_p,
		"velocity": next_v
	}


static func plan_times(
		v: Vector3,
		a: Vector3,
		dt: float
	) -> Dictionary:

	if not v.is_finite() or not a.is_finite():
		return {"ok": false, "reason": "non_finite_state"}
	if not is_finite(dt) or dt <= 0.0:
		return {"ok": false, "reason": "invalid_dt"}

	var speed := v.length()
	var acc := a.length()
	var path_bound := (speed + acc * dt) * dt
	var sag_need := dt * sqrt(acc / (8.0 * MAX_SAG_M))

	var needed := maxf(
		1.0,
		maxf(path_bound / MAX_CHORD_M, sag_need)
	)

	if not is_finite(needed) or needed > float(MAX_SUBSTEPS):
		return {"ok": false, "reason": "substep_budget_exceeded"}

	var count := maxi(1, int(ceil(needed)))
	var times := PackedFloat64Array()

	for i in range(count + 1):
		times.append(dt * float(i) / float(count))

	# Split at minimum speed. In a vertical turnaround this prevents
	# equal endpoints from concealing an out-and-back path.
	var a2 := a.length_squared()
	if a2 > 0.0:
		var turning_t := -v.dot(a) / a2
		if turning_t > TIME_EPS and turning_t < dt - TIME_EPS:
			var exists := false
			for t in times:
				if absf(t - turning_t) <= TIME_EPS:
					exists = true
					break
			if not exists:
				times.append(turning_t)
				times.sort()

	if times.size() - 1 > MAX_SUBSTEPS:
		return {"ok": false, "reason": "substep_budget_exceeded"}

	return {"ok": true, "times": times}

times 是该物理步内的子步边界。例如 [0, h, 2h] 表示依次推进两个子步，不是每次重新推进完整 delta。

超出子步预算要明确终止为未决／预算错误，不允许少查后半段却仍把炮弹移动到完整终点。

六、ProjectileManager 的推进算法
6.1 每个物理步只取一次当前车辆快照

管理器在物理阶段取得当前车辆布局与姿态快照，供本步飞弹查询使用。下一物理步重新采样，不使用开火瞬间保存的整车快照一直算到落点。

本轮把目标几何视为在单个物理步内固定。这能支持目标在飞行期间移动后，后续步看到新位置；但不保证检测所有“目标在一个 tick 内高速横穿弹道”的情况。

连续路径检测是针对炮弹的扫掠，不等于已经实现双方完整连续碰撞。

6.2 每发的逐段处理

建议接口：

advance_projectile(state, delta, snapshots, world_space)
finish_once(projectile_id, reason, terminal_data)
cancel_all(reason)
cancel_by_shooter(shooter_id, shooter_life_id, reason)

执行顺序：

检查仍活动、轮次有效、不是出生当步
→ 用剩余寿命裁短本步时间
→ plan_times()
→ 按顺序处理每个子段
    → advance_free() 求候选终点
    → 必要时按剩余路程裁短子段
    → WorldQueryAdapter 查询该段
    → ShotQueryService 查询该段
    → ExternalContactSelector 选择外部接触
    → 根据选择结果推进或终止

四种结果：

选择结果	管理器行为
vehicle	停在装甲接触点，生成一次终止记录
world	停在世界接触点，生成一次终止记录
miss	接受该段运动结果，继续下一段
unresolved	停止模拟，标记未决，不计命中，不假装飞过

模块和乘员仍只是内部几何候选，不参与本轮外部停止或计分。 本轮碰到装甲就停，不查询出一串模块之后直接把它们都算作受损。

自身排除使用发射者的：

shooter_id + shooter_life_id

不能按车型排除，也不能把首次碰过的整辆目标永久放进排除列表。

6.3 接触时间与限制边界

如果选中接触在当前子段的比例为 t：

本子段接触用时 ≈ 子段时长 × t
接触位置 = 查询返回的 point_world
接触速度 = 子段起始速度 + gravity × 本子段接触用时

时间是分段近似值，位置必须使用本次接触点；不要再用另一个公式生成不同的“爆点”。

剩余路程不足以覆盖整段时，先裁短线段，再查询。不得先查询完整越界段、命中上限外目标，然后才宣布超射程。

接触恰好位于寿命／距离端点时，先处理该合法端点接触，否则到期终止。近零位移段不能拿去触发零长度射线错误；继续更新时间与速度，转折情况按分段结果处理。

七、事件、计分与生命周期
7.1 终止事件必须一次且完整

建议终止记录：

projectile_id
round_id
shooter_id / shooter_life_id / shooter_team_id
shot_id / shell_id
reason
flight_time_s
travelled_m
impact_point
impact_velocity
target_id / target_life_id           # 撞到车辆时
surface_id
query_id / physics_tick

reason 至少区分：

impact_vehicle
impact_world
expired_time
expired_distance
unresolved_query
cancelled_reset
cancelled_scene_exit

finish_once() 必须先标终止、移出活动集合，再通知监听者。这样命中监听者触发重置时，不会把同一发再结算一次。

Main 收到有效车辆撞击记录后，核对当前轮次及目标 entity_id + life_id，再调用现有 register_hit()，由 TrialHitGate 继续执行任务身份与去重规则。

世界对象只能在撞击时立即查验并反馈；长期记录不保存活的 collider Node。目标已经消失时不重新找一辆同名新车冒充旧目标。

7.2 射手和目标的身份在不同时刻确定

发射时冻结射手身份，撞击时取得目标身份。

射手离开场景、转动车体、切换控制者，都不能改变已飞弹的来源。射手实体销毁后，飞弹可以继续飞，由场景管理器持有；最终能否计入当前任务仍由轮次和身份规则决定。

如果新弹已经发射，旧弹随后撞击，HUD 不能把旧弹结果错标到新弹。至少按 projectile_id 保存最近结果，不再仅靠一个无身份的字符串串接异步反馈。

7.3 暂停、F6 和重置规则
操作	明确行为
Esc／失焦暂停	飞弹位置、速度、年龄、路程及装填冻结；恢复不补算现实中经过的时间
打开 F6	不生成新发射；已有飞弹继续运行，正常撞击可以发生
关闭 F6	维持火键释放门；不能补发面板点击
整场重开	先取消全部活动／待推进飞弹，再推进轮次、复位车辆和任务
单车重置	取消该车发出的飞弹、复位本车弹药；不取消其他车辆的飞弹
切换训练／普通场景	作为新局处理，清空飞弹与临时视觉，不携带旧轮次命中
场景销毁／初始化失败	清理管理器及视觉，旧回调不得访问已释放对象

当前 Main 使用 ALWAYS，而实体使用 PAUSABLE。新增管理器不能无意继承 ALWAYS，否则暂停菜单打开时仍会飞行。 Godot 的处理模式会决定暂停期间哪些节点继续执行，管理器必须显式设为 PAUSABLE。
Godot Engine documentation

特别注意：“F6 查询不消耗弹药／不计分”与“F6 打开期间任何计数都不得变化”不再等价。 若面板打开前已经发射，弹丸到达目标后正常计分不是面板副作用。相关测试应使用无在飞弹的前提，或追踪具体发射 ID。

八、玩家界面和弹道训练入口
8.1 HUD 同期补齐，不只有日志

新增或调整：

AMMO: 29/30
RELOAD: 1.4 s
PROJECTILES: 1
LAST SHOT: #17 IN FLIGHT
LAST IMPACT: #17 VEHICLE / 0.50 s / 150.01 m

拒绝发射要显示具体原因，如 NO AMMO、PROJECTILE LIMIT、BARREL BLOCKED。

当前炮管直线查询标记继续可用，但标明：

GUN LINE — NOT BALLISTIC IMPACT PREDICTION

它表示炮管直线指向，不是考虑重力后的预计落点。本轮不做自动抬炮或落点辅助，避免又创建第二套“假弹道”。

8.2 视觉只显示实际飞过的部分

飞弹模型由状态位置驱动。轨迹线只连接已经推进过的采样点，不能开炮瞬间画到未来目标。

最多保存每发最近一小段尾迹，终止后的效果设置有限寿命。关闭特效不能改变命中结果，射手移动也不能拖动已经飞出的轨迹。

允许渲染插值，但禁止通过视觉节点位置反向决定碰撞。

8.3 一个小型、可进入的训练场景

在暂停菜单加入“弹道训练”入口，打开 ballistics_range.tscn；训练中提供“返回靶场”。两次切换都按新局处理，先清理飞弹，不承诺保留上一局位置和任务进度。

复用现有车辆、Gunner、管理器和查询系统，不复制一套训练专用射击代码。

训练场设置互不遮挡的近、远射道，主要接触面距离真实炮口分别约 30 米、150 米，确保地面和旧围墙不会先挡住射线。给水平发射留足高度与目标尺寸。

在射手静止、水平初速 300 m/s 的数学基准下：

距离	飞行时间	下坠量
30 m	0.10 s	0.04905 m
150 m	0.50 s	1.22625 m

实际场景记录必须按炮口到接触平面计算，不拿车体中心距离冒充。

不强制本轮录制视频；但演示日志要包含发射、飞行中、撞击的不同时间点，静态截图不能独自证明飞行过程。

九、验收条件与旧测试迁移
9.1 原 T006-01～05 保留并具体化
编号	必须实际验证
T006-01 自由飞行	无碰撞时，从 (0,3,0) 以 (300,0,0) 发射，0.5 秒后位置约 (150,1.77375,0)，速度约 (300,-4.905,0)；位置容差 0.001 m
T006-02 高速薄板	测试速度 1200 m/s，60 Hz 一步跨越薄板，完整线段仍检出；前板后的第二目标不被本轮击中
T006-03 渲染帧率	相同发射状态、静态目标、固定 60 Hz 物理步，在不同渲染限帧下，接触点差异 ≤0.005 m、记录飞行时间差异不超过一个物理步
T006-04 生命周期	100 次暂停／恢复、20 次整场重置，无额外扣弹、旧命中、飞弹或视觉残留
T006-05 炮口权威	相机方向故意与炮管错开，只按真实炮口位置和炮管方向飞行；贴墙遮挡继续成立

再补四组必要集成条件：

组	条件
发射原子性	try_fire() 返回后目标尚未加分；接收成功只扣一发；容量满、无弹、冷却与炮管遮挡不扣弹
实际撞击	首处装甲／世界接触只终止一次；模块候选不计分；不完整查询终止为未决
身份与边界	旧轮次飞弹不能新局计分；射手销毁不崩溃；目标同名重建不继承旧命中；寿命／路程上限外无命中
动态采样	发射后、到达前目标移走，后续查询看到新位置；不以开火时保存的目标位置制造追踪弹

高速度薄板测试要把板放在采样端点之间，例如起点前方 2.3 米，而不是恰好放在端点上。

9.2 旧测试允许迁移时序，不允许保留即时伤害

建立 docs/TEST_MIGRATION_006.md，记录：

旧测试编号
原行为要求
原来的即时断言
新的发射／飞行／撞击断言
迁移原因

典型变化：

旧断言	006 的等价行为
调用开火后 B 立即加 1	开火后先不加分；真实模拟推进到撞击后加 1
一帧内已有目标反馈	先有发射反馈，后有带同一 ID 的撞击反馈
第二炮自然装填后命中	自然装填结束才能发射；第二发也必须实际飞到目标
全长示踪线等于射程或命中点	尾迹只覆盖已飞路段，最终位置等于真实接触点

等待采用物理步数或模拟年龄，并设置超时。不清零冷却、不手动移动飞弹到终点、不让测试调用一个隐藏的即时命中入口。

旧靶子受下坠影响需要调整时，记录实际几何与理由；不把靶板放大到足以掩盖炮口或坐标错误。

9.3 人工验收合并

本轮人工流程可合并为：

发射近靶和远靶，观察反馈延迟；飞行中暂停再恢复；飞行中重开；贴墙开炮；打开 F6 后关闭，确认鼠标与开火正常。

U003～U005 保留项一起观察即可，不要求回旧版本补历史截图。未做的保持 NOT_RUN；历史原页转存不阻塞 TEST ONLY 弹道开发。

十、工具流程与证据

运行入口：

<godot> --headless --path <project> --import

<godot> --headless --path <project> -s res://tests/run_projectile_checks.gd

<godot> --headless --path <project> -s res://tests/run_query_checks.gd

<godot> --headless --path <project> -s res://tests/run_layout_checks.gd

<godot> --headless --path <project> -s res://tests/run_checks.gd

新增 --ballistics-demo，走同一训练装配与生产发射路径：

<godot> --path <project> --resolution 1280x720 --max-fps 30 -- --ballistics-demo

<godot> --path <project> --resolution 1280x720 --max-fps 144 -- --ballistics-demo

确认本地 --help 支持对应选项。--max-fps 是渲染限帧；不要用会关闭实时同步的 --fixed-fps 来冒充同一项测试，也不要同时改变物理频率。
Godot Engine documentation
+1

每次保存：

完整源码 SHA
引擎 --version
实际命令
固定物理频率
请求与实际渲染帧率记录
随机种子／固定测试状态
stdout、stderr、真实退出码、是否超时

本轮修正运行器退出码采集，但不补造 005 的旧值。 使用等待真实进程结束的运行方式取得返回码，PASS 文本、退出码和脚本错误分别检查；超时不能算通过。沿用已有工具语言即可，不因此更换开发环境。

证据目录：

logs/006/<tested_sha>/
docs/evidence/006/<tested_sha>/<resolution>/

演示至少留下“刚发射未命中、实际飞行中、接触后、暂停冻结、重开已清空”的记录。画面非空与真实玩法目视继续分开。

十一、实施顺序与正式授权
子提交	范围
006-a	弹种与弹药配置、独立状态、运动函数、管理器接收／容量机制
006-b	固定物理步推进、005 查询接入、一次性撞击与身份分发
006-c	暂停／重置／销毁、装填时钟迁移、HUD 与训练入口
006-d	旧测试迁移、弹道回归、双分辨率演示、交付文档

可以逐步提交，但不需要每一步再次请求授权。最终交付：

docs/DELIVERY_006.md
docs/TEST_MIGRATION_006.md
docs/ARCHITECTURE.md 增量
新增代码、配置、训练场景
实际测试日志与必要画面

DELIVERY_006.md 开头先说明玩家如何进入、能看到什么、仍有哪些近似，再列测试数量。

最终执行授权：

CURRENT_ORDER = 006
STATUS = authorized

NEW_BRANCH = work/006-projectile-flight
BASE_SHA = 3650cc510eccbcb2b7791dd8ef59dc8957736517

005 accepted 保持有效；本消息正式授权006。
先检查实际HEAD、工作区与固定Godot版本。
同名分支若存在先检查，不覆盖。

范围：
有限速度点弹丸、重力、分段完整路径查询；
实际撞击才反馈；首处装甲/世界接触停止；
最小弹药闭环、容量与寿命/路程限制；
暂停/重开/销毁清理；HUD与弹道训练入口。

允许迁移：
ShellDefinition的零初速占位约定；
Gunner由即时结算改为发射；
装填/宽限改为单一物理时钟；
旧即时命中测试改为等待真实飞行。
迁移必须保留原行为要求，并记录差异。

复用005服务，不在弹丸或UI中重新实现命中规则。
没有隐藏即时命中，没有视觉决定判定。
未知历史数据继续UNKNOWN。

不实现穿透、跳弹、损伤、AI、联网或007。
不重开已签收阶段，不强推、不改写历史、不合并main。

完成006-a/b/c/d后统一交付并停止。
源码SHA、证据提交与交付HEAD分别记录。

现在开始 006。完成标准是“这一炮确实飞过去，碰到东西才发生反馈”，而不是把原来的即时射击加上一个会移动的小球。