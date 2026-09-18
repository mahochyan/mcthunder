# MCT-COMBAT-DEEPEN-01 · CD002 证据档（两辆样车的战斗几何与装甲区域）

对应子单：**WT-CD-002**（优先级 P1 · 关口 G1）· 用例：`CD02-T01`…`CD02-T06`
探针：`tests/run_cd002_geometry_probe.gd` · 原始日志：`logs/COMBAT-DEEPEN-01/**` · 导出：`logs/COMBAT-DEEPEN-01/cd002-zone-plate-part.json`

> 纪律：每条结论都必须能指到一次**真实运行**；不能执行的检查标 **NOT_RUN**，并写明原因；**不为了让检查变绿而改期望值**。

## 1. 可读映射导出（子单「必须交付」第 1、3 条 ✓）

从**正常 Actor**（`VehicleActor.setup` ✓ 装载已交付包 ✓）导出，**只读**、不碰任何 authoring 文件与用户模型：

| 车 | 17 逻辑区 | `physical_plate` | 模块 | 乘员站 | 声明开口 | 布局部件 | 允许重叠 |
|---|---|---|---|---|---|---|---|
| `ussr_t_80b` | ✓ 17 | **46** | 11 | 3 | 5 | 6（fixed 4 · pitch 1 · yaw 1） | 1 |
| `germ_leopard_2a4` | ✓ 17 | **42** | 12 | 4 | 5 | 6（同上） | 3 |

- 每块板导出 `id` / `plate_group_id`(区) / `part_id`(运动部件) / `has_thickness` / `thickness_mm` / `thickness_status` / `geometry_status` / `material_kind` / 顶点数 / 三角数 / `reactive` / `evidence_keys` ✓
- **区→板→部件** 三级映射与单位（长度 m、厚度 mm）随 JSON 一并产出 ✓
- 板件状态实测：**两车全部为 `estimated/estimated`**（46/46 · 42/42 ✓）且**证据键覆盖 100%** ✓ ⇒ 没有任何板件冒充 `verified` ✓；因此 CD02-T01 的容差**必须显式声明**（见 §2 ✓）

## 2. `CD02-T01` 关键部位叠加与容差（**部分** ✓）

### 2.1 容差**取自交付包本身**（不是自造 ✓）
```
attachments = 50 mm  (model_binding.units.attachment_tolerance_m = 0.05)
dimension   = 2.00%  (model_binding.units.tolerance_fraction   = 0.02)
来源 = res://configs/vehicles/engineering/<id>.json（子单「先读的生产入口」✓）
同源 = 既有 model_binding_validator.gd 正是按这两个数校验 ✓
性质 = 项目 estimate ✓ · 与战雷对照标 NOT_COMPARED ✓ · 单位 m / mm ✓
```
透明度：参考包 `authoring/reference_data/modern_vehicles/<id>.json` 声明的是更严的一对（**1 mm / 0.1%** ✓），两者不一致**留待裁定**，未擅自择一掩盖 ✓。

### 2.2 **模型锚点腿：已测** ✓（曾经误标 NOT_RUN ✗，原因是我把嵌套 `model` 对象当字符串替换 ✓ 已更正）
| 车 | 交付 GLB | 锚点 | 最差偏差 | 判定 |
|---|---|---|---|---|
| `ussr_t_80b` | `assets/vehicles/modern_bound/ussr_t_80b.glb` ✓ | 13 | **0.00006 mm** | ✓ |
| `germ_leopard_2a4` | `…/germ_leopard_2a4.glb` ✓ | 15 | **0.00012 mm** | ✓ |
做法：由生产配置解析 GLB ⇒ 用包内 `internal_attachments` **真实节点路径** ⇒ 经既有 `ModelAnchorReader.part_relative()` 独立读出锚点 ⇒ 与布局安装的部件相对位置逐项比对（每项记录 `part_node`/`anchor_parent` ✓）。

### 2.3 生成自洽腿（**不是**容差证据 ✓ 口径已更正）
布局 vs **它自身来源的包**必然 0.00 mm ✓（14/16 项 ✓）⇒ 仅作生成自检 ✓。

