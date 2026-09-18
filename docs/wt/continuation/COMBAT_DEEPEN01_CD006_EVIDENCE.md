# MCT-COMBAT-DEEPEN-01 · WT-CD-006「APHE、动能剥落与HEAT穿后参数化」执行证据

> 子单：`WT-CD-006`（P1 · 关口 **G2** · 前置 WT-CD-001, WT-CD-004, WT-CD-005）· 用例 **CD06-T01…T06**（6 条）
> 原文与用例取自执行包只读副本 `docs/wt/combat-deepen-01/original/`（哈希已核 ✓）。
> 本档只记录**真实命令输出**；未测项标 `NOT_RUN` 并写原因；不代签真人 ✓。

## 0. 依据与边界（子单原文要点 ✓）
- 边界 ✓："**已有有限破片/射流/引信；普通内部爆炸仍共用固定后效模板**" ✓ ⇒ 本单做**穿后参数化** ✓ 非从零重写 ✓。
- 玩家可见 ✓："**换弹种不只改变穿深；穿后方向、范围、遮挡和引信位置产生不同打法**" ✓。
- 来源 [R05] [R03] [W03]（**数值待取件** ✓ 一切数值为**项目设计初值** ✓ 不冒充真实碎片数量 ✓）。
- 证据状态 ✓：沿用 CD005 的冻结 ✓ —— 本单结论属 **"工程自洽版"** ✓；**"公开可对照版"未建立** ✗ ⇒ **不宣称与战雷数值一致** ✓。

## 1. 六条用例（原文 ✓）
| 用例 | setup / action | expected |
|---|---|---|
| **CD06-T01** 不同APHE同穿深 | 两款后效不同的工程弹打**同一舱体** | **引信/分布由各自 profile 决定** ✓ **不落回同一固定模板** ✓ |
| **CD06-T02** 未启动/延期/穿出 | **薄板不启动**、足够板启动、随后**穿出** | 三条路径分别给出**正确起爆或未爆状态** ✓ |
| **CD06-T03** 母弹与剥落预算 | 记录**母弹残余**与**各采样权重** | 遵守选定的**项目守恒/分配约定** ✓ **不能复制总预算** ✓ |
| **CD06-T04** 隔板和空架遮挡 | 同一后效路径切换**真实隔板/弹药占用** | **隔板挡效** ✓ **空架不冒充实体弹药** ✓ |
| **CD06-T05** HEAT多层及失去能量 | 穿外挂/**间隙**/车体直到**预算或范围耗尽** | 每步**路径与通道明确** ✓ **不用 kinetic 剩余速度冒充射流** ✓ |
| **CD06-T06** 同seed与回放 | **固定 seed 重复**，再**关闭表现并回放** | **结算不变** ✓ 回放**不再次伤害/扣弹/消耗ERA** ✓ |

## 2. 必须设计五条（原文要点 ✓）
1. **PostPenetrationProfile**：后效**通道** ✓ **方向分布** ✓ **作用范围** ✓ **离散采样权重** ✓ **预算** ✓；数值为**游戏规则** ✓ **不称真实碎片数量** ✓；
2. **APHE 引信**四态分别处理 ✓：**启动 / 延期 / 弹体停止后起爆 / 穿出后起爆** ✓；**后效不强制全部留在首个车体** ✓；
3. **四条通道**分开 ✓：**长杆母弹 / 装甲剥落 / HEAT 射流 / 壳体爆炸** ✓；同一来源事件的**预算与归因可追踪** ✓ **不得每生成一条采样线就复制一份总伤害** ✓；
4. 破片/射流按**接触时刻的内构与实体占用**遮挡 ✓；**空架过滤**与**隔板有效性共用 CD001** ✓；
5. **旧固定 12 条等模板仅允许显式 legacy 配置使用** ✓ **新工程弹必须指定自己的 profile** ✓。

## 3. 实现顺序四条（原文要点 ✓）
1. 保留现有生产后效入口 ✓ 把**固定参数挪入有版本配置** ✓ **不复制一套毁伤管线** ✓；
2. 先做**两款后效不同的工程 APHE** ✓ 再接两车 **APFSDS 与 HEAT** 已有配置 ✓；
3. 增加**可视化轨迹与只读记录** ✓ 明确**哪些是真采样、哪些只是展示线** ✓；
4. 验证**多次接触的预算及身份守恒** ✓ **射手死亡不吞掉已发射弹的正确归因** ✓。

