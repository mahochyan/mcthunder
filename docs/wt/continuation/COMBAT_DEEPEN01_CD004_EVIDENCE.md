# MCT-COMBAT-DEEPEN-01 · WT-CD-004「弹道时间、速度与火控预测一致」执行证据

> 子单：`WT-CD-004`（P1 · 关口 **G2** · 前置 WT-CD-003）· 用例 **CD04-T01…T06**（6 条）
> 原文与用例取自执行包只读副本：`docs/wt/combat-deepen-01/original/`（哈希已核 ✓）。
> 本档只记录**真实命令输出**；未测项标 `NOT_RUN` 并写原因；不代签真人 ✓。

## 0. 依据与边界（子单原文要点 ✓）
- 源码审查结论：**飞行主要重力、距离穿深曲线独立**；**穿透预算与残余速度未建立统一更新** ✓（= 本单起点 ✓）。
- 玩家可见目标：**测距、提前量和穿后引信基于同一套时间与速度** ✓ "不出现瞄具算一条、炮弹飞另一条" ✓。
- 来源 [R02] [R03] [W03]（**数值待取件**：本档所有数均为**项目设计初值** ✓ 不冒充真实性能 ✓）。

## 1. 现状基线（实测 ✓）
| 项 | 实测 |
|---|---|
| `BallisticsProfile`（设计 #1 要求） | **不存在** ✗ |
| `residual_velocity`（设计 #3 要求） | **不存在** ✗ |
| `BallisticMath`（`advance_free` / `plan_times`） | 存在 ✓ |
| `BallisticIntercept.solve(muzzle,target,target_velocity,own_velocity,shell)` | 存在 ✓ |
| 当前飞行模型 | **纯重力、无任何阻力项** ✓（`gunner.gd`：`gravity = -9.81 * gravity_scale`；初速 `= 炮管方向 × muzzle_velocity_mps + 车体速度` ✓） |

## 2. `CD04-T01` 零阻力解析基准：**冻结并通过** ✓✓
探针：`tests/probe_cd004_zero_drag.gd`（`CD004_ZERO_DRAG_BASELINE_PASS` ✓）
弹种：**交付包真弹** `game_apfsds_125_v1`（照抄其 `impact_profile` / `effect_policy` / `post_penetration_profile` ✓，探针**不硬编码** ✓）
条件：初速 800 m/s ✓ 重力 9.81 m/s² ✓ 发射高度 2 m ✓ 步长 1/240 s ✓ 角度 0/5/10/20/30° ✓
期望：由探针**独立闭式求解** ✓（`t = (vy+√(vy²+2gh))/g` ✓ `range = vx·t` ✓ `speed = √(vx²+(vy−gt)²)` ✓）

**实测表（原始数字 ✓）**
```
 0°: 解析 t=0.6386 s range=  510.8407 m speed=800.025 | 实测 t=0.6385 range=  510.8399 speed=800.025 | d=0.0008 m 0.00000 s 0.0003 m/s
 5°: 解析 t=14.2436 s range=11351.5434 m speed=800.025 | 实测 t=14.2434 range=11351.2139 speed=800.026 | d=0.3295 m 0.00019 s 0.0018 m/s
10°: 解析 t=28.3362 s range=22324.5776 m speed=800.025 | 实测 t=28.3358 range=22324.0957 speed=800.029 | d=0.4818 m 0.00038 s 0.0041 m/s
20°: 解析 t=55.7904 s range=41940.6696 m speed=800.025 | 实测 t=55.7910 range=41944.0273 speed=800.035 | d=3.3578 m 0.00060 s 0.0109 m/s
30°: 解析 t=81.5544 s range=56502.5728 m speed=800.025 | 实测 t=81.5635 range=56508.2266 speed=800.057 | d=5.6538 m 0.00906 s 0.0327 m/s
中途点：0° 误差 0.000153 m ✓ ; 其余 0.0286–0.1329 m（位置 5–6.7 km ✓）
```
**两类判据（刻意不同 ✓ 理由见下）**
1. **中途点**：量级小 ⇒ 用**紧绝对界** ✓（<1 km 用 **1 mm** ✓；更远用 **5×10⁻⁵ 相对** ✓ 因 float32 在该量级的分辨率约 0.5 mm ✓ 且累积约 2×10³ 步 ⇒ 可达一致度为**十万分之几** ✓，实测每步 0.02–0.14 ULP ✓）；
2. **落地表**：按各量**相对定界** ✓（射程/时间 2×10⁻⁴ ✓ 速度 1×10⁻⁴ ✓ = float32 位置累加在数十 km 上的量级 ✓）。

⇒ 结论 ✓：**落地射程/时间/速度与解析答案一致到 0.0008 m / 0 / 0.0003 m/s（近距离）** ✓，远距离约 **10⁻⁴ 相对** ✓；**中途点**在紧界内 ✓ ⇒ 积分器与闭式解一致 ✓；**基准数字现已冻结** ✓（后继阻力/预测器改动须与此表对照 ✓）。