### 2.4 尚未完成 ✗
**板件轮廓 vs 交付模型网格 AABB** 的叠加（含空隙保持 ✓）**未测** ✗ ⇒ 需要从交付场景取 `MeshInstance3D` 包围盒 ⇒ 列为下一项 ✓。

### 2.5 板件轮廓 vs 交付模型网格：**已测，并列出超差项** ✓✗
读法与**项目自身一致** ✓：交付目录 `assets/vehicles/modern_bound/` 带 **`.gdignore`**（**有意不导入** ✓ 见 `asset_registry_audit.gd:32` 的证据说明 ✓）⇒ 必须用 **`GLTFDocument.append_from_file`** ✓（`model_anchor_reader.gd:22` 同法 ✓）；GLB 路径取自**生产配置** ✓（夹具内的 packet 已被 TEST ONLY 模型改写 ✗）。
判定方式：板件是**部件的子区域** ✓ ⇒ 检验**包含性**（轮廓不得越出所属部件的模型包围盒 ✓；并**排除子角色**以免车体盒被炮塔/火炮撑大 ✓），容差＝**50 mm 或 2%** 取大 ✓（按轴 ✓）。

| 车 | 车体 12 区 | 炮塔 4 区 | 炮盾 `gun_shield` |
|---|---|---|---|
| `ussr_t_80b` | 多数 **within**（outside 0.0 mm ✓）；**`hull_sides_rear` / `hull_sides_lower_rear` / `hull_rear_upper` / `hull_rear_lower` / `hull_roof_rear` 超 210 mm** ✗（Z 向 ⇒ 后部板件伸出车体网格 0.21 m） | **超 666–1376 mm** ✗（Y inset **−1376 mm** ⇒ 炮塔板件伸到炮塔网格**下方** 1.38 m） | **超 663 mm** ✗ |
| `germ_leopard_2a4` | **全部 12 区 within（outside 0.0 mm）** ✓ | **超 790–1570 mm** ✗（Y inset **−1570 mm**） | **超 1005 mm** ✗ |

**待办（按用例原文"超差逐处修复或列未验" ✓）**——以下**逐处登记**，尚未修复 ⇒ 探针中该断言**按设计保持红** ✓（不为变绿改期望 ✓）：
1. 两车**炮塔**板件（`turret_front` / `turret_sides` / `turret_rear` / `turret_roof`）向**下**越出炮塔网格 1.38 m（T-80B）/ 1.57 m（豹2）⇒ 需判定：**模型缺炮塔吊篮** ✓ 还是**布局炮塔下沿过高** ✗（下一轮在**隔离 authoring 目录**内判定并修 ✓ 不碰你在制作的 GLB ✓）；
2. 两车**炮盾**越出 `gun` 角色网格 663 / 1005 mm ⇒ 同上判定（炮盾/炮口开口区域 ✓）；
3. T-80B **车体后部** 5 区越出 210 mm ⇒ 后甲板/尾板与模型轮廓不一致 ✓。
以上均为**项目内部一致性**问题（模型 ↔ 窄相位几何 ✓），**与战雷对照无关** ✓ ⇒ 标 `NOT_COMPARED` ✓；每处的"实际误差"已按轴记录于导出 JSON 的 `mesh_overlay.zones` ✓（含 `outside_mm` / `inset_mm` / `limits_mm` / `within` ✓）。

## 3. `CD02-T02` 姿态与机构：**通过** ✓（无双重变换）

姿态：车体倾斜 **9°** · 炮塔偏转 **28°** · 火炮俯仰 **7°** ⇒ **单一快照**（`physics_tick` 随快照 ✓）
```
部件世界变换 vs 节点 global：worst = 0.000 mm · mismatches=[]   （hull/turret/barrel/drive/L-track/R-track ✓✓）
炮口：barrel 部件 × 该车自身局部偏移 ⇒ 与真实 muzzle 节点差 0.000 mm ✓
      真实偏移 = ussr_t_80b (0,0,-5.09) · germ_leopard_2a4 (0,0,-4.14)   ← 硬编码 2.45 是我的错误 ✗
模块/乘员：逐项保持与**自己部件**的距离（0.000 mm ✓），世界原点与乘员位置逐条记录 ✓
```