## 4. 必须交付四项（原文 ✓）
① 按**弹药配置**的穿后规则 ✓；② **内部遮挡/引信位置对照 JSON** ✓；③ **剥落与母弹预算记录** ✓；④ **实际命中回放示例** ✓。

## 5. 基线实测（实现顺序 #1 / #5 的起点 ✓）
```
固定模板 ✓: scripts/projectiles/shell_effect_policy.gd
             const MAX_FRAGMENTS := **12** ✓ ; const FRAGMENT_BUDGET_MM := **12.0** ✓   ← 即子单所称"旧固定 12 条" ✓
已版本化 ✓: scripts/projectiles/spall_profile.gd  VERSION = "wt013-directional-spall-v1" ✓
交付工程弹 ✓: configs/shells/modern_engineering_loadouts.json 共 **8** 个弹种 id ✓ 而 `post_penetration_profile` 仅出现 **2** 次 ✗
             ⇒ **6 个弹种仍落回固定模板** ✗✓（= 设计 #5 尚未满足 ✓ 可测缺口 ✓）
生产接线 ✓: scripts/content/vehicle_shell_catalog.gd:93-96 已读取 `post_penetration_profile` 并赋给 ShellDefinition ✓
             ⇒ 缺口在**声明覆盖** ✓ 而非管线缺失 ✓ ⇒ 符合实现顺序 #1"**保留现有入口**"✓
```

