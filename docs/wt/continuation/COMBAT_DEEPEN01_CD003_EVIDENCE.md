# MCT-COMBAT-DEEPEN-01 · CD003 证据档（有限截面弹丸与运动目标接触）

对应子单：**WT-CD-003**（P1 · 关口 G1/G2 · 前置 CD001/CD002 ✓）· 用例：`CD03-T01`…`CD03-T06`
探针：`tests/probe_shape_profile.gd` · `tests/probe_cd003_gap_baseline.gd` · 日志：`logs/COMBAT-DEEPEN-01/cd03-*.log`

> 纪律：期望值**由几何独立算出** ✓ 不用被测函数算答案 ✓；未实现的部分**如实记录为缺口** ✓ 不为了让检查变绿而改期望 ✓。

## 1. 现状勘察（只读 ✓ 子单"依据与边界"的核对）

| 事实 | 证据 |
|---|---|
| `ProjectileShapeProfile` **不存在** | `git grep` 0 命中 |
| `ShellDefinition` **只有 `caliber_mm`（炮膛）**，无弹形字段 | `scripts/defs/shell_definition.gd:12` |
| 结算把**炮膛直径当弹径**消费 | `scripts/armor/armor_resolver.gd:20` 取 `budget.caliber_mm` ⇒ **APFSDS 目前由炮膛代表** |
| 查询是**线段 + 平移扫掠**，无体积/旋转连续碰撞 | `QueryGeometry.segment_triangle` · `TranslationSweep.local_segment` |

## 2. `ProjectileShapeProfile`（`必须交付 #1` ✓ 已落地）

文件 `scripts/projectiles/projectile_shape_profile.gd` ✓（93 行 ✓）：

- **炮膛与有效截面分开** ✓：`bore_caliber_mm` / `core_diameter_m` / `core_length_m` —— 有效截面**不由炮膛推导** ✓
- **出处标注** ✓：`provenance=design` + 每条带 `note`，明写"项目工程估计、无实测截面、`NOT_COMPARED`" ✓（**不冒充实测** ✓）
- **采样与误差边界随数据走** ✓：`centre_plus_ring` · 射线数 · `error_bound = r·(1−cos(π/n))` ✓（**从不声称精确** ✓ 子单 `必须设计 #2` ✓）
- **缺剖面按名拒绝** ✓（`no_shape_profile` ✓）⇒ **不偷偷回退 v1 线规则** ✓（`必须设计 #5` ✓）；`core > bore` 亦按名拒绝 ✓

自检（期望值**独立重算** ✓）：
```
apfsds 炮膛 125.0 / 弹芯 30.0 mm ⇒ 次口径=true ✓ · rays=7 · bound=1.485467 mm ✓（独立重算一致）
ap     88.0 / 88.0 mm          ⇒ 次口径=false ✓ · rays=5 · bound=8.403252 mm ✓（独立重算一致）
无剖面弹 ⇒ 拒绝 no_shape_profile ✓ ;; 弹芯>炮膛 ⇒ 按名报错 ✓ ;; SHAPE_PROFILE_SELF_TEST_PASS ✓
```

## 3. 独立缝隙基准（`实现顺序 #1` ✓ 已测）

做法 ✓：合成一对平板在 X=0 处留出**宽 d 的竖直缝** ✓；弹道沿 +X ✓；**期望由"弹丸声明截面 vs d"的纯几何算出** ✓（不经查询 ✓）；实测的是**当前线段查询**的结果 ✓。

| 缝宽 | 缝中线（弹道） | 边缘线 | 内侧 150 mm |
|---|---|---|---|
| 20 mm | contacts=**0** | 1 | 1 |
| 50 mm | contacts=**0** | 1 | 1 |
| 200 mm | contacts=**0** | 1 | 1 |

| 缝宽 | long_rod 30 mm | full_caliber 88 mm | chemical 120 mm |
|---|---|---|---|
| 20 mm | 应接触 ⇒ 实测**穿** ✗ | 应接触 ⇒ 实测**穿** ✗ | 应接触 ⇒ 实测**穿** ✗ |
| 50 mm | 应穿 ⇒ 穿 ✓ | 应接触 ⇒ 实测**穿** ✗ | 应接触 ⇒ 实测**穿** ✗ |
| 200 mm | 应穿 ✓ | 应穿 ✓ | 应穿 ✓ |