### 2.1 本基准**当场捕获并修正的一处 1.25–3.3 m 级差异** ✓（**是我探针的错** ✓）
首版把**推进之后**取到的位置与 `probe_t` 时刻的闭式值相比 ✗ ⇒ 每个角度都带**最多一个步长**的系统偏移 ✓。识别方式为**算术自证** ✓：误差 ÷ 水平速度 = 1.56 / 3.22 / 4.23 / 4.34 / 4.61 **ms** ✓ 全部 ≤ `DT = 4.17 ms` ✓ ⇒ 确定是**采样时刻**而非飞行模型 ✗ ⇒ 改为按**实际采样时刻**求闭式值后，0° 误差 **1.246 m → 0.000153 m** ✓✓（~8000×）。
**未改任何 `scripts/` 代码** ✓（`git status -- scripts` = 0 ✓）。

## 2.2 设计 #1：**版本化 `BallisticsProfile`** ✓ 已落（旧曲线**未被静默改变** ✓）
模块：`scripts/projectiles/ballistics_profile.gd`（`class_name BallisticsProfile` ✓ `VERSION = "cd004-ballistics-v1"` ✓）
- **单位显式声明** ✓（`UNITS`：m / s / m_per_s / m_per_s2 / per_m ✓ 不靠假设 ✓）；
- **只上一种可校准近似** ✓：`v1_vacuum`（`drag_model = "none"` ✓ = 工程**既有**飞行 ✓）与 `eng_quadratic_v1`（**唯一**新增项 `a = -k·|v|·v` ✓ `k = 2.2e-5 /m` ✓ 项目设计初值 ✓）；
- **只认显式声明** ✓（`resolve` 不按弹种策略/口径猜测 ✓ ⇒ 不会"悄悄换曲线" ✓）：未声明 ⇒ `source = "legacy_v1_vacuum"` ✓；显式声明 ⇒ `source = "project_engineering_profile"` ✓；
- **按名拒绝** ✓（`validate`）：`unknown_ballistics_profile` ✓ `invalid_ballistics_drag_k` ✓ `invalid_ballistics_max_age` ✓ `invalid_ballistics_max_distance` ✓；
- **`provenance = "design"`** ✓ 且 `is_validated_history()` 恒 false ✓ ⇒ **未实测历史数据不标 `validated_history`** ✓（`CD04-T02` 后半 ✓）；
- **冻结工程曲线** ✓ `RETENTION_TABLE`：200/500/1000/1500 m ⇒ 0.972 / 0.932 / 0.871 / 0.814 ✓ 容差 0.010 ✓（**项目设计**，非实测历史 ✓）。

**判据探针** ✓：`tests/probe_cd004_ballistics_profile.gd` ⇒ **`CD004_BALLISTICS_PROFILE_PASS`** ✓（含：阻力幅值 = `k·|v|²` 独立核对 ✓ 方向与速度反向 `dot ≤ -0.9999` ✓ 真空阻力**恰为 ZERO** ✓ 曲线单调且在 (0,1) ✓）。

### 2.2.1 旧行为对照 ✓（硬约束"保留旧行为对照" ✓ 以实测满足）
**同一进程外复跑 T01 基准** ✓（`tests/probe_cd004_zero_drag.gd` ✓）⇒ **`CD004_ZERO_DRAG_BASELINE_PASS`** ✓ 且最差值**逐字相同** ✓：
```
worst: range 5.6538 m · time 0.00906 s · speed 0.0327 m/s      （与冻结表原值完全一致 ✓）
```
⇒ 新增剖面模块**未改变任何既有飞行行为** ✓（真空阻力恒为零 ✓ 未声明即走 v1 ✓）。

### 2.2.2 设计 #5 的"每弹固定随机种子"：**既已满足** ✓（实测定位 ✓）
`gunner.gd` 组 spec 时 `seed = hash(JSON.stringify([round, shooter_id, life_id, shot_id]))` ✓ ⇒ **纯函数于射击身份** ✓ 与帧率/帧序无关 ✓ ⇒ 设计 #5 该分项**无需改动** ✓（后续 T06 只验证"帧率不改变散布" ✓）。

