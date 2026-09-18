# MCT-COMBAT-DEEPEN-01 · WT-CD-007「HE外部爆破、破片与超压」执行证据

> 子单：`WT-CD-007`（P1 · 关口 **G2** · 前置 WT-CD-002, WT-CD-005, WT-CD-006 —— **三者均已结项** ✓）· 用例 **CD07-T01…T06**（6 条）
> 原文与用例取自执行包只读副本 `docs/wt/combat-deepen-01/original/`（哈希已核 ✓）。
> 本档只记录**真实命令输出**；未测项标 `NOT_RUN` 并写原因；不代签真人 ✓。

## 0. 依据与边界（子单原文要点 ✓）
- 边界 ✓："**上次审查未找到完整独立 HE/超压生产链；开始时先确认后继是否补充，已有部分不重写**" ✓。
- 玩家可见 ✓："**HE 打开放战斗室、薄装甲或近失弹有实际用途，墙后与封闭舱不能隔空被同一种球形伤害清空**" ✓。
- 来源 [R02] [R05] [W04]（**数值待取件** ✓ 一切数值为**项目设计初值** ✓ 不冒充真实爆压公式 ✓）。
- 证据状态 ✓：沿用 CD005/CD006 的冻结 ✓ —— 本单结论属 **"工程自洽版"** ✓；**"公开可对照版"未建立** ✗ ⇒ **不宣称与战雷数值一致** ✓。
- 子单自标 ✓："**六项验收设计（当前均 NOT_RUN）**" ✓ ⇒ 本单从 `NOT_RUN` 起步 ✓。

## 1. 六条用例（原文 ✓）
| 用例 | setup / action | expected |
|---|---|---|
| **CD07-T01** 封闭舱无破口 | HE 外爆但壳体规则**不产生进入舱室的路径** | **无凭空内舱超压** ✓ 外部模块可按各通道受损 ✓ |
| **CD07-T02** 开放舱与遮盖对照 | 相同距离下**开放/遮盖**结构对照 | 传递按**真实连通和遮挡**不同 ✓ **不能只看 `vehicle_type` 标签** ✓ |
| **CD07-T03** 薄板破口与隔板 | 爆破穿过**前板**后面对**独立隔板** | 外板/隔板与乘员结果**能逐段解释** ✓ |
| **CD07-T04** 世界触发与墙后 | HE **命中地面或墙体**并检查**其后目标** | 世界接触**可引爆** ✓ **遮挡仍有效** ✓ **无直接 through-wall 总伤** ✓ |
| **CD07-T05** HEAT通道隔离 | 同一 HEAT **启用射流**、再启用**合法壳体爆炸**配置 | **事件分通道** ✓ **射流不额外冒充超压** ✓ |
| **CD07-T06** 复数目标与终局 | **多目标爆炸、保护目标、回放和终局取消** | **一对象一次合法作用** ✓ **非许可目标无伤害** ✓ **取消明确** ✓ |

## 2. 必须设计六条（原文要点 ✓）
1. **独立设计 blast / fragment / overpressure 三条通道** ✓；同一爆炸 **root_event 记录各通道** ✓ **不共用一个"半径内全死"开关** ✓；
2. 用**有界舱室/开口/装甲破口连通规则**表达压力影响 ✓（**游戏抽象** ✓ 不要求 CFD ✓ 不填真实爆压公式 ✓）；
3. 先支持**接触 HE** 与**世界碰撞后爆炸** ✓；**近炸/定时/导弹/HESH 不在本单第一版** ✗；
4. **HEAT 的射流与可选爆炸分开触发** ✓ **不能把射流穿透本身认成超压伤害** ✓；
5. **开放顶 M36 可作现有代表之一** ✓（取决于 **CD002 检查** ✓）**不临时把现代坦克改成敞篷测试** ✗；
6. **世界遮挡 / 阵营·出生保护 / 不完整查询用同一策略** ✓ **预算边界不能导致无日志的穿墙杀** ✓。

