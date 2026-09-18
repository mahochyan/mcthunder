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