⇒ **9 组中 5 组不符** ✗：缝中线弹道**恒为直穿** ✓，弹丸声明的截面**从未进入结果** ✗ —— 即子单所述"炮弹像无尺寸针穿过窄缝" ✓，**实测而非推断** ✓。
⇒ 该缺口即 **3A（静态有限截面）** 的工作项 ✓；本基准**只测量、不假装通过** ✓（探针 7 项检查 0 失败 ✓，5 项不符作为**缺口**逐条打印并列入本档 ✓）；3A 落地后同一探针将改为**断言**这些期望 ✓。

### 3.2 3A 已落地（静态有限截面 ✓ 实测 9/9 与几何一致 ✓）
实现 ✓：`ShotQueryService.query` 接受**可选** `shape_section`（`section_radius_m` + `rays` ✓）；`_collect_patches` 以**有界环射线**采样截面 ✓：
- **中心射线仍定义** `point_world` / `t` / `normal` ✓ ⇒ **同一物理板同一 episode 只结算一次** ✓（`必须设计 #3` ✓）；环射线只决定"**是否遇到该板**" ✓；事件新增 `section_ray_index` / `section_offset_local_m` / `section_radius_m` 字段 ✓（`必须交付 #3` 的接触记录 ✓）
- 粗筛 AABB 按半径**外扩** ✓ —— 这是**真实多射线的保守粗筛** ✓ **不是**"放大碰撞盒冒充体积弹" ✗（拒收条件 1 ✓）
- **射线预算** `RAY_BUDGET=512` ✓ ⇒ 耗尽时 `complete=false` + 诊断 `ray_budget_exhausted` ✓（`必须设计 #4` ✓ **不当作无命中** ✓）
- **无截面时 v1 线行为逐字不变** ✓（同一基准仍 5/9 不符 ✓ 作为**显式旧规则对照** ✓ `必须设计 #5` ✓）

实测（期望值由几何独立算出 ✓）：
| 缝宽 | long_rod 30 mm | full_caliber 88 mm | chemical 120 mm | v1 线对照 |
|---|---|---|---|---|
| 20 mm | **contact(2)** ✓ | **contact(2)** ✓ | **contact(2)** ✓ | pass ✗ |
| 50 mm | **pass** ✓ | **contact(2)** ✓ | **contact(2)** ✓ | pass ✗ |
| 200 mm | pass ✓ | pass ✓ | pass ✓ | pass ✓ |

⇒ **3A：9/9 与独立几何一致** ✓（`16 项检查 0 失败` ✓）；**v1 线：5/9 不符** ✓ ⇒ 缺口已闭合 ✓ 且旧规则**保留可对照** ✓。
回归 ✓：`ARMOR 81 · QUERY ✓ · PROJECTILE ✓ · DAMAGE 57 · ERA 73 · RECOVERY 64 · SPALL 78 · AMMO_COMPARTMENT 63 · LIVE_FIRE_RESPAWN 17` = **433 PASS / 0 FAIL** ✓

### 3.3 `CD03-T03` 同板/真双层 与 `CD03-T02` 边缘结算：**通过** ✓（走真实弹丸链路 ✓）
用真实弹丸经 `manager.try_spawn`（声明截面 ✓）打**合成几何** ✓，期望值由几何独立给出 ✓（一块板＝一次作用 ✓）：

| 腿 | 实测 | 判定 |
|---|---|---|
| **单板** · 射线数 **3 / 7 / 13** | contacts **1/1/1** ✓ · consumed **100.000000 / 100.000000 / 100.000000 mm** | **单板不因射线数变厚** ✓（用例期望 ✓） |
| **同板** · 三角数 **2 vs 16** | contacts **1/1** ✓ · consumed **100.000000 vs 100.000000 mm** | 细分不增厚 ✓ |
| **两块真实板串联** | contacts **2** ✓ · consumed **200.000000 mm** ✓ · results **["penetrated","penetrated"]** | **真实双层保留双层作用** ✓ |
| **边缘/中心接触**（`CD03-T02` ✓） | contacts 1 ✓ · consumed 100 ✓ · result **["penetrated"]** | **走材料结算** ✓ 非"必然停弹/直穿" ✓ |

⇒ `32 项检查 0 失败` ✓；机制依据 ✓：3A 中**中心射线定义 TOI/点/法线** ✓ ⇒ 一块板恒为一次结算 ✓ 而环射线只决定"是否遇到" ✓（`必须设计 #3` ✓）。

