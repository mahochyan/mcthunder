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

## 4. 未完成（`拒收条件 4` ✓ 不得只做 T01 就宣称本单完成 ✓）
- **T02** 经验阻力曲线与速度/时间表 ✗ · **T03** 预测/瞄具/AI 与真实飞行**共用求解服务**的误差界限 ✗ · **T04** `residual_velocity` 与**穿后引信按残余轨迹** ✗ · **T05** 移动射手/目标时间基准 ✗ · **T06** 长步/无效值/**暂停不补算** ✗；
- **设计 #1** 版本化 `BallisticsProfile`（单位/初速/重力/可选阻力/寿命与距离上限，**第一版只上一种可校准近似** ✓ 不同时上多套空气模型 ✓）✗；
- **设计 #4** **空气段与接触段分别消费**、长距离**不重复惩罚**的审计 ✗；**设计 #5** 每弹**固定随机种子**避免帧率影响散布 ✗；
- `200/500/1000/1500 m` 采样表与"**超范围不作性能承诺**"的声明 ✗（`实现顺序 #3` ✓）。