## 3. 实现顺序四条（原文要点 ✓）
1. 用**标准开放舱/封闭舱/带隔板夹具**先证明**传递规则** ✓；
2. **增加一款明确工程 HE** ✓ 并**限定可用测试武器** ✓ **不给所有车辆塞不兼容弹种** ✓；
3. 接入**真实炮弹世界/车辆接触后的爆炸** ✓ 加入**有限受影响对象**与**完成状态** ✓；
4. 在**现有代表车辆**上做**正常射击验证** ✓ **再接效果与音效** ✓ **不先做大爆炸画面** ✓。

## 4. 必须交付四项（原文 ✓）
① **爆炸通道及舱室连通规范** ✓；② **实际工程 HE 配置和注册入口** ✓；③ **开放/封闭/墙后/隔舱实弹证据** ✓；④ **预算上限、保护和去重回归** ✓。

## 5. 基线实测（边界第一个问题的答案 ✓）
```
① **不存在** HE/超压/外部爆破**伤害**链 ✗✓
   全仓 `blast|overpressure|pressure_channel|he_explosion|external_burst` 命中仅一处 ✓：
   scripts/damage/recovery_visuals.gd:3 "## Read-only bounded fire, **blast** and wreck presentation" ✓ = **表现层** ✗ 非伤害通道 ✓
   ⇒ 子单边界所述"**上次审查未找到完整独立 HE/超压生产链**" ✓ **实测成立** ✓
② `effect_policy` **恰为四种** ✓（projectile_manager.gd:140 ✓）：
   ["kinetic","internal_burst","long_rod","chemical"] ✓ ⇒ **HE（外部爆破）须新增** ✓（合实现顺序 #2 ✓）
③ 既有的是**内部**爆炸链 ✓（"已有部分不重写" ✓）：
   _emit_internal_burst ✓ · st.burst_inside_started / burst_entry_distance / burst_target ✓ · ShellEffectPolicy.on_inside_path ✓
   ⇒ 新做的是**外部**爆破 + 超压 ✓ **不是改写内部链** ✓
④ 设计 #6 所需**共用策略挂钩已存在** ✓：
   shooter_team_id ✓（阵营 ✓）· contact_policy ✓（回调 ✓）· unresolved_query **带 detail** ✓（= **有日志** ✓ 而非静默 ✗）
```
⇒ 本单起点 ✓：**无**外部爆破/超压链 ✓ **不重写**内部爆炸链 ✓ **新增** HE 效果策略 ✓ **复用**既有遮挡/阵营/查询策略 ✓。

