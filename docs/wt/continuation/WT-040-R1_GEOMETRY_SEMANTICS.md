# 第 ③ 步 A 类：`geometry` **字段语义规范**（源码实证，供测量工具对齐 ✓）

> 依据：`scripts/content/historical_vehicle_geometry.gd`（158 行全文 ✓）—— 它是**消费** `packet.geometry` 造 layout 的模块 ✓，
> 因此其用法即**权威语义** ✓（不是猜测 ✓）。生产包实例：`configs/vehicles/historical/<id>.json` ✓。

## 1. 逐字段语义（含源码行）
| 字段 | 精确含义 | 源码依据 | 可实测 |
|---|---|---|---|
| `hull_rings` | **环数组**：每环 `[y, w, f, r]` ＝ **高度 · 半宽 · 前 z · 后 z**；约定 **`[0]`＝地板**、**`[1]`＝车体中线的 y**、**`[2]`＝车顶 y**（**恰好 3 环**被使用） | L24-31, L45, L50, L53-54 | ✓ |
| `turret_origin` | 炮塔枢轴**原点**（局部坐标，作为 `turret` 部件 `bind_local.origin`） | L16, L19 | ✓ |
| `gun_origin` | 火炮枢轴**原点**（`barrel` 部件） | L16, L19 | ✓ |
| `turret_outline` | 炮塔**底部**二维轮廓 `[x,z]` | L56-57 | ✓ |
| `turret_bottom` / `turret_top` | 炮塔**下沿/上沿 y** | L57-58 | ✓ |
| `turret_taper` | 顶部相对底部的**收缩比例**（顶部轮廓 = 底部 × taper） | L58 | ✓ |
| `ring_half` | 炮塔座圈**半尺寸**（座圈开口按 ±ring_half 生成） | L43, L46-47, L51 | ✓ |
| `open_top` | 敞篷（true ⇒ 不生成炮塔顶面，改声明开口） | L74-75 | 几何判定 ✓ |
| `mantlet_half_width` / `mantlet_half_height` | 炮盾**半宽/半高** | L77-78 | ✓ |
| `barrel_length` | **本模块未引用** ✗（供 layout 的 `barrel` 部件/弹道侧） | —（生产包中存在） | ✓（须标注基准 ✓） |
| `wheel_count` / `track_width` / `wheel_radius` | 行动装置参数（`TrackAssembly.bind_layout` 消费） | L117 | ✓ |
| `muzzle_brake` | 布尔（本模块未用 ✗，供视觉/弹道） | —（生产包中存在） | 几何判定 ✓ |
| `separate_rotor_shield`（可选 ✓） | 是否**分体炮盾**（true ⇒ 生成固定炮盾+转子盾两个环面） | L81-94 | ✓ |

## 2. 与 `layout` 的接口（测量后必须能被消费 ✓）
- `hull`（`fixed`）→ `turret`（`yaw`，角度取 `packet.runtime.yaw_min/yaw_max`）→ `barrel`（`pitch`，角度取 `runtime.pitch_min/pitch_max`） ✓；
- 装甲面由 `hull_rings`/`turret_outline`/`mantlet_*` 生成 ✓，**每个 zone 必须能解析到 `packet.facts` 中的一条 ✓**（L150-152 ✓）⇒ B 类资料的硬要求 ✓。

## 3. 由此确定 A 类工具的输出要求
1. 只写**可实测**字段 ✓，**每字段附测量方法**（`{"method":…,"measured":true}` ✓）；
2. `hull_rings` 必须给**恰好 3 环** ✓（地板/中线/车顶 ✓，与源码约定一致 ✓）；
3. `turret_outline` 用**炮塔底部轮廓** ✓（不是顶部 ✗）；
4. `barrel_length` 输出时**附基准说明** ✓（炮口偏移相对车体根 ✓；枢轴≠炮尾 ✓）；
5. 无炮车辆**不产出**炮口相关字段 ✗（与已加固的适配器判定一致 ✓）。

---

## 4. A 类工具首跑结果与**两处遗留问题**（诚实记录 ✓）
工具：`tests/generate_modern_geometry.gd`（新增 ✓）· 产出：`logs/WT-040-R1/modern_geometry_draft.json`（draft ✓）

| 车辆 | 结果 |
|---|---|
| **T-80B** | **13 字段测出** ✓（3 环 hull_rings ✓ · turret/gun 枢轴 ✓ · turret 上下沿与 taper ✓ · ring_half ✓ · track_width/wheel_radius ✓ · `wheel_count 13`（单侧 ✓）· `barrel_length 6.134` ✓） |
| **豹2A4** | hull 网格未识别 ⇒ **`hull_rings` 明确未产出** ✓（注记 "loud, not zero" ✓）；其余字段测出 ✓（`mantlet_half_width 0.476` ✓ · `turret_taper 1.0` ✓ 等 ✓） |

### 首跑暴露并已修的两个缺陷（**均为我自己的错** ✗）
1. **静默零值** ✗：`_band_extent` 在空带时曾返回 `0.0` ✗ ⇒ 豹2A4 出现 `hull_half_width=0` 与全零中环 ✗（**正是本会话反复出现的失败模式** ✓）⇒ 已改为**返回空并响亮注记** ✓；
2. **选错网格** ✗：hull 提示词含 `armour` ⇒ 命中 **`TurretArmour`** ✗ ⇒ 已加**排除表**（turret/track/skirt/wheel/gun/mantlet/shield ✓）。

### **遗留问题（下一轮，未解决 ✗）**
1. `wheel_count` 语义与生产包不一致 ✗：我数 **13**（单侧全部轮类 ✓ 含托带轮 ✓），生产包记 **6**（**负重轮** ✓）⇒ 需对齐口径并写明判据 ✓；
2. 豹2A4 的 **hull 网格未定** ✗（其可见网格含 `TurretRace/TurretArmour/Optics/hatch_*/Mantlet/track_l/track_r/SideSkirtPanels` 等 ✓）⇒ 需**列出全部网格后再选** ✓，**不接受猜测** ✗；
3. `open_top` 为**推断** ✓（非视觉复核 ✓）；`muzzle_brake` 为**几何猜测** ✓；`ring_half` 为**派生** ✓ —— 三者均已在 `methods` 中如实标注 ✓。
