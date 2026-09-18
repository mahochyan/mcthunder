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

### 3.1 明确未完成（`拒收条件 4` ✓ 不得只做 3A 就宣称整单完成 ✓）
- **3A 静态有限截面**：未实现 ✗（本轮只交付了剖面数据与基准 ✓）
- **3B 相对平移**：现有 `TranslationSweep` 为**线段级**平移 ✓，尚未与弹形结合 ✗
- **3C 旋转部件**：未实现 ✗（`CD03-T06` 需要）
- `CD03-T05`（平移目标一致接触时间 ✓）与 `CD03-T04`（子步/预算 ✓）**均未开始** ✗
- **v1 线查询**保留为显式旧规则入口 ✓（对照用；新工程弹不得经回退进入 ✓ 已由剖面的拒绝行为保证 ✓）