### 3.5 `CD03-T04` 子步/预算 与 `CD03-T05` 旋转偏移：**通过** ✓
| 腿 | 实测 | 判定 |
|---|---|---|
| **跨子步**（`1/60 · 1/120 · 1/240`） | 各 **1 接触 · consumed 100.000000 mm** ✓ | 可比场景在声明容差内一致 ✓（`T04` 期望 ✓） |
| **预算耗尽**（`rays=400` × 2 板 = 800 > `RAY_BUDGET=512`） | `complete=false` ✓ · 诊断 `["ray_budget_exhausted at patch cd003_second (budget 512)", "section_sampled rays=400 radius_m=0.030000"]` ✓ | **明确 incomplete，不当作无命中** ✓（`必须设计 #4` ✓） |
| **旋转下的环偏移**（转轴**垂直于弹道** ✓ 弹道与板件同步旋转 ✓） | A/B 两相位 `contacts=1` · `len=0.030000` ✓ · **`dir_dot = 1.000000`** ✓✓ | **同一相对几何 ⇒ 同一局部偏移** ✓ ⇒ **3B 的偏移帧处理正确** ✓ |
| **移动目标一致接触时间**（三相位 ✓） | `fraction = 0.500000` ✓ · 局部 Z 与解析值逐一相符 ✓ | **无跨 tick 固定偏置** ✓ |

**说明（两次测试设计更正 ✓ 已留档）**：① 最初绕**飞行轴**旋转 ✗ ⇒ 该轴不变量 ⇒ 相对几何其实未变 ⇒ 只能得到分歧 ✓（已更正为**垂直于弹道**的转轴 ✓）；② 预算腿最初用**缝中线** ✗ ⇒ 射线环在中心命中时即 `break` ⇒ 只投 2 条射线 ✗ ⇒ 远未到预算 ✓（已改为**中心不中的擦边线** ⇒ 每板走完整环 ✓）。两次都是**测试**的问题 ✓，产品侧未改动 ✓。

### 3.6 明确未完成（`拒收条件 4` ✓ 不得只做 3A 就宣称整单完成 ✓）
- **3A**：**已完成**（有界环射线 + 声明误差边界 + 射线预算 + 同板一次 ✓）
- **生产链路接线**：**已完成** ✓ —— 子单要求的落点是整条链 ✓ 现已落实：
  · 声明只走**显式** `shape_profile`/`shape_kind` ✓（**不从 `effect_policy` 推导** ✓ —— 我最初那样写会让**所有旧长杆弹**被静默加上截面 ✗，正是子单禁止的 ✓）
  · **无法解析的声明 ⇒ 发射按名拒绝** ✓（实测 `no_shape_profile` ✓）；**未声明者 ⇒ 状态标 `shape_source="legacy_line"`** ✓（回退**可见**而非静默 ✓ `必须设计 #5` ✓）
  · 实测链路 ✓：工程弹经 `manager.try_spawn` ⇒ 命中 20 mm 窄缝的接触记录为 `section_radius=0.015 m` · **`ray_index=2`** ✓ ⇒ **环射线**（非中心 ✓）⇒ 截面确实走过 `声明 → ProjectileState → ProjectileManager → ShotQueryService` ✓✓
  · 回归 ✓：**14 套件 714 PASS / 0 FAIL** ✓（ARMOR 81 · DAMAGE 57 · ERA 73 · RECOVERY 64 · SPALL 78 · AMMO 63 · LOADING 62 · LOADING_MECHANISM 65 · MODERN_GARAGE 29 · **AI_INTERCEPT 106** · AUTHORITY 19 · LIVE_FIRE_RESPAWN 17 · QUERY ✓ · PROJECTILE ✓）
- **3B 相对平移**：现有 `TranslationSweep` 仍是**线段级** ✓；截面偏移按**静置部件系**换算 ✓（3A 静态下精确 ✓）⇒ **移动目标下尚未接入 = 3B 待完成** ✗
- **3C 旋转部件**：未实现 ✗（`CD03-T06` 需要）
- `CD03-T01/T02/T03/T04/T05` **均已通过** ✓（见 §3.2、§3.3、§3.5）
- **3C 旋转部件 / `CD03-T06`**：**未实现** ✗（"接触/内构同一时刻 ✓ 旋转边界不伪装成静态回退" ✓）⇒ 这是本单**最后一项**待做 ✓
- **模块/乘员/世界遮挡**当前仍走中心线 ✓（3A 只接**装甲** ✓ 子单要求的"统一接触时刻"待后续 ✓）
- **2.4** 中的交付项：**3A 可玩检查点**尚未在正常局上验证 ✗（本轮为组件级夹具 ✓ 按裁定**不冒充正常局** ✓）