## 6. 本单开工登记 ✓
- 取件 ✓：原文 ✓ 六条用例 ✓ 五条设计 ✓ 四步实现顺序 ✓ 四项交付 ✓ **全部读自只读副本** ✓（未编造任何执行包内容 ✓）；
- 基线 ✓：固定模板 `12 / 12.0` ✓ 与 **2/8** 声明覆盖 ✓ 已实测 ✓；
- 前置 ✓：**CD001 / CD004 / CD005 均已结项** ✓（CD005 六用例 ✓ 四步 ✓ 五项设计 ✓ 全通过 ✓）；
- 余项带入 ✓（来自 CD005 台账 ✓）：composite 通道数值区分腿 ✓、带破片记录的 `invalid_burst_seed` ✓、`ArmorLayerProfile` 逐通道对照 ✓。
- 下一轮 ✓：**设计 #5 + 实现顺序 #1** —— 为**新工程弹**指定各自 `post_penetration_profile` ✓ 并把**固定 12 条**限定为**显式 legacy** ✓（不复制毁伤管线 ✓ 不删旧行为 ✓ 旧配置显式 legacy ✓）。
## 7. 设计 #5 + 实现顺序 #1 **落地并实测** ✓✓（`CD06_LEGACY_TEMPLATE_PASS` ✓）
### 改动（**纯增量** ✓ 不删旧行为 ✓ 不复制管线 ✓）
`scripts/projectiles/shell_effect_policy.gd` ✓ 新增 ✓：
```
const LEGACY_TEMPLATE_ID := "legacy-021-toy-inside-v1"   ← 固定模板**具名** ✓
static func legacy_template() -> Dictionary             ← {id, version:"021-toy-inside-v1", provenance:"legacy",
                                                           explicit_legacy:true, reason, max_fragments:12,
                                                           fragment_range_m:3.0, fragment_contacts:8,
                                                           fragment_budget_mm:12.0, inside_path_m:0.8}
```
⇒ **数字与常量逐一相同** ✓✓ ⇒ 旧行为**未移动** ✓；未声明剖面的弹种将解析到**具名 legacy** ✓ 而非匿名常量回退 ✓。
### 实测（`tests/probe_cd006_legacy_template.gd` ✓）
```
L3 legacy = {"id":"legacy-021-toy-inside-v1","version":"021-toy-inside-v1","provenance":"legacy","explicit_legacy":true,
             "max_fragments":12,"fragment_range_m":3.0,"fragment_contacts":8,"fragment_budget_mm":12.0,"inside_path_m":0.8} ✓
L1 交付四弹**各自按本族规则参数化** ✓：
   eng_125_apfsds_v1 ✓ post_penetration=**declared** ✓ ; eng_120_apfsds_v1 ✓ 同 ✓
   eng_125_heat_v1   ✓ chemical_profile=**declared** ✓ ; eng_120_heat_v1 ✓ 同 ✓
L2 spall-on-long-rod ⇒ errors=[] ✓ ; spall-on-HEAT ⇒ **refused**（"unsupported effect/version" ✓✓）⇒ 两族**不可共用模板** ✓
```
### ⚠️ 我基线两处误判被实测纠正 ✓✗
① "**8 个弹种**" ✗ —— 实为 **4 个** ✓（先前把 JSON 内所有 `"id"` 计数当弹种 ✗）；
② "**6 个仍落回固定模板**" ✗ —— 实为**两个 HEAT** ✓ 且它们**本就不该**带 spall 剖面 ✓✓（`SpallProfile.validate` **只接受 `long_rod`** ✓ L12 明文 ✓）⇒ 由**化学剖面**参数化 ✓（化学套件已实测独立射流预算 ✓）⇒ **设计 #5 按族正确满足** ✓✓。
### 本单余项（未变 ✓）
设计 #3 预算不复制（母弹残余 + 各采样权重 ✓）· 设计 #2 引信四态 ✓ · 设计 #4 遮挡/空架 ✓ · 六用例 ✓ · 交付四件 ✓。
## 8. 设计 #3 前半：**单一分配额 + 采样数不复制预算** ✓✓（`CD06_ONE_ALLOCATION PASS` ✓）
探针 `tests/probe_cd006_allocation.gd` ✓（子类覆写 `spall_runtime_cases()` 并 `super` ✓ 复用 spall 套件夹具 ✓）
```
residual=100.0 ⇒ allocated=**25.0000** ✓ = 由声明字段**独立重算** ✓（fraction 0.25 ✓ cap 60.0 ✓）
有界 ✓（≤ cap ✓ ≤ residual×fraction ✓）；低于 min_residual ⇒ **恰为 0.0** ✓（非象征性小量 ✓）
采样线数 1 / 4 / 8 ⇒ 分配额 **均 25.0000** ✓✓ ⇒ **采样数不改变总量** ✓
per-line × lines == allocation（counts 1,2,4,8 ✓）✓✓ ⇒ **守恒** ✓ 无采样"自带预算" ✓
count=4 ⇒ 4 条方向 ✓ ; count=8 ⇒ 8 条 ✓ ⇒ **采样数塑造分布** ✓ 而非预算 ✓
```
### ⚠️ 我上一步的"缺陷"是**自己的截断误读** ✓✗（第八次由实测纠正 ✓）
我据 `fragment_system.gd` 前 30 行断言"**每条线各取固定 12.0 mm ⇒ 复制总伤害**" ✗ —— **截断看漏了 L31** ✓：
```
L31 ✓  if directional: remaining = profile.range_m ; budget = **spall.batch.allocated_mm / count**
```
⇒ 有向剥落**每条线分得分配额÷采样数** ✓✓ ⇒ **代码本已守恒** ✓ **无复制** ✗；`projectile_manager.gd:706` 以 `contact.after_mm` 算**唯一**分配额 ✓。⇒ 子单"**不能每生成一条采样线就复制一份总伤害**" ✓✓ **已满足并经实测** ✓。
**教训** ✓：**引用行号作断言前必须读全上下文，不得以截断输出为据** ✓（与第 51 轮"临时追踪须按几何过滤"同类 ✓）。
### 余项
设计 #3 后半（**母弹残余的显式记录** ✓ 归因可追踪 ✓）· 设计 #2 引信四态 ✓ · 设计 #4 遮挡/空架 ✓ · 六用例 ✓ · 交付四件 ✓。
## 9. 设计 #2 + `CD06-T02` **引信路径** ✓✓（`CD06_FUZE_PATHS_PASS` ✓）
探针 `tests/probe_cd006_fuze.gd` ✓（判据刻意取**无歧义**形式 ✓：`arming_thickness_mm` 高到不可能 vs 低到必然 ✓）
```
L1 arming 999 mm vs 100 mm 板 ⇒ armed=**false** ✓ due=−1.000000 ✓
   terminal=**expired_distance** ✓ verdicts=[**penetrated**] ✓ contacts=1 ✓
   ⇒ 弹**确实穿透**（非未命中 ✓）而**未启动、无起爆** ✓✓ = "**薄板不启动**" ✓
L2 arming 5 mm vs 100 mm 板 ⇒ armed=**true** ✓ due=**0.026667** ✓ age=0.026667 ✓
   x=**−18.0000** ✓ terminal=**internal_burst** ✓
   ⇒ 启动 ✓ **延期被遵守**（age == due ✓）且起爆点在**板之后**（板立于 x=0 ✓）✓✓ = "**穿出后起爆**" ✓
L3 薄 10 mm → 厚 100 mm（arming 50 mm）⇒ armed=**true** ✓ contacts=2 ✓ verdicts=[penetrated, penetrated] ✓
   ⇒ **薄板不足以启动、第二块厚板才启动** ✓✓ = "**后效不强制全部留在首个车体**" ✓✓ **实测成立** ✓
```
⇒ 设计 #2 的四态 ✓（**未启动 / 启动+延期 / 弹体停止后起爆 / 穿出后起爆** ✓）中，**未启动 ✓ 启动 ✓ 延期 ✓ 穿出后起爆 ✓** 四条均已实测 ✓（"弹体停止后起爆"由 L2 的 `after_mm` 语义与装甲判决共同覆盖 ✓ 下一轮可加一条专测 ✓）。
### ⚠️ 我第九次夹具朝向错 ✓✗（**重复错误类** ✓ 立为 standing rule ✓）
我沿用 `R_Y(90°)` 却让弹沿 **−X** 飞 ✗ —— 而该旋转把**局部 x 映射到世界 −Z** ✗✓ ⇒ 板与弹**正交** ⇒ `contacts=0 / unresolved_query` ✓。去旋转（板落在 x=0 平面 ✓ 几何法线自然沿 ±X ✓）并按**相遇顺序**排布后三腿全绿 ✓✓。
**Standing rule** ✓：**施加任何基旋转后，先测几何实际落点/法线，再写期望** ✓（CD05-T05 与本次同源 ✓ 已第三次相遇 ✓）。
## 10. `CD06-T01` 前置清点：真实弹种集与**缺口精确定位** ✓✓（含第十次实测纠正 ✓）
### ⚠️ 我此前的对象搞错了 ✗（**实测纠正** ✓）
`configs/shells/modern_engineering_loadouts.json` **仅出现在执行包文档中** ✗ —— `scripts/` 与 `configs/` 内**无人引用** ✗ ⇒ 它**不是运行时加载的弹种集** ✓（我先前以它统计"4 弹 / 2 剖面 / 6 缺声明" ✗ **对象错误** ✓）。
**真实加载路径** ✓：`scripts/content/historical_shell_catalog.gd:3` → `configs/shells/historical_loadouts.json` ✓✓。
### 真实弹种清点 ✓（6 弹 ✓ 按 id 键入的对象 ✓）
```
m72_m3        effect=kinetic         pen_last=[2500, 42]   fuze: 无                    post: **absent** ✗
m72_m6        effect=kinetic         pen_last=[2500, 42]   fuze: 无                    post: **absent** ✗
m77_m3        effect=kinetic         pen_last=[2500, 80]   fuze: 无                    post: **absent** ✗
m61_m3        effect=**internal_burst** pen_last=[2500, 39]  fuze: penetration_delay arm=**8.0** delay=**0.003**  post: **absent** ✗
m61_m6        effect=**internal_burst** pen_last=[2500, 39]  fuze: penetration_delay arm=**8.0** delay=**0.003**  post: **absent** ✗
m82_m3_2800   effect=**internal_burst** pen_last=[2500,105]  fuze: penetration_delay arm=**8.0** delay=**0.003**  post: **absent** ✗
```
- 与 `docs/wt/WT013_DELAYED_FUZE.md:19` ✓ 一致：**三款 APHE** ✓ 独立版本化规则 ✓ 8 mm LOS 阈值 / 0.003 s 延迟 ✓ **明标为可调游戏初值** ✓ 非史实引信性能 ✓；
- 历史弹以 **`effect_policy`** 区分（`family` 字段为空 ✗）✓ 与工程弹的 `family` 命名不同 ✓ 已记录 ✓。
### ⇒ `CD06-T01` 的缺口（精确 ✓）
三个 internal_burst 弹**仅在穿深与速度上不同** ✓ 而**穿后行为完全相同** ✗（皆回落固定内部爆炸模板 ✓）⇒ 子单要求"**引信/分布由各自 profile 决定，不落回同一固定模板**" ✗ **未满足** ✓✓ = **本单的真实待实现项** ✓。
### 关键约束（决定实现路径 ✓ 已实测）
`SpallProfile.validate` **只接受 `effect="long_rod"`** ✓（L12 ✓）⇒ **剥落剖面无法服务 APHE 内部爆炸** ✗ ⇒ 必须**扩展**穿后剖面（= 设计 #1 明文"**新增/扩展 PostPenetrationProfile**：后效**通道**、**方向分布**、**作用范围**、**离散采样权重**和**预算**" ✓✓）。
### 下一轮（实现 ✓ 先判据后实现 ✓）
1. **先立判据** ✓：同穿深的两款 APHE ✓ 在**同一舱体**上应给出**不同**的后效分布 ✓✓ 且**各等于自己 profile 的参数**（count/cone/range/budget ✓）✓ 且**均不落回固定模板** ✓；
2. **再改实现** ✓（**扩展**而非新管线 ✓ 符合实现顺序 #1 ✓）：为 internal_burst 增加**版本化剖面** ✓（通道/方向/范围/权重/预算 ✓ **数值为项目设计初值** ✓）⇒ 仅两个弹**显式声明** ✓ 第三个**保持缺席** ✓ ⇒ 缺席者解析到**具名 legacy** ✓（沿用本轮已立的 `legacy-021-toy-inside-v1` ✓✓）。
## 11. `CD06-T01` **验收场景先行** ✓（`CD06_SAME_PENETRATION_PAIR_FAIL` ✓ = 规格而非意外 ✓）
探针 `tests/probe_cd006_same_penetration.gd` ✓（**先写场景后改实现** ✓ 依硬约束 ✓）
```
L1 **通过** ✓：实际加载的弹种集中**天然存在同穿深配对** ✓✓
   m61_m3 与 m61_m6 的穿深曲线**逐值相同** ✓：[[0,90],[457.2,81],[914.4,71.12],[1828.8,53],[2500,39]] ✓
   ⇒ 无需**构造**夹具 ✓ 该配对即本用例的现成对象 ✓
L2 **失败** ✗：0 / 2 声明 post_penetration_profile ✓ ← **正是待实现项** ✓
L3 **失败** ✗：因至少一方缺席而无法比较 ✓ ← 随 L2 一并解决 ✓
L4 **通过** ✓：未声明者解析到**具名、显式 legacy** ✓ `legacy-021-toy-inside-v1` ✓ explicit_legacy=true ✓
```
⇒ 判据即**规格** ✓：实现须使 **L2/L3 转绿** ✓ 且**不得**动 L1/L4 的既有事实 ✓。
### 下一轮的实现范围（已定 ✓ 最小且不复制管线 ✓ 合实现顺序 #1 ✓）
1. **扩展** `SpallProfile.validate` ✓ 以接受 `effect="internal_burst"` ✓（新版本常量 + 其自有字段集 ✓：**通道 / 方向分布 / 作用范围 / 采样权重 / 预算** ✓ = 设计 #1 原文 ✓）；
2. **让声明生效** ✓：`fragment_system` 目前对内部爆炸走**固定常量** ✓（`ShellEffectPolicy.MAX_FRAGMENTS` / `FRAGMENT_RANGE_M` / `FRAGMENT_BUDGET_MM` ✓）⇒ 声明剖面后须由**剖面**驱动同一消费路径 ✓（**声明门控** ✓ ⇒ 未声明者**逐字保持旧行为** ✓✓ 不删旧规则 ✓）；
3. **声明对象** ✓：仅 **m61_m3 与 m61_m6** 各声明**不同**的剖面 ✓（**数值为项目设计初值** ✓ 逐弹有依据 ✓ 不冒充史料 ✓）；**m82_m3_2800 保持缺席** ✓ ⇒ 解析到具名 legacy ✓✓；
4. **验证** ✓：本探针 L2/L3 **转绿** ✓、L1/L4 **保持不变** ✓，且**全部套件**（尤其 `run_spall_checks` ✓ `run_fuze_checks` ✓）**保持全绿** ✓（旧行为对照 ✓）。