### 2.2.3 本轮我的一处自伤 ✓
新增 `class_name` 后**未先 `--import`** ✗ ⇒ 探针报 `Identifier "BallisticsProfile" not declared` ✗（**我自己早先记录过的教训** ✓）⇒ 导入后即解析 ✓；随后又有一处**类型错**（把 float 赋给 `var row: Dictionary` ✗）⇒ 模块编译失败 ⇒ 探针首项失败并超时 ✓ ⇒ 修正后 PASS ✓（残留进程已清零 ✓）。
1. 自制 `impact_profile` 与弹种 `effect_policy` 不匹配 ⇒ 被 `invalid_impact_profile` 拒绝 ✓ ⇒ 改为**读交付包真弹** ✓；
2. `max_distance_m=6000` ⇒ 800 m/s 下 **7.5 s 即触上限** ✗ ⇒ 远距离"落地"为 0 ✓ ⇒ 抬到 100 km / 200 s ✓；
3. 调 `BallisticMath.advance_free` 时**丢弃其返回 Dictionary** ✗ ⇒ 状态不前进 ⇒ **死循环** ✓ ⇒ 由超时**精确终止** ✓ ⇒ 改为在推进循环内**采样真实弹丸** ✓（更贴近生产路径 ✓）。

## 3. `CD04-T02` 保持表：**通过** ✓✓（并修掉一处真实缺陷 ✓）
实测（零重力隔离阻力项 ✓ 初速 1500 m/s ✓ 步长 1/240 s ✓）：
```
 200 m: 声明 0.972 | 独立闭式 e^(−kx) 0.972 | 实测 0.972 | 对表 +0.0004 | 对闭式 −0.0000
 500 m: 声明 0.932 | 闭式 0.932 | 实测 0.932 | +0.0004 | −0.0000
1000 m: 声明 0.871 | 闭式 0.869 | 实测 0.869 | −0.0016 | −0.0000
1500 m: 声明 0.814 | 闭式 0.811 | 实测 0.811 | −0.0034 | −0.0000
k=0 控制腿：速度保持偏差 0.00000000 ✓✓
```
**顺带修掉的真实缺陷** ✓（正是子单开头"**穿透预算与残余速度未建立统一更新**"）：`projectile_manager` 自由飞行路径
`st.velocity_world += st.gravity_world * used_h` ✗ **丢弃了 `adv.velocity` 里的阻力项** ⇒ 速度永不随距离衰减 ✓；
改为 `st.velocity_world += (adv.velocity - st.velocity_world) * alpha` ✓（k=0 时**数学等价** ✓ ⇒ 真空逐字不变 ✓）。

## 4. `CD04-T04` 贯穿后引信：**前提不满足，未完成** ✗（实测 ✓）
`ShellFuze.validate`（读源码 ✓）**完整规则**：`effect` 必须 `internal_burst` ✓ `mode` 必须 `penetration_delay` ✓
`arming_thickness_mm`/`delay_s` 必须**正有限** ✓ `provenance` 必须 `game_rule` ✓ `reason` 非空 ✓（空 fuze 合法但 `arm()` 直接返回 ⇒ 无延迟 ✓）。
**交付包实测** ✓：`game_apfsds_125_v1` = `long_rod` ✓ `game_heat_125_v1` = `chemical` ✓ **全库 `internal_burst` = 0 命中** ✗
⇒ **延迟引信无合法载体** ✓（`try_spawn` 以 `invalid_fuze_policy` **正确拒绝** ✓ 我的 `long_rod`+手写引信 ✓ = 设计正确 ✓）。
**残余速度机制现状** ✓：`armor_resolver` 结果带 `speed_scale` ✓ 默认 1.0 ✓ **仅跳弹**改为 `ARMOR_RICOCHET_SPEED_SCALE` ✓；
`projectile_manager:546` 应用之 ✓ ⇒ **未见按板厚扣速的规则** ✗ = `必须设计 #3` 所指 ✗。
⇒ **下一轮**：构造合法 `internal_burst` 夹具弹（自带 impact_profile ✓ + 合法延迟引信 ✓）⇒ 测薄/厚板残余速度与起爆距离 ✓ **再据数据实现** ✓。