## 4. `CD02-T03` 同板等价三角划分：**通过** ✓（跨进程单发对照 ✓）

### 4.1 换划分本身 ✓
每块板绕重心拆 3 片（**并集不变** ✓）：`ussr_t_80b` **194 → 582** 三角（46 板 ✓）· `germ_leopard_2a4` **174 → 522** 三角（42 板 ✓）

### 4.2 可复现夹具（**跨进程单发** ✓）
单进程只建**一个** Actor、只打**一发**；布局由命令行 `-- --t03=original|modified` 选择 ✓。
```
original（第 1 次）：T-80B consumed=110.000000 contacts=1 · 豹2 consumed=439.596969 contacts=3
original（第 2 次）：T-80B consumed=110.000000 contacts=1 · 豹2 consumed=439.596969 contacts=3   ← 逐位相同 ⇒ 对照通过 ✓
modified          ：T-80B consumed=110.000000 contacts=1 · 豹2 consumed=439.596969 contacts=3   ← 与 original 一致 ✓✓
```
伤害条目亦一致 ✓（仅浮点噪声，如豹2炮闩 `after_mm` 66.0358879841737 vs 66.0362557628371 ⇒ **0.0004 mm** 级 ✓，远低于任何有意义容差 ✓）。
⇒ **同一物理板的等价三角划分不改变该路径的命中与阻力** ✓（用例期望成立 ✓）

### 4.3 被撤销的"幻影缺陷" ✗（如实留档 ✓）
旧夹具把**第一发与第二发打在同一世界**里，第二发**不可复现**（同版布局两次得到 429.84 / 110.0 与 209.957 / 439.597 ✗、接触数 2 vs 1 / 2 vs 3 ✗）⇒ 由此读出的"**10 mm 残差**"及其 **6 个假设**全部**撤回** ✗。**对照实验**（同布局打两次 ✓）是识别它的唯一手段 ✓，现已作为**门控**写进探针：对照不过 ⇒ 打印明确 **NOT_RUN** ✓ 并**跳过**比较 ✓，不产出误导性失败/通过 ✓。

### 4.4 从本用例得到的**真实生产修复** ✓（与幻影无关 ✓）
单次运行内观测到：更密划分使**同一 event_id** 出现第二次 ⇒ 伤害提交被判 `invalid_or_duplicate` ⇒ 管理器把它当**致命** ⇒ **整发射击在第一步中止** ✗（`unresolved_damage`、飞行 0.0025 s ✗）。按契约 `CombatIdentity`"**同 event_id 重复只能读取原结果，不再次变更**" ✓ ⇒ 改为 **no-op 继续飞** ✓ **并标记为已处理**（否则无限重放 ✗ 我实测过一次 31 分钟死循环 ✓）。
回归：`PROJECTILE · DAMAGE 57 · ARMOR 81 · RECOVERY 64 · SPALL 78 · ERA 73 · LIVE_FIRE_RESPAWN 17` = **370 PASS / 0 FAIL** ✓

## 5. `CD02-T05` LOD 与显示开关：**通过** ✓
隐藏模型/车体/炮塔后：**查询事件不变** ✓ · **部件世界变换不变** ✓ · **弹药占用不变** ✓ ⇒ 视觉 LOD 只改变外观 ✓

## 6. `CD02-T06` 脱塔重生与无效数据：**部分** ✓
| 腿 | 结果 |
|---|---|
| 非法**板**引用 | `{"ok":false,"reason":"invalid_or_duplicate_armor","surface_id":"cd002_no_such_plate"}` ✓ **按名拒绝** ✓ |
| 非法**模块**引用 | `{"item_id":"cd002_no_such_module","ok":false,"reason":"missing_module"}` ✓ **按名拒绝** ✓ |
| 反应装甲接受性（合法/重复/重生后重击） | **NOT_RUN** ✓ —— 实测**两车反应装甲板均为 0** ✓（`apply_projectile_armor` 是反应装甲通道 ✓） |
| 脱塔后查询 | **未做** ✗ |

## 6.5 `CD02-T04` 真实多层与开口：**通过** ✓