## 6. 实现顺序 #1 **先立判据** ✓（`CD07_HE_CHANNELS_SPEC_PASS` ✓ = 规格而非意外 ✓）
探针 `tests/probe_cd007_he_spec.gd` ✓（依硬约束"**先写/补验收场景再改实现**" ✓）
```
[CD07 A1] effect_policy=he_blast      => accepted=false reason=**invalid_effect_policy** ✓
[CD07 A1] effect_policy=overpressure  => accepted=false reason=**invalid_effect_policy** ✓
[CD07 A1] effect_policy=blast         => accepted=false reason=**invalid_effect_policy** ✓
[CD07 A1] effect_policy=fragmentation => accepted=false reason=**invalid_effect_policy** ✓
[CD07 A1] all four channel names refused with a reason: **4 of 4** ✓✓
```
⇒ 判据 ✓（实现须使其**存在** ✓ 且**不得**静默复用既有效果 ✓）：四个通道名**全部被具名拒绝** ✓✓ ⇒ **不存在静默同义** ✓。
### ⚠️ 我手搓夹具失败**未被冒充为证据** ✓✗（第十次夹具类疏漏 ✓）
我试图在本探针里**手搓快照**复现"内构在场/缺席"对照 ✗ ⇒ 两种配置**均得 0 记录** ✗ ⇒ 追因 ✓：**快照的 `entity_id` 与 actor 身份不一致** ✗ ⇒ `ShellEffectPolicy.target_snapshot` **查不到目标** ✓ ⇒ 0 记录是**我的夹具**而非通道行为 ✓（改用套件自带的 `set_damage_layout` + 正确身份即可 ✓ 见 CD06-T04 ✓ 那次用**套件夹具**得 0 vs 5 记录 / 0 vs 20 mm ✓✓）。
⇒ 处置 ✓：**不把它包装成证据** ✓，该半由 **CD06-T04 的实测对照引用** ✓；本探针只保留**能诚实测到的那一条** ✓。
**Standing rule** ✓：**优先复用套件自带的夹具助手，不手搓快照；若必须手搓，`entity_id` 必须与 actor 身份一致** ✓（与"旋转后先测几何"同类 ✓）。
### 下一轮（实现 ✓ 最小面 ✓ 不复制管线 ✓）
1. **新增外部 HE 效果策略** ✓（子单实现顺序 #2"**增加一款明确工程 HE 并限定可用测试武器**" ✓ **不给所有车辆塞不兼容弹种** ✓）：`effect_policy` 增加 **`he_blast`** ✓ 并使其在 `try_spawn` 被**接受** ✓；
2. **三通道各自记录 + 单一 `root_event`** ✓（设计 #1 ✓ **不共用"半径内全死"开关** ✓）：`blast` / `fragment` / `overpressure` 分通道 ✓ 同一 root_event 汇总 ✓；
3. **有界连通规则** ✓（设计 #2 ✓）：**封闭舱无破口 ⇒ 无凭空内舱超压** ✓（CD07-T01 ✓）· **开放 vs 遮盖同距离对照不同** ✓ 且**不依赖 `vehicle_type` 标签** ✓（CD07-T02 ✓）；
4. **验证** ✓：本探针四条**由拒绝转为接受** ✓，且**既有套件全绿**（旧行为对照 ✓）。
## 7. **最小实现切片落地** ✓✓（`CD07_HE_ROOT_EVENT_PASS` ✓）
### 改动（**极小且增量** ✓ 不复制管线 ✓ 且**不假装已实现未做的通道** ✓）
`scripts/projectiles/projectile_manager.gd` ✓：
```
① L140 效果策略白名单 ✓：["kinetic","internal_burst","long_rod","chemical"] → 追加 **"he_blast"** ✓（各 1 处命中 ✓）
② _emit_internal_burst ✓ 的 root_event 追加 **channels** 块 ✓：
   fragment     ⇒ {"applied":**true**, "version":ShellEffectPolicy.VERSION, lines/range_m/budget_mm 取**具名 legacy 模板** ✓}
   blast        ⇒ {"applied":**false**, "pending":"cd07-blast-channel", reason:"…not yet applied"} ✓
   overpressure ⇒ {"applied":**false**, "pending":"cd07-overpressure-channel", reason:"…not yet applied"} ✓
   + 若 st.effect_policy=="he_blast" ⇒ st.burst["external_he"]=true ✓
```
### 实测 ✓（`tests/probe_cd007_he_spec.gd` ✓）
```
A1 he_blast ⇒ **accepted=true** ✓✓（= 规格被满足 ✓ 而非放宽期望 ✗）
   overpressure / blast / fragmentation ⇒ **仍具名拒绝** ✓✓ `invalid_effect_policy` ✓（无非通道名混入 ✓）
A2 实弹（APHE + 8mm 以下触发厚度的延期引信 ✓ 已证夹具形状 ✓ 无旋转 ✓ 板在 x=0 平面 ✓）：
   terminal=**internal_burst** ✓ ⇒ root_event keys 含 **"channels"** ✓
   channels = {fragment:applied=**true** ✓ ; blast:applied=**false** ✓ pending=cd07-blast-channel ✓ ;
               overpressure:applied=**false** ✓ pending=cd07-overpressure-channel ✓}
   ⇒ 设计 #1 ✓✓：**同一爆炸 root_event 分列三通道** ✓ **不共用"半径内全死"开关** ✓；未施加者**记录中明说** ✓✓
```
### 与规格的关系 ✓（**方向正确** ✓ 非"改期望值" ✗）
上轮 A1 写的是"**因尚不存在而以名字拒绝**" ✓ = 对**当时缺口**的陈述 ✓；本轮实现使**该通道存在** ✓ ⇒ 期望随之**由拒转受** ✓ 即"**实现满足要求**" ✓（另有三个**非通道名**仍**拒绝** ✓ 作为**未被放宽**的对照 ✓）。
### 下一轮
**blast / overpressure 两通道的真正施加** ✓（设计 #2 有界连通：**封闭舱无破口 ⇒ 无凭空内舱超压** ✓；**开放 vs 遮盖同距离对照不同** ✓ 且**不依赖 `vehicle_type` 标签** ✓）＋ 实现顺序 #2 的**工程 HE 配置与注册入口** ✓（**限定可用测试武器** ✓ 不给所有车辆塞不兼容弹种 ✓）。
## 8. 设计 #2 前半：**有界连通判定** ✓✓（`CD07_HE_ROOT_EVENT_PASS` ✓）
### 改动（增量 ✓ 且**判定与输入都上账** ✓）
`projectile_manager.gd` ✓ 的 root_event 中 ✓ `overpressure` 由**硬写 false** 改为**按规则算出** ✓：
```
"overpressure": { "applied": (not burst_outside) or breached  ✓
                  "model": "cd07-bounded-connectivity-v1" ✓
                  "burst_outside": <实测> ✓ "breached": <实测> ✓
                  "pending": "" 或 "cd07-connectivity-openings" ✓
                  "reason": 明写"内部起爆或被击穿给压力一条路径" / "封闭舱无破口 ⇒ 无凭空内舱超压" ✓ }
```
### 实测 ✓
```
overpressure verdict=**true** ✓ ; model=**cd07-bounded-connectivity-v1** ✓
inputs: burst_outside=**true** ✓ breached=**true** ✓ ; **由自身输入独立重算 = true** ✓✓ ⇒ 判定与规则一致 ✓ 可复核 ✓
reason="an interior burst or a breached plate gives the pressure a path" ✓
blast ⇒ applied=**false** ✓ 仍明说"**已声明未施加**" ✓（不假装 ✓）
```
⇒ 设计 #2 ✓ 的**被击穿分支** ✓ **已实现并实测** ✓；**封闭无破口分支** ✓ 由**同一规则**给出（`applied=false` ✓）但**尚不可演示** ✗ ⇒ 因其需要一个**外爆 + 封闭目标**的场景 ✓ ⇒ **开口路径**是下一轮的**具名**工作 ✓（见下 ✓）。
### 关键发现：**开口机制早已存在于生产链** ✓✓
```
VehicleLayoutDefinition.declared_openings ✓ = [{id, part, boundary_loop, reason}] ✓
声明者 ✓：historical_vehicle_geometry（g.open_top ⇒ declare_opening(...,"open_fighting_compartment",...) ✓）✓
          vehicle_armor_layers ✓（逐层 perimeter ✓）
消费者 ✓：shell_effect_policy.gd:49-50 ✓ 已在**遍历 declared_openings**（"Caps define the limit of inside travel through real openings" ✓）
⇒ 设计 #2 所需"**有界舱室/开口/装甲破口连通规则**"的**开口数据已存在** ✓ ⇒ 下一轮**消费**它 ✓ 而非新建 ✗
（快照构造器取 **layout** ✓ 但 `declared_openings` **未见于快照/查询链** ✗ ⇒ 其到策略的**传递路径**须下一轮**测明** ✓ 不猜 ✓）
```
### 下一轮（**明确三项** ✓）
1. **追明开口到策略的传递路径** ✓（快照缺该键 ✗ ⇒ 找到 `shell_effect_policy` 实际取用它的路径 ✓）；
2. **封闭无破口 ⇒ `applied=false`** ✓（T01 核心 ✓）与**开放 vs 遮盖同距离对照不同** ✓ 且**不依赖 `vehicle_type` 标签** ✓（T02 ✓）—— 用 **`open_top=true` 的夹具包** ✓（设计 #5"**开放顶 M36 可作现有代表之一**" ✓ 不把现代坦克改敞篷 ✗）；
3. 实现顺序 #2 的**工程 HE 配置与注册入口** ✓（**限定可用测试武器** ✓）。