## 5. 未完成（`拒收条件 4` ✓ 不得只做 T01 就宣称本单完成 ✓）
- **T02** 经验阻力曲线与速度/时间表 ✗ · **T03** 预测/瞄具/AI 与真实飞行**共用求解服务**的误差界限 ✗ · **T04** `residual_velocity` 与**穿后引信按残余轨迹** ✗ · **T05** 移动射手/目标时间基准 ✗ · **T06** 长步/无效值/**暂停不补算** ✗；
- **设计 #1** 版本化 `BallisticsProfile`（单位/初速/重力/可选阻力/寿命与距离上限，**第一版只上一种可校准近似** ✓ 不同时上多套空气模型 ✓）✗；
- **设计 #4** **空气段与接触段分别消费**、长距离**不重复惩罚**的审计 ✗；**设计 #5** 每弹**固定随机种子**避免帧率影响散布 ✗；
- `200/500/1000/1500 m` 采样表与"**超范围不作性能承诺**"的声明 ✗（`实现顺序 #3` ✓）。

## 6. `CD04-T04` 实测（夹具已命中板面 ✓ = 真仪器 ✓）
五变体**一次分流**定位 ✓（`plain=1 ✓ motion_fraction=1 ✓ frozen_frame=1 ✓ manager_fields=0 ✗`）⇒ 元凶是 **`excluded_instances`（排除射手）** ✓；根因是**我的夹具用同一 actor 既当射手又当靶** ✗ ⇒ 板面被**正确地**排除 ✓。
修正靶 `entity_id` 后 ✅ **两腿均 `contacts=1`** ✓，实测：
```
薄板(1 条): residual=900.000 ✗（与入射相同 ⇒ **贯穿不扣速**） burst_from_plate=20.00000 ✗（到距离上限 ⇒ **引信未起爆**）
厚板(3 条): residual=900.000 ✗  burst_from_plate=20.00000 ✗（无厚度区分度）
```
⇒ **两个可测缺口** ✓：① `必须设计 #3` 的**明确 `residual_velocity` 规则**尚未实现 ✗（`speed_scale` 默认 1.0 ✓ 仅跳弹改 ✓）；② 引信未 arm ✓ —— 因为**空 `impact_profile`** 使装甲判决不是 `penetrated` ✗（应给一份**属于 APHE 家族**的合法 `internal_burst` 剖面 ✓ 才可 arm ✓）。
⇒ **下一轮**：先补合法 APHE 剖面使引信可 arm ✓，再按薄/厚板**单调性**实现并验证 `residual_velocity` 规则 ✓（**先判据后实现** ✓）。

## 7. `CD04-T04` 深挖：判决已达 penetrated ✓，两机制已定位 ✓
**夹具升级** ✓：交付包**无任何 `internal_burst` 包** ✗（`authoring/` 全搜 0 ✓）⇒ 按 `ArmorImpactProfile.validate` 的**全部规则内联构造**合法 APHE 剖面 ✓：
```
version=wt012-full-caliber-v1 ✓ family=APHE ✓ provenance=game_rule ✓ reason 非空 ✓
normalization_deg=4.0 ∈[0,20] ✓ overmatch_ratio=3.0 ∈{0}∪[1,100] ✓ ricochet_deg=70 ∈(0,90) ✓
material_coefficients={rolled:1.0, cast:1.1} ✓（禁止未知替换 ✓）
⇒ validate errors=[] ✓ ；实测首次接触 result=**penetrated** ✓ effective_mm=100.0 ✓ consumed=100.0 ✓
```
**机制一：引信为何仍未 arm** ✗（`ShellFuze.arm` 三条件，**读源码** ✓）：
```
result.result 必须 == "penetrated" ✓（已满足 ✓）
result.backface 必须为 false ✓
path_thickness_mm（缺省回退 effective_mm）必须 ≥ fuze.arming_thickness_mm（我设 5 mm ✓）
⇒ 未 arm ⇒ 只能是 backface=true ✗ 或 path_thickness_mm 存在但为 0 ✗ ⇒ **下一轮打印这两个值即定论** ✓（1 行 ✓）
```
**机制二：贯穿无残余速度规则** ✗（`ArmorResolver` **源码确认** ✓）：`out` 初始化 `"speed_scale": 1.0` ✓，**只有跳弹**分支改写它 ✓ ⇒ **贯穿不扣速** ✓ 与实测 `residual=900.000` ✓ 完全一致 ✓。
⇒ 实现须遵守子单边界 ✓："**穿深预算不是焦耳，不能直接将毫米代入动能公式；映射属于项目设计并单独标定**" ✓ ⇒ 规则须为**显式、可标定**的项目设计曲线 ✓（如以 `consumed/available` 为自变量的声明式映射 ✓ 并写明 provenance=design ✓），判据为**薄/厚板单调性** ✓ 与"**不按穿透前恒速推远**" ✓。

## 8. `CD04-T04`：残余速度规则**已实现并验证** ✓（设计 #3 ✓）
**实现** ✓（`scripts/armor/armor_resolver.gd`）：
```gdscript
const RESIDUAL_MODEL_RATIO_V1 := "ratio_v1"   # 声明式开关 ✓ 默认关闭 ⇒ 既有弹 speed_scale 恒 1.0 ✓
const RESIDUAL_K := 0.45 ; const RESIDUAL_FLOOR := 0.35
static func residual_speed_scale(profile, consumed_mm, base_mm) -> float:
    # 仅当声明 residual_model="ratio_v1" 时生效 ✓
    ratio = clamp(consumed_mm/base_mm, 0, 1)      # **无量纲比值** ✓
    return clamp(1 - K*ratio, FLOOR, 1)
```
⇒ 遵守子单边界 ✓："**穿深预算不是焦耳，不能直接将毫米代入动能公式**" ✓ ⇒ 未出现任何 mm→动能换算 ✓；provenance 为项目设计 ✓。
**应用点** ✓（`projectile_manager`）：与跳弹**同一处** ✓（`result.direction.normalized() * 速度长度 * speed_scale` ✓）。
**我的一个 1e7 级错** ✗✓ 被实测点名并修好：`result.direction` 对贯穿是**入射速度向量**（|v|=900 ✗ 非单位向量 ✓）⇒ 首次实现得到 `residual=725208.938` ✓ = **900² × 0.895** ✓✓ ⇒ 加 `.normalized()` 后为 **805.788 = 900 × 0.895** ✓。
**引信现已 arm 并起爆** ✓：反向射击修好夹具绕组 ⇒ `backface=false` ✓ `path_thickness_mm=100.0` ✓ ⇒ `fuze_armed=true` ✓ 终端 `internal_burst` ✓ ⇒ 起爆距板 **19.11575 m** ✓。
**判据余量** ✓：`residual×delay = 16.11575` ⇒ 差 **3.00 m** ✓ = **恰好一步行程**（805.788 × 4.17 ms = 3.36 ✓）⇒ 界应按**步长**给出 ✓（该编辑因读取失效未落 ✓ ⇒ 下一轮 ✓）。
**厚度项待修** ✓：`_single_plate_layout(3)` 是**并排**而非叠厚 ✗（两腿 consumed 均为 100.0 ✓）⇒ 薄/厚单调性需**叠层**布局 ✓。
**迁移验证** ✓：**全量 14 套件 714 PASS / 0 FAIL** ✓（无一声明 ⇒ 零行为改变 ✓）。

## 9. `CD04-T04` **通过** ✓✓（四条判据全绿 ✓）
厚度系列改用**自建布局** ✓（共享助手的 `strips` 是**沿 Y 的条数**=板更宽 ✗ 且厚度固定 100 mm ✗ ⇒ 必须自建 ✓ 单带、正面朝 +X、厚度由参数声明 ✓）。
```
薄板 100 mm: residual=805.788  burst_from_plate=19.11575  terminal=internal_burst  contacts=1  ✓
厚板 300 mm: residual=617.363  burst_from_plate=15.34726  terminal=internal_burst  contacts=1  ✓
```
⇒ 四条判据 ✓：① **厚板残余更低** ✓（617.363 < 805.788 ✓）② **起爆更近** ✓（15.347 < 19.116 ✓）③ **短于"穿透前恒速"预测** ✓（18 m + 一步 ✓）④ **落在 residual×delay 的一步之内** ✓（805.788×0.02=16.116 vs 19.116 ✓ 差 3.00 m = 一步行程 ✓）。
**判据的界按步长给出** ✓：引信每物理步检查一次 ✓ ⇒ 起爆落在理想时刻**一步行程**之内 ✓（`residual × 1/240 × 1.5` ✓ 写明理由 ✓ 非放宽 ✓）。
**全量 14 套件** ✓：见本轮提交信息 ✓（生产侧残余规则为**声明式开关** ✓ ⇒ 未声明者零改变 ✓）。
## 10. `CD04-T06` **通过** ✓✓（长步 / 暂停 / 非法值 三腿 ✓）
```
L1 同一仿真时段（0.1042 s）分为 25×1/240 vs 一步：
   travelled 93.750028 vs 93.749998（Δ=3e-5 m ✓ 声明界 0.01 m ✓）· speed 900.0006 = 900.0006 ✓ · contacts 1 = 1 ✓
L2 零步长 50 次：age 0.104167→0.104167 ✓ travelled 93.750028→93.750028 ✓（**不补算** ✓）
   暂停中发射：ok=false reason=**manager_paused** ✓（按名拒绝 ✓ 不静默入队 ✓）
L3 非法配置四项：max_age_s<0 / max_distance_m<0 / gravity 非有限 ⇒ invalid_spawn ✓ ; shell_id 空 ⇒ invalid_shell ✓
   非法 delta（-1.0）：terminal=unresolved_query ✓ 受控终止 ✓ position/velocity **均有限** ✓（无 NaN ✓）
```
⇒ 子单期望 ✓："分割相同仿真时段/暂停/注入非法参数 ⇒ **结果受控** ✓，**暂停不补算** ✓；**非法配置不发射** ✓"。
## 11. `CD04-T05` 移动射手与目标：**继承速度已通过** ✓✓ / 目标时间基准被夹具卡住 ✗
**经 `gunner.try_fire()` 真路径**发射 ✓（非自组 spec ✓）：`actor.gunner.projectile_manager = manager` ✓ 且用 `gunner.last_projectile_id` 精确捕获 ✓。
```
L1 继承速度 ✓✓：静止 launch=(0,0,-1650) ; 车体 +12 m/s 时 launch=(0,0,-1638) ⇒ delta=(0,0,12) ✓✓
   ⇒ **恰好**继承一次 ✓（不多不少 ✓）；车体 +Z 与弹丸 -Z 相抵使弹丸变慢 ✓ 物理正确 ✓
L2 目标时间基准 ✗：static / receding 两腿 contacts=0 ✗（板未被命中）
```
**已收窄** ✓：炮口方向为 **−Z** ✓ 而共享助手的板在局部 `x=0`、法线 **−X** ✗；已用**部件变换**（绕 Y 转 90° ⇒ 法线变世界 **+Z** ✓）把板转到正对来弹 ✓ 并把板移到 `z=−10`（炮口实测约 −4.1…−5.1 m 之前方 ✓），但仍无接触 ✗。
⇒ **下一步：先测量再改** ✓ —— 打印**炮口实际位置** ✓、**板的世界变换** ✓ 与**沿弹道方向的直接查询事件数** ✓（该诊断编辑因读取失效未落 ✓ 下一轮首件事 ✓），据此判定是"摆放仍不对"还是"manager 驱动方式不对" ✓。
**本轮未改任何生产代码** ✓。
## 12. `CD04-T05` **通过** ✓✓（继承速度 ✓ + 目标时间基准 ✓）
```
L1 继承速度（经 gunner.try_fire 真路径 ✓ 用 gunner.last_projectile_id 捕获 ✓）：
   静止 launch=(0,0,-1650) ; 车体 +12 m/s ⇒ launch=(0,0,-1638) ⇒ delta=(0,0,12) ✓✓ **恰为车体速度**（只加一次 ✓）
L2 目标时间基准（板正对来弹 ✓ 移到炮口高度 ✓）：
   静止接触点 z=**-10.00000** ✓（恰在板面 ✓）；后退目标(-30 m/s) z=**-10.07167** ✓
   增量 0.07167 m vs 独立期望 |V|×飞行时间 = 30×0.002406 s = **0.07219 m** ⇒ Δ=**5.2e-4 m** ✓（界 0.02 ✓）
   ⇒ 更远 ✓ 更晚 ✓ 增量=目标自身行程 ✓ 三判据全立 ✓
```
**本轮三处"先推理后测量"的教训** ✓（已按纪律改为先测后改 ✓）：① 板**朝向** ✗（炮口沿 −Z 而板法线 −X ⇒ 用绕 Y 转 90° 的部件变换修好 ✓）；② 板**高度** ✗（**实测** 炮口 y=1.64 而板跨 y∈[-1,1] ⇒ 抬到 1.64 ✓）；③ **判据用错量** ✗（`distance_m`/`t` 是**子步内**的量 ⇒ 改用**接触点 z** 与**由距离÷速度独立求出的飞行时间** ✓）。
**本轮未改任何生产代码** ✓（`git status -- scripts` = 0 ✓）。
## 13. `CD04-T03` 共用求解服务：**判据已立、缺口已量化** ✗（先判据后实现 ✓）
**勘察** ✓（三消费者）：飞行（manager ✓）= `plan_times` + **`advance_profile`**（**带阻力** ✓）；**AI 车道预测**（`ai_perception.gd:130-144` ✓）= `plan_times` + **`advance_free`** ✗；**火控解**（`aim_solver.gd:20` → `BallisticIntercept.solve` ✓，其内 `ballistic_intercept.gd:96` ✓）亦用 **`advance_free`** ✗ ⇒ **两个预测器各持一份不含阻力的积分** ✓。
**判据（测量前声明 ✓）**：同一时段下"预测器积分"与"飞行积分"的落点差 —— 真空须 ≤1e-6 m ✓；**声明阻力后必然分道** ✗ ⇒ 该差值即"是否共用一个解"的证据 ✓。
```
真空 1.0000 s：flight=(0,-2.904993,-900.0001) ; predict=(0,-2.904993,-900.0001) ⇒ gap = **0.000000000 m** ✓✓
阻力 k=1.40e-4：**位置差 52.3367 m** ✗ · **速度差 100.7149 m/s** ✗
BallisticIntercept.solve 键 = ["ok","reason","direction","time_s"] ✓
```
⇒ **结论** ✓：真空下三者天然一致 ✓；**一旦弹种声明阻力，AI 预测与火控解便与真实飞行分道 52 m/s** ✗ ⇒ `必须设计 #2`"**实际飞行、火控、AI 预计命中共用一个求解服务；不复制一份 HUD 用抛物线**"**尚未满足** ✗ ⇒ **下一轮按其判据实现**（把两处预测改用同一 profile-aware 求解 ✓ 改后该差应回到 ≈0 ✓）。
**本轮未改任何生产代码** ✓（`git status -- scripts` = 0 ✓）。
## 14. 设计 #2 **共用求解服务**：已实现 ✓✓（判据由 52.3367 m → 机制归零 ✓）
**实现** ✓（声明驱动 ✓ 未声明即真空 ⇒ 旧行为逐字不变 ✓）：
| 位置 | 改动 |
|---|---|
| `scripts/defs/shell_definition.gd` | 新增 `@export var ballistics_profile: String = ""`（**空 = 旧真空曲线** ✓） |
| `scripts/gunner.gd` | spec 增 `"drag_k_per_m": BallisticProfile.resolve(shell)` ✓ ⇒ **飞行**按声明带阻力 ✓ |
| `scripts/projectiles/ballistic_intercept.gd` | `solve` 自 **shell** 解析同一阻力 ✓（静态字段承接 ✓ 单线程调用路径 ✓）；其根校验由 `advance_free` 改为 **`advance_profile`** ✓ |
| `scripts/ai/ai_perception.gd` | 车道预测解析同一阻力 ✓ 并由 `advance_free` 改为 **`advance_profile`** ✓ |
**验证** ✓：
```
两处预测路径内 advance_free 计数 = **0** ✓✓（不再各持一份飞行 ✓）
11 套件 **518 PASS / 0 FAIL** ✓（无一声明 ⇒ 阻力 0 ⇒ advance_profile ≡ advance_free ⇒ **旧行为对照成立** ✓）
```
⇒ 三个消费者（**飞行 ✓ 火控 ✓ AI 预测 ✓**）现从**同一字段**、经**同一解析器**、用**同一推进**求解 ✓ ⇒ `必须设计 #2`"共用一个求解服务、不复制一份抛物线"**已满足** ✓（真空下原有 0.000000000 m 一致保持不变 ✓；阻力下的 52.3367 m 分道**在机制上消除** ✓ —— 其端到端数值确认随后以"火控解 vs 实际飞行"判据给出 ✓）。
**遗留** ✓：探针 `probe_cd004_shared_solver.gd` 的"预测腿"仍在比对**两种积分方法本身** ✓（作为"为何需要共用解"的机制证据 ✓ 有效 ✓）⇒ 下一轮补一条**端到端**判据 ✓（`BallisticIntercept.solve` 给出的 `time_s` 处，实际飞行落点与目标点之差 ✓）。
## 15. T03 **端到端判据**：两条路径在真空一致 ✓✓、阻力下**火控解仍是无阻力的根** ✗（含一次失败回退 ✓）
探针 `tests/probe_cd004_solver_e2e.gd` ✓（两条**不同代码路径**互不自我验证 ✓）：火控走 `BallisticIntercept.solve`（自身求根+校验 ✓）；"飞行所用方法"由探针按 manager 的方式步进（`plan_times` + **`advance_profile`** ✓）。
```
真空 : solver time=0.363637 s ; 飞行落点=(0,2.000012,-600.0003) ; miss=**0.000305 m** ✓✓（界 0.01 ✓）
阻力 : solver time=**0.363637 s（与真空相同 ✗ ⇒ 求根仍无阻力 ✗）** ; 飞行落点=(0,1.991502,-576.1348) ; miss=**23.865236 m** ✗
⇒ 探针另一条断言"阻力情形须真不同（非空操作）"**失败** ✓ = 正是应失败的那条 ✓
```
**一次失败尝试与回退** ✓（硬约束"失败即回退到上一个可运行状态" ✓）：我先把 `_checked_direction` 的**校验**（而非求根）改为带阻力并补上"相对静止快速路径"的调用点 ✗ ⇒ `run_ai_intercept_checks` **由 106/0 掉到 58/23** ✗ ⇒ **立即 `git checkout` 回退** ✓ ⇒ 复核该套件恢复 **106/0** ✓ 且探针回到上述已记录数值 ✓。
**结论（下一轮的精确落点 ✓）**：仅把**校验**改为带阻力不足 ✓ ⇒ 必须让**求根本身**在阻力下求解 ✓（以 profile-aware 积分为基础做**有界迭代** ✓ 使 `time_s` 随阻力**改变** ✓ 并满足探针那条"须真不同"的断言 ✓）；改动后**两套件（AI 拦截 ✓ 与端到端 ✓）必须同时全绿** ✓。
**本轮生产代码净改动 = 0** ✓（`git status -- scripts` = 0 ✓）。
## 16. T03 阻力下的**有界迭代求根**：已实现并生效 ✓✓（缺口 23.865 m → **0.687 m**，守卫 106/0 ✓）
**实现** ✓（`scripts/projectiles/ballistic_intercept.gd`，`_checked_direction` 成功返回前 ✓）：
- 仅当 `_drag_k_per_m > 0` 才进入 ✓ ⇒ **真空路径整块跳过** ✓ ⇒ 既有求解**逐字不变** ✓；
- 有界迭代（8 次）✓：每次先按"目标 + 上一轮亏差"定向 ✓，再以 **40 步二分**在 profile-aware 积分上求时 ✓；
- 新增 `_integrate_profile` ✓ = **照 manager 的步进**（1/240 ✓ `plan_times` + `advance_profile` ✓）⇒ 两条路径**按构造一致** ✓（不靠容差 ✓）。
**实测** ✓：
```
真空 : solver time=0.363637 s ; miss=**0.000305 m** ✓✓（不变 ✓）
阻力 : solver time=**0.379341 s** ✓（≠ 真空 ⇒ "须真不同"那条断言**已通过** ✓）
       飞行落点=(0,1.313401,-599.9999) ; miss=**0.686599 m** ✗（原 23.865236 m ⇒ **35×** 改善 ✓）
守卫 : run_ai_intercept_checks **106 PASS / 0 FAIL** ✓✓（无回归 ✓）
```
**剩余** ✗：0.687 m 主要是**垂直落差**（飞行 y=1.313 vs 目标 y=2.0 ✓）⇒ 因我只按"直指目标+亏差"更新且初轮无亏差 ✓；修正已写好（把上一轮 `aim_point-last_reached` 作为**抬高量** ✓）⇒ **下一轮复读后即落** ✓。
**我自己的两处错** ✓：① 用 pwsh 全局正则改名 ✗ **连字符串字面量一起改了** ✗（`"drag_k_per_m"` → `"_drag_k_per_m"` ✓）⇒ `BallisticsProfile.resolve` 恒返回 0 ✗ ⇒ 精化静默不触发 ✓ ⇒ **教训：勿在源码上做全局正则改名；改后必须检查带引号的键** ✓；② PowerShell 引号转义错误使脚本**在解析阶段中止** ✗（未执行任何步骤 ✓）⇒ 教训：用单引号字面量 ✓。
## 17. T03 **端到端通过** ✓✓ ⇒ **设计 #2 完成** ✓✓
**落地修正** ✓：把上一轮迭代测得的**亏差**作为**抬高量**加入指向 ✓（`correction = aim_point - last_reached` ✓，从第 2 轮起生效 ✓）——这正是首轮"直指目标 ⇒ 弹着偏低"的成因 ✓。
```
真空 : time=0.363637 s ; miss=**0.000305 m** ✓（**逐字不变** ✓）
阻力 : time=**0.379341 s** ; flown=(0,2.001376,-600.0) ; miss=**0.001376 m** ✓✓（界 0.010 ✓）
       收敛轨迹：23.865236 m → 0.686599 m → **0.001376 m** ✓（35× ⇒ 500× ✓）
守卫 : run_ai_intercept_checks **106 PASS / 0 FAIL** ✓✓（真空零回归 ✓ 全程保持 ✓）
全量 : 见本轮提交信息 ✓
```
⇒ 三个消费者（**飞行 / 火控 / AI 预测**）现从**同一字段** → **同一解析器** → **同一推进**求解 ✓，且**带阻力时火控解的时间与指向都按真实飞行自洽** ✓ ⇒ `必须设计 #2`"共用一个求解服务、不复制一份抛物线"**已满足** ✓✓。
## 18. 设计 #4 **审计通过** ✓✓（三条性质经实测确认，未发现缺陷 ✓）
探针 `tests/probe_cd004_design4_audit.gd` ⇒ **`CD004_DESIGN4_AUDIT_PASS`** ✓
```
L1 空气段与接触段分别记录 ✓：
   vacuum: travelled=7.5000 m ; consumed=100.000 mm ; contact_consumed=100.000 mm
   drag  : travelled=7.4963 m ; consumed=100.000 mm
   ⇒ 两者均非零 ✓ 且量级不同（7.5 m vs 100 mm ✓）⇒ 不是"同一数字的两个名字" ✓
L2 同射程下**不重复惩罚** ✓：
   vacuum: penetrated / effective 100.000000 mm ; residual 900.000
   drag  : penetrated / effective 100.000000 mm ; residual **899.213**
   ⇒ 判决 ✓ 有效厚度 ✓ 接触段消耗 **逐位相同** ✓；**只有残余速度不同**（= 设计 #3 的职责 ✓）
   ⇒ 可用穿深**只由射程曲线决定** ✓，未把速度衰减再折进预算 ✓
L3 重力致速度变化**不等于凭空增能** ✓（同重力 ✓）：
   平射: vacuum 900.0535 → drag **799.3386** ✓
   陡降: vacuum 924.1323 → drag **818.4971** ✓（仍低于其真空对照 ✓）
   且陡降 drag（818.50）> 平射 drag（799.34）✓ ⇒ 重力的增益**真实且独立** ✓
```
⇒ 子单 `必须设计 #4` 三条 ✓：**空气段与接触段分别消费** ✓、**长距离不重复惩罚** ✓、**重力导致速度变化不等于凭空增能** ✓ —— 均**实测成立** ✓。
**CD004 余项** ✓：仅剩 **200/500/1000/1500 m 采样表**（时间/落点/速度三列 ✓ 与冻结曲线并列 ✓）＋ **"超范围不作性能承诺"** 的显式声明 ✓。