在**独立第三个载体**（+120 m ✓ 不与其他用例共享伤害状态 ✓）上用真实弹丸跑三条腿：

### 6.5.1 开口**不当板** ✓（用 `declared_openings` 的真实 `turret_ring` 边界环 ✓）
| 车 | 穿**开口中心**（自上而下） | 旁边（仍在**甲板上** +1.2 m） |
|---|---|---|
| `ussr_t_80b` | 3 接触 · 80.0 mm · 区＝`[turret_roof, hull_floor_front, hull_floor_rear]` ⇒ **无甲板板** ✓ | 4 接触 · 100.0 mm · 区＝`[turret_roof, hull_roof_rear, hull_floor_rear]` ⇒ **有甲板板** ✓ |
| `germ_leopard_2a4` | 2 接触 · 60.0 mm · 区＝`[turret_roof, hull_floor_front]` ⇒ **无甲板板** ✓ | 4 接触 · 100.0 mm · 区＝`[turret_roof, hull_roof_rear, hull_floor_rear]` ⇒ **有甲板板** ✓ |
说明：两条线都命中 `turret_roof` 是**几何正确** ✓（炮塔位于炮塔环**上方** ⇒ 自上而下的线先穿炮塔顶 ✓）；判定"空隙不当板"的对比在**甲板板** ✓。差值（100−80 / 100−60 ✓ 且接触数 4 vs 3 / 4 vs 2 ✓）同时证明**多层分别作用** ✓。

### 6.5.2 多层**分别结算** ✓
横穿车体两侧：`ussr_t_80b` **4 个接触、4 个不同板 id**（`hull_1_7` / `hull_1_6` / `hull_1_3` / `hull_1_2` ✓）合计 **329.527 mm** ✓；`germ_leopard_2a4` 同样 4 个不同 id ✓ 合计 **265.159 mm** ✓ ⇒ 不是被当成"一块厚板" ✓。

### 6.5.3 **不可见实体不可忽略** ✓
垂直穿炮盾路径 ⇒ 内构（无任何视觉呈现 ✓）仍被击中：`ussr_t_80b` 炮闩 `breech` `module_destroyed` **10 mm** ✓；`germ_leopard_2a4` 炮闩 + 另一模块，均产生伤害记录 ✓。

## 7. 复现方式（全部可自行复跑 ✓）
```powershell
$g='E:\AIprogram\mcthunder\tools\godot\Godot_v4.7.2-stable_win64_console.exe'
$c='E:\AIprogram\mcthunder-cont'
& $g --headless --path $c --fixed-fps 60 -s res://tests/run_cd002_geometry_probe.gd                 # 映射 + T01/T02/T05/T06（T03 比较被对照门控 ⇒ NOT_RUN）
& $g --headless --path $c --fixed-fps 60 -s res://tests/run_cd002_geometry_probe.gd -- --t03=original   # 单发：原版
& $g --headless --path $c --fixed-fps 60 -s res://tests/run_cd002_geometry_probe.gd -- --t03=modified   # 单发：换划分
```

## 8. 状态汇总
| 用例 | 状态 | 依据 |
|---|---|---|
| `CD02-T01` | 🔶 部分 | 容差按包声明 ✓ + 28 锚点 ✓；**板轮廓 vs 网格未测** ✗ |
| `CD02-T02` | ✅ 通过 | 0.000 mm 无双重变换 ✓ |
| `CD02-T03` | ✅ 通过 | 跨进程单发：对照逐位相同 ✓ 两版一致 ✓（换划分 194→582 / 174→522 ✓） |
| `CD02-T04` | ✅ 通过 | 开口不当板 ✓（穿开口 3/2 接触无甲板板 vs 旁边 4 接触有甲板板）· 多层 4 个不同板 id 分别结算 ✓ · 不可见内构仍被击中 ✓ |
| `CD02-T05` | ✅ 通过 | 视觉不改战斗几何 ✓ |
| `CD02-T06` | 🔶 部分 | 非法引用按名拒绝 ✓；反应装甲三腿 NOT_RUN（0 反应板 ✓）；脱塔后查询未做 ✗ |
