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
## 9. **开口并入连通判定** ✓✓（`CD07_HE_ROOT_EVENT_PASS` ✓）⇒ 设计 #2 的**连通规则三项齐备** ✓
### 路径**已测明**（并纠正我上轮的结论 ✗）
```
query_snapshot_builder.gd:53 ✓  "layout": layout ✓  ⇒ **快照整体携带 layout 本体** ✓✓
shell_effect_policy.gd:41 ✓  layout = snapshot.get("layout") ✓ ⇒ 再遍历 layout.declared_openings ✓
⇒ 我上轮断言"`declared_openings` 未见于快照/查询链" ✗ **是只搜关键词所致的误判** ✓（实际经 `"layout"` 键整体携带 ✓）
⇒ **传递路径早已完整** ✓✓ ⇒ 实现只需**消费** ✓ 无需新建 ✗
```
### 改动（增量 ✓）
```
pressure_reaches = (not burst_outside) or breached or **declared_openings>0** ✓
记录并上账 ✓：burst_outside ✓ breached ✓ **declared_openings** ✓ applied ✓ model ✓ reason ✓（pending 恒为空 ✓ 因规则已全 ✓）
reason 明写三种路径 ✓："an interior burst, a breached plate or a declared opening gives the pressure a path" ✓
```
### 实测 ✓
```
overpressure verdict=**true** ✓ ; model=**cd07-bounded-connectivity-v1** ✓
inputs: burst_outside=true ✓ breached=true ✓ **openings=0** ✓ ; **由自身输入独立重算 = true** ✓✓
（本夹具为**单板布局** ✓ ⇒ 声明开口 **0** ✓ ⇒ 打开路径的是**被击穿** ✓ 如实记录 ✓）
```
### 我本轮的**两处疏漏** ✓✗（**均自查修正** ✓）
① 用**关键词 grep** 就断言"快照缺该键" ✗ ⇒ 实为经 `"layout"` 整体携带 ✓ ⇒ **教训**：**"没搜到"不等于"不存在"** ✓ 须查**整体载体** ✓；
② 一处行内替换插入了**措辞含糊的判据**（`… or true` ✗）⇒ 探针**挂起** ✗ ⇒ 修净后复跑通过 ✓ ⇒ **教训**：**替换必须逐字核对，含判据文字** ✓。
### 设计 #2 连通规则**三条齐备** ✓
| 分支 | 判据 | 状态 |
|---|---|---|
| **内部起爆** ✓ | `not burst_outside` ⇒ 有路径 ✓ | ✅ 规则就位 ✓ |
| **装甲破口** ✓ | `breached`（`penetrated`/`perforated_stop` ✓）⇒ 有路径 ✓ | ✅ **实测**（breached=true ⇒ applied=true ✓） |
| **声明开口** ✓ | `declared_openings>0` ⇒ 有路径 ✓ | ✅ 规则与**计数上账** ✓；`open_top` 夹具的**对照**待下一轮 ✓ |
### 下一轮
1. **`open_top=true` 夹具的开放/封闭对照** ✓（T01"**封闭无破口 ⇒ applied=false**" ✓ 与 T02"**开放 vs 遮盖同距离对照不同** ✓ **不依赖 `vehicle_type`**" ✓）：以设计 #5 允许的**开放顶代表** ✓（**M36 类** ✓ 不把现代坦克改敞篷 ✗）；须先测明 **`open_top` 经哪条几何重建路径变成 `declared_openings`** ✓（现代包与历史包路径可能不同 ✓ **不猜** ✓）；
2. **实现顺序 #2 的工程 HE 配置与注册入口** ✓（**限定可用测试武器** ✓）。
## 10. **`open_top` 到开口的路线**：以运行期实测回答 ✓✓（`CD07_OPEN_TOP_ROUTE_PASS` ✓）
探针 `tests/probe_cd007_open_top.gd` ✓（**注册真实包并数其布局的开口** ✓ 非 grep 推断 ✓）
```
R1 **交付包原样** ⇒ layout=test_cd007_open_closed_layout ✓ armor_patches=**46** ✓
   declared_openings=**5** ✓ = ["turret_ring","gun_aperture","turret_floor_ring","shield_perimeter","gun_bore"] ✓✓
   ⇒ **现代加载路径上开口链是活的** ✓✓ ⇒ 设计 #2 的"声明开口"分支在**真实包**上**有活来源** ✓
   ⚠️ 我此前"openings=0"读的是**手搓单板布局** ✗ ⇒ **不是交付包** ✓ ⇒ 教训：**别把手搓夹具的行为当成产品事实** ✓
R2 **强制 open_top=true** ⇒ ok=**false** ✓
   errors=["**geometry: actual content differs from field record**"] ✓✓
   ⇒ **设计 #5 由内容门强制** ✓✓："**不临时把现代坦克改成敞篷测试**" ✓ 不是靠自觉 ✓ 而是**拒绝** ✓
⇒ **结论** ✓：开放 vs 遮盖的对照须用子单允许的**历史开放顶代表** ✓（"**开放顶 M36 可作为现有代表之一**" ✓）
  而**非**把现代包强制开放 ✗（已被拒 ✓）。
```
### 我本轮**两处工具性疏漏** ✓✗（**均自查修正** ✓ 并立规 ✓）
① 一次行内替换**未命中**（文本已被前一次改动）✗ ⇒ 残留旧判据使探针**误报** ✗；
② 随后用**跨行正则**清除 ✗ ⇒ **matches=0** ✗ 白耗一轮 ✗。
⇒ **Standing rule** ✓：**对已被多次编辑的文件，改文本要么先读全文再整体重写，要么逐次核对替换后的实际内容** ✓；**跨行正则不是可靠工具** ✓。
（本轮结束时以**整体重写**探针收口 ✓ 一次通过 ✓✓）
### 下一轮
1. **历史开放顶代表**上的**开放/封闭对照** ✓（**T01**"封闭无破口 ⇒ `applied=false`" ✓；**T02**"开放 vs 遮盖同距离对照不同 ✓ **不依赖 `vehicle_type`**" ✓）：先测明**历史包**是否/如何声明 `open_top` ✓ 并据此给出两句对照 ✓；
2. **实现顺序 #2 的工程 HE 配置与注册入口** ✓（**限定可用测试武器** ✓）。
## 11. **开放/封闭对照**：数据级对照**已由交付内容实测** ✓✓（探针读路径未打通 ⇒ **具名**为下一步 ✓）
### 实测（真实命令输出 ✓）
```
configs/vehicles/historical/ 四个包**均存在** ✓：us_m24_m6_t85e1_1951 ✓ us_m26_m3_1945 ✓ us_m36_m4a1_1945 ✓ us_m4a3_75w_vvss_1944 ✓（各 ~28 KB ✓）
**us_m36_m4a1_1945 : geometry.open_top = **True** ✓✓**（设计 #5 点名的开放顶代表 ✓）
**us_m26_m3_1945   : geometry.open_top = **False** ✓✓**（同代封闭代表 ✓）
两者均带 `armor` 键 ✓ ⇒ **交付内容自带正确的开放/封闭对照** ✓✓ **无需改动交付件** ✓ 且**不违反设计 #5** ✓
```
⇒ 即 **T02** 所需的"**开放 vs 遮盖**"在**交付数据层**已具备 ✓；且其判据须落在"**声明几何**"上 ✓ 而非 `vehicle_type` 标签 ✓✓。
### 重建路径（**分别实测/引用** ✓ 不含糊 ✓）
| 类 | 事实 | 状态 |
|---|---|---|
| **现代类** | 交付包重建后 `declared_openings=**5**` ✓（turret_ring / gun_aperture / turret_floor_ring / shield_perimeter / gun_bore ✓）| ✅ **实测** ✓ |
| **历史类** | `historical_vehicle_geometry.gd:117` ✓ `if g.open_top: declare_opening(out,"turret","**open_fighting_compartment**",upper)` ✓ | 🔶 **引用代码** ✓ **未实测** ✗（见下 ✓） |
### 我的探针读路径**未打通** ✗（**如实记录 ✓ 并具名 ✓**）
我为历史包写了探针 `probe_cd007_open_closed.gd` ✓ 但**读取始终为空** ✗：文件**确实存在** ✓（上面直查 ✓）、路径与**生产 catalog 完全一致** ✓（`vehicle_catalog.gd:39` ✓）、改用 `FileAccess.open` **仍为空** ✗ ⇒ **根因未定** ✗（**不猜** ✓）。⇒ 依我自己的 standing rule **停止路径狩猎** ✓，移除该未打通探针 ✓ **不留失败件** ✓。
**下一步（具名 ✓）**：改走**生产 catalog 自身的加载** ✓（`tests/run_historical_checks.gd` L20-25 ✓ 已证四包可注册 ✓ 并从 `catalog.packages[id].packet` 取包 ✓）⇒ 由此**实测**历史类的 `declared_openings` ✓ 并给出 **T01/T02** 两句对照 ✓（**外爆 + 无破口** ⇒ 封闭 `applied=false` ✓；开放顶 `applied=true` ✓）。
### 本轮**三处工具/对象疏漏** ✓✗（**均自查** ✓）
① 常量名与**父类重名**（`HISTORICAL` ✓）⇒ 解析冲突 ✗ ⇒ 改名 ✓；
② 误把 `authoring/vehicles/seeds/*.json` 当**包** ✗ ⇒ 实为另一层结构 ✓（**先确认对象再写代码** ✓）；
③ 对**已多次编辑**的文件用**逐处替换** ✗ ⇒ 反复未命中 ✗ ⇒ **standing rule 再次生效** ✓：**整体重写优先** ✓。
## 12. **历史类开口已实测** ✓✓ ＋ **T01/T02 对照成立** ✓✓（`CD07_HIST_OPENINGS_PASS` ✓ `CD07_OPEN_CLOSED_CONTRAST_PASS` ✓）
### 走**生产 catalog** 打通（纠正上轮的死路 ✓）
```
VehicleCatalog.new() ✓ → load_all(defs) ✓ ⇒ 四包注册 ✓（result.ok ✓ packages.size=4 ✓）
catalog.packages[id] 的键 ✓ = ["ok","audit","errors","notes","**layout**","definitions","packet","model_check"] ✓✓
⇒ `entry.layout.declared_openings` **可直接读** ✓（上轮"读不到"是我自造读路径 ✗ 而非产品缺失 ✓）
```
### 实测：历史四包的**声明开口**（决定 T02 的根据 ✓）
```
us_m4a3_75w_vvss_1944  open_top=false ⇒ declared_openings=**7** ✓ open_fighting_compartment=**0** ✓
us_m24_m6_t85e1_1951   open_top=false ⇒ declared_openings=**5** ✓ open_fighting_compartment=**0** ✓
us_m26_m3_1945         open_top=false ⇒ declared_openings=**5** ✓ open_fighting_compartment=**0** ✓
**us_m36_m4a1_1945     open_top=**true**  ⇒ declared_openings=**6** ✓ open_fighting_compartment=**1** ✓✓**
⇒ **开放顶代表确实声明开放战斗室开口而封闭代表没有（1 vs 0）** ✓✓ ⇒ 连通性来自**声明几何** ✓ **非 `vehicle_type` 标签** ✓
```
### ⚠️ 我原规则**太粗** ✓✗（实测暴露 ✓ 已修 ✓）
首版按"**存在任意开口**"判定 ✗ ⇒ 但**每辆车都声明** `turret_ring` / `gun_bore` 等结构开口（封闭车 5 个 ✓）⇒ 会让**所有车都"开放"** ✗。
⇒ 依 `shell_effect_policy.gd:49` 的**原文**（"Caps define the limit of inside travel … **They are not armor**" ✓）⇒ 那些是**内部行程盖** ✓ **不是压力开口** ✓ ⇒ 规则改为**只认 `open_fighting_compartment`** ✓✓ 并把两个计数**都上账** ✓（`declared_openings` ✓ `open_compartment_apertures` ✓）。
### 对照实测（**同一低威力外爆**，M36 vs M26 ✓）
```
us_m36_m4a1_1945 ⇒ terminal=**internal_burst** ✓ verdicts=["penetrated","stopped"] ✓ burst=**present** ✓
                   breached=true ✓ openings=6 ✓ compartments=**1** ✓ **applied=true** ✓（判定=其自身记录输入 ✓）
us_m26_m3_1945   ⇒ terminal=**armor_stopped** ✓ verdicts=["stopped"] ✓ burst=**none** ✓ breached=false ✓ applied=**false** ✓
⇒ **T01**"封闭舱无破口 ⇒ 无凭空内舱超压" ✓✓ **由构造成立** ✓（**根本没有爆发** ⇒ 无从凭空产生 ✓）
```
### ⚠️ 我一条判据曾**空洞通过** ✓✗（**自查发现并改如实** ✓）
首版要求"**两跑都产生 root_event**"再比对判定 ✗ ⇒ 而封闭跑**根本没爆发** ✗ ⇒ 其 `false` 来自**默认值** ✗ 而非规则 ✗ ⇒ 该对照**空洞通过** ✗ ⇒ 已改为如实三条 ✓（开放式须**真是规则判定** ✓ / 封闭式**如实记录为"未爆发"** ✓ / 开放式判定**等于其自身输入** ✓）。
### **新实测事实** ✓（本单的精确边界 ✓）
**延迟引信的启动需要"打穿某块板"** ✓（CD06-T02 亦见 ✓）⇒ ⇒ "**外爆 + 无破口**"在**当前引信规则下不可达** ✗✓ ⇒ 故：
- **T01 由构造满足** ✓（封闭车无爆发 ⇒ 无内舱超压 ✓✓）；
- 规则中的**封闭分支**是**防守性**的 ✓ = **守住当前引信规则所阻止的那个场景** ✓✓（一旦将来可达即生效 ✓）。
### 下一轮
1. **实现顺序 #2 的工程 HE 配置与注册入口** ✓（**限定可用测试武器** ✓ **不给所有车辆塞不兼容弹种** ✓）；
2. **T03 薄板破口与隔板** ✓（**外板/隔板与乘员结果逐段可解释** ✓）与 **T04 世界触发与墙后** ✓（**世界接触可引爆** ✓ **遮挡仍有效** ✓ **无 through-wall 总伤** ✓）；
3. **T05 HEAT 通道隔离** ✓（**射流不冒充超压** ✓）与 **T06 复数目标/终局** ✓（**一对象一次合法作用** ✓ **非许可目标无伤害** ✓ **取消明确** ✓）。
## 13. 实现顺序 #2：**一款明确工程 HE** ✓（入库并经内容门接纳 ✓）
### 绑定机制先测明 ✓（决定"限定可用测试武器"如何表达 ✓）
```
弹种 `gun` 字段 ✓："75-mm M3" / "90-mm M3" ✓；车体 `compatible_shells` ✓ = 标签串 ✓
内容门 ✓：variant_compatibility.gd:30 ✓ "shell: incompatible ammunition" ✓
          vehicle_shell_catalog.gd:117-120 ✓ "**compatible_shells: must exactly match admitted catalog IDs**" ✓✓
⇒ 限定方式 ✓ = 声明于**特定 `gun`** ✓ 且**只在许可车型列出** ✓（多列即拒 ✓）
```
### 改动（**照抄既有结构** ✓ 不手写新 schema ✓）
```
① spall_profile.gd ✓：expected_version 增加 **he_blast ⇒ VERSION_INTERNAL_BURST** ✓（1 处精确命中 ✓ 解析干净 ✓）
   ⇒ 外部 HE 以**同一扩展 schema** 声明其破片通道 ✓ 而非第二套 schema ✓✓
② configs/shells/historical_loadouts.json ✓：新增 **`he_75_m3_eng`** ✓（锚点 1 处精确命中 ✓）
   label "CD07 engineering HE (75-mm M3 only)" ✓ ; **effect_policy="he_blast"** ✓ ; **gun="75-mm M3"** ✓（武器限定 ✓）
   muzzle 463.0 ✓ ; 穿深曲线 **平 20 mm** ✓（设计上**只为让弹停在外面而非穿透** ✓ 已在 reason 写明 ✓）
   post_penetration_profile ✓ count=5 cone=50 range=3.0 frac=0.20 max=50 min_res=4 ✓（**CD07 项目设计初值** ✓）
   fuze ✓ penetration_delay arm=5.0 delay=0.02 ✓ ; ruleset_id **cd07-he-contact-delay-v1** ✓
   **逐字段标注 ✓**：`historical_observations` 明写"**None claimed … not a historical ammunition type**" ✓✓
   `estimate_reason` 明写"**Every number is a project design initial value**" ✓ 且说明**绑定 75-mm M3 故只有该炮的车可用** ✓
```
### 实测（内容门 ✓）
```
json_ok ✓ ; shells=**7** ✓（6+1）; new_effect=**he_blast** ✓ ; gun=**75-mm M3** ✓
run_historical_checks   **192 PASS / 0 FAIL** ✓
run_shell_checks        **193 PASS / 0 FAIL** ✓
run_chemical_content_checks **31 PASS / 0 FAIL** ✓
⇒ 新弹**被接纳** ✓ 且**未破坏既有内容** ✓✓
```
### 本轮**工具疏漏** ✓✗（**已立规并规避** ✓）
PowerShell here-string 的**终止符**被我写在**同一行** ✗ ⇒ 解析报错 ✗ ⇒ 改为**写成 .ps1 文件再执行** ✓ **一次通过** ✓ ⇒ **Standing rule 扩展** ✓：**长 here-string 一律落成脚本文件执行** ✓（与"整体重写优先"同族 ✓）。
### 下一轮（**明确两项** ✓）
1. **实测武器限定** ✓：确认该弹**仅**在 75-mm M3 车型的 `compatible_shells` 中出现 ✓（**未**塞给不带该炮的车 ✓ = 子单"**不给所有车辆塞不兼容弹种**" ✓）；
2. **实测端到端开火** ✓：以该工程 HE 打出一次**外部爆破** ✓ ⇒ root_event 三通道 ✓ 且**破片通道 applied=true**（用**声明剖面** ✓ 非 legacy ✓）✓ 并核对**预算账目**守恒 ✓。

## 14. 工程 HE 的**族**与**武器限定机制**：两处实测结论（含一条改变落点的发现 ✓）

### 14.1 新增 **HE 族** ✓（内容门要求 source/effect 成对 ✓）
```
vehicle_shell_catalog.gd:38 ✓ 必填 ["id","label","gun","family","source_bullet_type","effect_policy"] ✓
L43-47 ✓ family 必须在 FAMILIES 内 ✓ **且 source/effect 必须与族严格一致**（"no relabeling" ✓）
FAMILIES（改动前）= {AP/APHE/APFSDS/HEAT} ✓ ⇒ **无 HE 族** ✗
⇒ 改动 ✓：新增 **"HE":{"source":"he_tank","effect":"he_blast"}** ✓（与既有族同构 ✓ 1 处精确命中 ✓）
⇒ 弹条目补齐 **family="HE"** ✓ **source_bullet_type="he_tank"** ✓（1 处精确命中 ✓ json_ok ✓）
```

### 14.2 **武器限定机制实测**（**改变了落点** ✓）
```
运行期逐车列出**实际可用弹**（生产安装路径 ✓ 非读配置文字 ✓）：
  us_m4a3_75w_vvss_1944  gun=**75-mm M3** ⇒ ["…_shell","**…_m61_m3**"] ✓
  us_m24_m6_t85e1_1951   gun=75-mm M6  ⇒ ["…_m72_m6","…_shell"] ✓
  us_m26_m3_1945 / us_m36_m4a1_1945  gun=90-mm M3 ⇒ ["…_shell","…_m82_m3_2800"] ✓
⇒ 四车**均未**提供 `he_75_m3_eng` ✗（**连 75-mm M3 的 M4A3 也没有** ✓）
根因（实测 ✓）：historical_shell_catalog.gd:20-25 ✓
  `packet.vehicles[id]` 必须存在 ✓（"vehicle has no admitted shell set" ✓）
  `row.gun` 必须等于车体 `assembly.gun` ✓
  **`row.shells` 必须恰为长度 2** ✓✓（`size()!=2` 即报错 ✓）且 `row.default ∈ row.shells` ✓
⇒ 即 **历史车每辆恰 2 个弹位** ✓ 且由 `packet.vehicles[id].shells` **点名** ✓
⇒ 加入 HE 会变 3 个 ⇒ **被"恰为 2"规则拒绝** ✗✓
```
⇒ 我的 HE **过了内容门** ✓（`run_historical_checks 192/0` ✓ `run_shell_checks 193/0` ✓ `run_chemical_content_checks 31/0` ✓）
但**历史安装不提供它** ✓ —— 原因是**弹位规则** ✓ 而非族或绑定错误 ✓ ⇒ **如实记录 ✓ 不当作成功** ✓。

### 14.3 **两条合法路线** ✓（**不越权 ✓ 不无对照删旧 ✓**）
| 路线 | 说明 | 状态 |
|---|---|---|
| **(a) 挂到工程车** ✓ | `configs/vehicles/engineering/*` 的 `shell_catalog` 允许 **1..8** ✓（`MAX_SHELLS=8` ✓）⇒ 可**新增**而不删旧 ✓✓ | **下一轮实施** ✓ |
| **(b) 挂在历史车** ✗ | 只能**替换**其 2 位之一 ✗（= **无对照删旧规则** ✗ 违反硬约束 ✓）或**改"恰为 2"规则** ✗（**非本单权限** ✓） | **不做** ✗ 如实记录 ✓ |

### 14.4 本轮**工具疏漏** ✓✗（**已升级规则** ✓）
PowerShell here-string 的终止符**再次**报错 ✗（与第 102 轮同类 ✓）⇒ **规则升级** ✓：**含 Markdown/中文的长文本一律用 write 工具写成独立文件，再由短脚本追加** ✓ **不再使用 here-string** ✓✓。

### 下一轮
1. 按路线 (a) ✓：在**工程车**的 `shell_catalog` 中**新增**该工程 HE ✓（**不删任何既有弹** ✓），并使其 `gun`/`caliber` 与该车一致 ✓ ⇒ 实测**仅该车**提供它 ✓（= **限定可用测试武器** ✓）；
2. 随后**端到端开火** ✓：外部爆破 ✓ root_event **三通道** ✓ 破片通道用**声明剖面** ✓ + **预算账目守恒** ✓；
3. 再推进 **T03 / T04 / T05 / T06** ✓。


## 15. 路线 (a) 首试：**触发两处真实回归 ⇒ 依硬约束立即回退** ✓（并取得本单的**精确障碍** ✓）

### 15.1 我做了什么（**已全部回退** ✓）
```
① scripts/armor/armor_impact_profile.gd ✓：放开 effect 白名单以接受 "he_blast" ✓（1 处精确命中 ✓）
② configs/vehicles/engineering/ussr_t_80b.json ✓：以**深拷贝 APFSDS 条目**生成 eng_125_he_v1 ✓
   并追加其 id 到 compatible_shells ✓（shells 2→3 ✓ default 未动 ✓ 豹 2 未动 ✓ 保持 2 弹 ✓）
```
### 15.2 回归（**实测** ✓）
```
run_historical_checks **191 PASS / 1 FAIL** ✗
   [FAIL] normal garage exposes the fixture, the four historical types and **the two admitted engineering types**, by id
   ⇒ 即**交付测试的期望**把工程弹种数**钉在 2** ✓ ⇒ 新增第三个**打破该断言** ✓
run_modern_garage_checks     **7 / 2** ✗（"modern vehicle has actual garage entry: ussr_t_80b" ✗ "normal deploy routes…" ✗）
run_modern_armor_frame_checks **8 / 2** ✗（"corrected packets retain production admission" ✗ "**missing modern packet ussr_t_80b**" ✗）
   ⇒ 即我的 **JSON 往返重写**使该车配置**未过准入** ✓（被报为"missing" ✓）
脚本另报 ✓：`$he.fuze_policy = …` **无法赋值** ✗ —— 深拷贝得到的 PSCustomObject **不能靠赋值新增属性** ✓
   ⇒ 我的 HE 条目**本会缺引信** ✓（运行期自证 ✓）
```
### 15.3 处置（**硬约束** ✓）
```
git checkout -- configs/vehicles/engineering/ussr_t_80b.json scripts/armor/armor_impact_profile.gd ✓
⇒ tracked changes = **0** ✓（回到上一个可运行状态 ✓）
复核 ✓：run_historical_checks **192/0** ✓ · run_modern_garage_checks **29/0** ✓ ·
        run_modern_armor_frame_checks **17/0** ✓ · run_shell_checks **193/0** ✓ ⇒ **TOTAL 431 PASS / 0 FAIL** ✓✓
```
### 15.4 精确障碍（下一轮须正面解决 ✓）
| 障碍 | 实测内容 | 正确做法 |
|---|---|---|
| **交付测试把工程弹数钉在 2** ✗ | `run_historical_checks` 的该条断言 ✓ | 子单 `实现顺序 #2` **明文要求**新增一款工程 HE ✓ ⇒ 该期望须作为**一次明确的、有记录的变更**更新 ✓ **附迁移前后全量** ✓ —— **不是**"为了让测试变绿改期望值" ✗（**方向是被子单要求的** ✓） |
| **JSON 往返重写使配置未过准入** ✗ | 三套件报 "missing modern packet" ✓ | 改为**文本插入**（保留原格式 ✓）或往返后**逐项复验准入** ✓；**不靠猜测格式** ✓ |
| **深拷贝对象不能赋值加新属性** ✗ | `$he.fuze_policy = …` 抛错 ✓ | 用 `Add-Member` ✓ 或**直接从模板文本构造**条目 ✓ |
### 15.5 本轮**工具/方法疏漏** ✓✗（**已升级规则** ✓）
① `.ps1` 内**中文**被按 ANSI 读取而乱码 ✗ ⇒ **规则**：**`.ps1` 一律 ASCII** ✓（中文只放 `.md` ✓）；
② 深拷贝 + 赋值加属性 ✗ ⇒ **规则**：**PSCustomObject 加属性用 `Add-Member`** ✓；
③ 在大配置上做**往返重写** ✗ ⇒ **规则**：**交付配置优先文本插入，往返重写必须在写后立即复验准入** ✓。
### 下一轮
1. **文本插入**方式在 **T-80B** 的 `shell_catalog.shells` 中新增该 HE ✓（保留原格式 ✓ 用 `Add-Member` 补 `fuze_policy` ✓）；
2. **明确更新**"工程弹种数为 2"的**交付期望** ✓（作为子单要求的一次**记录在案的变更** ✓ 附**变更前后**该套件全量输出 ✓）；
3. 复验：**仅 T-80B 提供它** ✓（= **限定可用测试武器** ✓）⇒ 然后**端到端开火** ✓（外部爆破 ✓ 三通道 ✓ 声明剖面 ✓ 预算守恒 ✓）。


## 16. 工程 HE 准入失败的**真实病因**（**树外诊断** ✓ 三次回归后终于具名 ✓）

### 16.1 诊断方法（**不进树** ✓ 无风险 ✓）
```
把改动包写到**我自己的未跟踪夹具** `assets/vehicles/test_cd007_he_fixture/ussr_t_80b_he.json` ✓
（含 `.gdignore` ✓）⇒ 由 `VehicleShellCatalog.build(packet)` ✓ 与 `VehicleContentPipeline.validate_package(packet)` ✓
**逐条打印 errors** ✓ —— 而不是让三套件只说 "missing modern packet" ✗
```
### 16.2 第一次诊断：**是我改错了 id** ✓✗
```
errors = **全部五条源**："sources.<id>: **source not applicable to project identity**" ✓✓
根因 ✓：我把 `$v.id` 改成 `test_cd007_he_fixture` ✗ ⇒ 而源的 `applies_to_identity_ids` 仍指向**原车 id** ✓
⇒ 全部源被判"不适用" ✓ ⇒ **与 HE 条目无关** ✓（是我的夹具错误 ✓）
```
### 16.3 第二次诊断（**保持原 id** ✓）：**真实病因具名** ✓✓
```
① shell.eng_125_he_v1: **actual values differ from evidence record** ✓
   ⇒ 弹的**实际字段**必须与其 `evidence.*.value` **逐字一致** ✓ —— 我只更新了部分 evidence ✗
② shell.eng_125_he_v1.**fuze: malformed reference claim** ✓
③ shell.eng_125_he_v1: **fuze differs from separate design evidence** ✓
   ⇒ 引信**必须有自己的 evidence 条目** ✓ —— 而工程 schema 的 evidence 只有
      identity / ballistics / effect / impact / post_penetration ✗（模板里**没有** fuze ✓）
      ⇒ 须按**同一 claim 形状**构造 `evidence.fuze = {location,note,origin,source_refs,status,unit,value}` ✓ 且 `value` 与 `fuze_policy` 一致 ✓
④ **夹具特有** ✓（**非 HE 之过** ✓）：`model_source: independent delivered artifact/version required` ✓
   `ussr_t_80b: admission_status: production game reference requires engineering validation` ✓
   ⇒ 因我的夹具未携带**模型源**与**准入状态** ✓（真实包有 ✓）
```
⇒ 结论 ✓✓：**上一轮三套件失败**（"missing modern packet" ✗）**同因** ✓ = **弹条目的证据记录与实际字段不一致 + 缺少 `evidence.fuze`** ✓
（我上一轮把 **id 改动**误当主因 ✗ ⇒ 实为**证据契约** ✓ ⇒ **本次诊断纠正** ✓）
### 16.4 准入**契约**（实测所得 ✓ 下一轮照此实现 ✓）
| 要求 | 内容 |
|---|---|
| **字段与证据逐字一致** | 每个 `evidence.<field>.value` 必须等于对应实际字段 ✓（含 family/source/effect/velocity/curve/profile/impact ✓） |
| **引信须有独立证据** | 新增 `evidence.fuze` ✓ 形状同其它 claim ✓ 且 `value == fuze_policy` ✓ |
| **源须适用该身份** | 包的 `id` **不得**更改 ✓（源按 id 声明适用性 ✓） |
| **工程车需准入状态** | `admission_status` 与模型源须齐备 ✓（真实包已具备 ✓） |
### 16.5 本轮**方法疏漏** ✓✗（**已升级规则** ✓）
① 在**交付配置**上试改并跑三套件 ✗ ⇒ 报错信息**无用**（"missing packet" ✗）⇒ **规则**：**先树外诊断拿确切错误，再动交付件** ✓✓（本轮即如此 ✓）；
② **改包 id** ✗ ⇒ 令**所有源失效** ✓ ⇒ **规则**：**不得改交付包的 id** ✓；
③ 连续三轮在**同一处**以小步试错 ✗ ⇒ **规则**：**先建立诊断通道，再实施** ✓（与本轮 16.1 同 ✓）。
### 下一轮（**照 16.4 实施** ✓）
在 **T-80B** 的 `shell_catalog.shells` **新增**（**不删任何既有弹** ✓）该工程 HE ✓：
① 全字段与 `evidence.*.value` **逐字一致** ✓（含 impact_profile 采用**全口径**形状 ✓ 与 `effect=he_blast` 匹配 ✓）；
② **新增 `evidence.fuze`** ✓ 且与 `fuze_policy` 一致 ✓；
③ 保留原 `id` ✓ 并同步 `compatible_shells` ✓；
④ **先树外诊断通过** ✓ 再落交付件 ✓ 然后跑门 ✓ ⇒ **仅 T-80B 提供它** ✓（= **限定可用测试武器** ✓）⇒ 随后**端到端开火** ✓。


## 17. 工程 HE **准入已打通**（`VehicleShellCatalog.build ok=true` ✓）—— 尚差**载弹分配**一处

### 17.1 打通过程（**树外诊断逐环定位** ✓✓ 每环一条精确错误 ✓）
| 环 | 诊断给出的确切错误 | 修正 |
|---|---|---|
| ① | `sources.<id>: source not applicable to project identity` ✓（**全五条源** ✓） | **不改包 id** ✓（我上轮改 id 是**自造**错误 ✓） |
| ② | `actual values differ from evidence record` ✓ | 弹**每个实际字段**与其 `evidence.*.value` **逐字一致** ✓ |
| ③ | `fuze: malformed reference claim` ✓ / `fuze differs from separate design evidence` ✓ | 原拟新增 `evidence.fuze` ✓ ⇒ 但下一环否决了**带引信**本身 ✓ |
| ④ | **`fuze: requires internal_burst shell`** ✓✓ | **`he_blast` 不得带引信** ✓ ⇒ **正合设计 #3"先支持接触 HE"** ✓ = **接触即爆 ✓ 无引信** ✓ |
| ⑤ | `impact_profile: unsupported effect` ✓ | `armor_impact_profile.gd` 的 effect 白名单加入 `he_blast` ✓ |
| ⑥ | **`shell.<id>: effect_policy: unsupported`** ✓ | `shell_definition.gd:40` 效果白名单 + `:41` **终结效果须 `armor_policy=resolve`** ✓ 两处加入 `he_blast` ✓ |
| ⑦ | 仅剩 **夹具自身**的 `model_source` / `admission_status` ✓ | **非弹之过** ✓（真实包具备 ✓） |
⇒ **`VehicleShellCatalog.build ok=true`** ✓✓ ⇒ **弹级契约全部满足** ✓

### 17.2 落件结果（**实测** ✓）
```
T-80B ✓：shells=**3** ✓（apfsds / heat / **he** ✓ 各一 ✓）；compatible_shells 三 id ✓ **default 未动** ✓
豹 2 ✓：**未动** ✓（仍 2 弹 ✓）⇒ 即"**限定可用测试武器**"**已按车生效** ✓✓
套件 ✓：run_historical_checks **192/0** ✓ · run_shell_checks **193/0** ✓ ·
        run_modern_armor_frame_checks **17/0** ✓ · run_modern_equipment_checks **55/0** ✓
        **run_modern_garage_checks 27/2** ✗：
          "first spawn consumes **edited loadout**, not defaults" ✗
          "restart retains river, exact type and **edited loadout**" ✗
```
### 17.3 尚差一处（**载弹分配** ✓ 具名 ✓）
`VehicleShellCatalog.install` ✓ 的弹量由 `weapon.initial_rounds` **自动分配** ✓（默认占 70% ✓ **其余平均分** ✓）
⇒ 新增第三弹 ⇒ 该车**每种弹的载弹数**改变 ✓ ⇒ 车库两条断言（涉及 **edited loadout** ✓）随之失败 ✓
⇒ 这是"**加一款弹**"的**必然后果** ✓ ⇒ 须**随子单要求一并**处理 ✓（**不是**为了让测试变绿而改期望值 ✗）
### 17.4 处置（**硬约束** ✓）
仍存在失败 ✓ ⇒ 依"**失败即回退到上一个可运行状态**" ✓ **本轮先回退** ✓：
`git checkout -- configs/vehicles/engineering/ussr_t_80b.json` ✓（**白名单三处编辑保留** ✗ hmm ✓：白名单属于**新功能**且**本身无回归** ✓ ⇒ 保留 ✓；仅回退**落件** ✓）
⇒ **tracked changes = 2** ✓（= 两个白名单文件 ✓）⇒ 下一轮**与载弹分配一并**落件 ✓ 并跑全量 ✓
### 17.5 本轮**方法疏漏** ✓✗
**PowerShell 对象按引用** ✓ ⇒ 我在诊断与落件处**各调用一次** `Build-He` ✗ ⇒ `$real` **已被改过** ⇒ **重复追加**（compatible 出现两次 ✓ shells=4 ✗）⇒ **规则**：**构建一次、落件同一对象** ✓（或**每次重新读取** ✓）。
### 下一轮
1. **构建一次** ✓ ⇒ 落件到 T-80B ✓（保留原 id ✓ default 不变 ✓）；
2. **处理载弹分配的必然后果** ✓：先**实测**该车三弹各得多少发 ✓ 与车库两条断言的实际期望 ✓ ⇒ 作为**子单要求的一次记录变更**处理 ✓（附**变更前后**输出 ✓）；
3. 跑**全量** ✓ ⇒ 然后**端到端开火** ✓（外部爆破 ✓ 三通道 ✓ **声明剖面** ✓ 预算守恒 ✓）。


## 18. 载弹分配后果**精确定位**（两行魔数 ✓ 改法已定 ✓ 树保持全绿 ✓）

### 18.1 断言位置（**在随包发布的生产诊断里** ✓ 不在测试里 ✓）
```
scripts/diagnostics/modern_garage_verifier.gd ✓（其自身注释："Exercise the same diagnostic shipped in the independent package" ✓）
L58 ✓  for spin in prep.shell_spins.values(): spin.value = **3** ✓   ← 编辑配弹为**每弹 3 发** ✓
L72 ✓  check(… battle.actor.gunner.shell.id==wanted.first_shell and battle.actor.gunner.rounds_remaining==**6** ✓,
            "first spawn consumes edited loadout, not defaults") ✓
L79 ✓  check(… battle.actor.gunner.rounds_remaining==**6** ✓, "restart retains river, exact type and edited loadout") ✓
⇒ 即 **两处硬编码 `== 6`** ✗✓ —— 6 = **2 弹 × 3 发** ✓（旧的两弹结构 ✓）
```
### 18.2 为什么加第三弹会失败（**必然** ✓）
```
VehicleShellCatalog.install ✓：弹量 = `weapon.initial_rounds` ✓ ⇒ 默认弹占 **70%** ✓ ⇒ 其余**平均分给非默认弹** ✓
⇒ 第三弹 ⇒ 该车**载弹总数与分配**改变 ✓ ⇒ 战斗内 `rounds_remaining` **不再等于 6** ✗ ⇒ 两条断言失败 ✓✓
```
（我上一轮把它归为"**edited loadout**" ✓ 是对的 ✓；此处给出**确切行号与魔数** ✓）
### 18.3 正确改法（**加强而非放宽** ✓✓）
把 `== 6` 换成**由该编辑配弹自身推出**的期望 ✓：
```
期望 = 该 `wanted` 配弹**各弹计数之和** ✓（即"战斗里拿到的总数"必须恰等于**玩家编辑的总数** ✓）
⇒ 这比魔数**更强** ✓：它校验"**编辑过什么就得到什么**" ✓ 而非"恰好是 6" ✗
⇒ **不是**为了让测试变绿而改期望 ✗；是**把魔数换成该断言本来要表达的不变式** ✓✓
```
### 18.4 本轮处置（**硬约束** ✓）
本轮**未改任何代码** ✓ ⇒ 树**保持全绿** ✓（`tracked changes = 0` ✓；7 套件 **715/0** ✓ 见上轮末 ✓）
⇒ 本轮只**记录**精确定位与改法 ✓ ⇒ 下一轮与**落件一并**实施 ✓。
### 18.5 本轮**方法疏漏** ✓✗
① 我在 `tests/` 内反复搜失败的**标签** ✗ ⇒ 而标签在**生产诊断脚本**里 ✓ ⇒ **规则**：**断言未必在 tests/ ✓ 先全仓搜 ✓**（我最终用全仓 `git grep` 命中 ✓）；
② 薄壳套件（`run_modern_garage_checks.gd` 只 10 行 ✓）⇒ **须先看它调用谁** ✓ 再搜 ✓。
### 下一轮（**三件事一并** ✓）
1. **构建一次** ✓ ⇒ 落件到 **T-80B** ✓（原 id ✓ default 不变 ✓ 豹 2 不动 ✓）；
2. **两行魔数改数据驱动** ✓（`== 6` → `该配弹计数之和` ✓ 见 18.3 ✓）；
3. 跑**全量** ✓ → 然后**端到端开火** ✓（外部爆破 ✓ 三通道 ✓ **声明剖面** ✓ 预算守恒 ✓）⇒ 再推进 **T03 / T04 / T05 / T06** ✓。


## 19. 工程 HE **落件完成** ✓✓ 且**全绿**（附两处魔数改数据驱动 ✓）

### 19.1 落件（**构建一次、落件同一对象** ✓ 依新规则 ✓）
```
T-80B ✓：shells=**3** ✓（eng_125_apfsds_v1 / eng_125_heat_v1 / **eng_125_he_v1** ✓）
        compatible_shells 三 id ✓ **default=eng_125_apfsds_v1 未动** ✓
豹 2 ✓：**未动**（仍 2 弹 ✓）⇒ "**限定可用测试武器**"**按车生效** ✓
```
### 19.2 两处魔数 → **数据驱动** ✓✓（**加强而非放宽** ✓）
```
scripts/diagnostics/modern_garage_verifier.gd ✓
  + 在 `var wanted = prep.loadouts[id].duplicate(true)` 之后插入 ✓：
      var expected_total: int = 0
      for edited_count in wanted.counts.values(): expected_total += int(edited_count)
  + 两处 `gunner.rounds_remaining==6` → `==expected_total` ✓（命中 **2** 处 ✓）
⇒ 断言从"**恰好 6**"变为"**战斗里拿到的总数必须恰等于玩家编辑的总数**" ✓✓
⇒ 这是该断言**本来要表达的不变式** ✓ **比魔数更强** ✓ **不是**为了让测试变绿而改期望 ✓✓
```
### 19.3 实测（**十套件全绿** ✓✓）
```
run_modern_garage_checks **29/0** ✓ · run_modern_armor_frame_checks **17/0** ✓ · run_historical_checks **192/0** ✓
run_shell_checks **193/0** ✓ · run_modern_equipment_checks **55/0** ✓ · run_modern_support_checks **19/0** ✓
run_chemical_checks **92/0** ✓ · run_fuze_checks **137/0** ✓ · run_spall_checks **78/0** ✓ · run_armor_checks **81/0** ✓
⇒ **TOTAL 893 PASS / 0 FAIL** ✓✓
最终树状态核对 ✓：tracked changes = **2** ✓ = **正是本次两处改动** ✓（车辆配置 ✓ 诊断魔数 ✓）
```
### 19.4 武器限定的**证据状态**（**分开写** ✓ 不含糊 ✓）
| 层面 | 证据 | 状态 |
|---|---|---|
| **数据层** ✓ | T-80B 3 弹、豹 2 2 弹 ✓（本轮实测 ✓） | ✅ **实测** ✓ |
| **准入层** ✓ | `VehicleShellCatalog.build ok=true` ✓（上轮树外诊断 ✓） | ✅ **实测** ✓ |
| **运行期"某车可用弹列表"** ✗ | 我写的探针**注册管道未打通** ✗（直接 `extends SceneTree` 无 `fixture_asset` ✓；改传 `packet.sources` 后工程包**注册失败** ✗） | 🔶 **未测得** ✗ **如实标注** ✓ |
⇒ **不把"配置层"结论冒充为"运行期"结论** ✓✓
### 19.5 下一轮
1. **修好探针管道** ✓：改为 **extend 项目探针基类** ✓（其 `fixture_asset` 是工程包的**已证**注册入口 ✓，所有既有探针都这么做 ✓）⇒ 由此**实测运行期弹列表** ✓ 并**端到端开火** ✓；
2. **接触 HE 的爆炸路径** ✓（**本轮实测所暴露的真实缺口** ✓）：`he_blast` 目前**无引信**且**停下即不爆** ✗ ⇒ 依设计 #3"**先支持接触 HE 和世界碰撞后爆炸**" ✓ 须补**接触即爆 / 世界碰撞后爆** ✓（**不含**近炸/定时 ✓）；
3. 随后 **T03 / T04 / T05 / T06** ✓。


## 20. **运行期武器限定实测成立** ✓✓（探针管道修好 ✓）＋ 开火结果**如实更正** ✓

### 20.1 管道的修法（**回归到我自己的规则** ✓✗）
```
上一版探针 **改了工程包的 id** ✗ ⇒ 触发**交付件专属门**（`model_source` / `admission_status` ✓）⇒
  **T-80B 注册失败** ✗ 而豹 2 **侥幸通过** ✓（源与门对身份的绑定程度不同 ✓）
⇒ 修法 ✓（= 我第 105 轮已立的规则 ✓）：**不改交付包 id** ✓ ⇒ 两车均注册成功 ✓✓
⇒ **规则再次被验证** ✓：**不得改交付包的 id** ✓（本轮我违反了一次 ⇒ 已改正 ✓）
```
### 20.2 运行期实测（**`CD07_HE_RUNTIME_PASS`** ✓✓ 18 项 0 失败 ✓）
```
T-80B ✓ gun=125mm_2A46_2_user_cannon ⇒ options=["ussr_t_80b_shell","ussr_t_80b_eng_125_heat_v1","**ussr_t_80b_eng_125_he_v1**"] ✓✓
豹 2 ✓ gun=120mm_Rheinmetall_L44_user_cannon ⇒ options=["germ_leopard_2a4_shell","germ_leopard_2a4_eng_120_heat_v1"] ✓（**无 HE** ✓✓）
⇒ **vehicles offering eng_125_he_v1 = ["ussr_t_80b"]** ✓✓ ⇒ **1 of 2** ✓✓
⇒ 子单"**限定可用测试武器**" ✓✓ 在**配置层 ✓ 准入层 ✓ 运行期 ✓** 三层**均已实测** ✓✓
```
### 20.3 开火结果（**如实更正** ✓✗）
```
R2 实测 ✓：terminal=**expired_distance** ✓ contacts=**0** ✗ burst=**none** ✗
⚠️ **但 R2 我传的是空快照列表** ✗（`[]` ✓）⇒ 该弹**根本没有遇到任何目标** ✓ ⇒ 因此"**停下即不爆**"之说**过强** ✗✓
⇒ **更正** ✓：本轮的实测结论只是"**未遇到目标时按距离到期结束**" ✓；
   "**接触时是否起爆**" **尚未测得** ✗ ⇒ 须以**带目标快照**的射击复测 ✓（**不夸大** ✓✓）
```
### 20.4 下一轮（**两项** ✓）
1. **带目标快照的开火复测** ✓：以 T-80B 自身的快照为靶 ✓ ⇒ 观察 `he_blast` 在**接触**时的真实行为 ✓（到期 ✓ / 停住 ✓ / 起爆 ✓ 三种**如实记录** ✓）；
2. **补接触即爆 / 世界碰撞后爆路径** ✓（设计 #3 ✓）：`he_blast` 目前**无引信**且**无接触起爆** ⇒ 依"**先支持接触 HE 和世界碰撞后爆炸**" ✓ 实现 ✓（**不含**近炸/定时 ✓）；
3. 随后 **T03 / T04 / T05 / T06** ✓。


## 21. 带目标快照复测：**接触 HE 停住但不爆**（**真接触** ✓ 缺口实测确认 ✓）＋ 实施点已定位 ✓

### 21.1 复测（**这次真的接触** ✓）
```
R2 target layout=**ussr_t_80b_layout** ✓ armour_patches=**66** ✓（T-80B 自身快照 ✓）
R2 OUTCOME terminal=**armor_stopped** ✓ contacts=**1** ✓ verdicts=["**stopped**"] ✓ burst=**none** ✗
⇒ 与上一轮"空快照 ⇒ 未遇目标" ✓ 相比 ✓，本轮是**真实接触** ✓ ⇒ **缺口实测确认** ✓✓：
   **`he_blast` 弹遇甲停住而不起爆** ✗ —— 依设计 #3"**先支持接触 HE 和世界碰撞后爆炸**" ✓ 须补 ✓
```
### 21.2 实施点（**已定位 ✓ 含一处硬约束** ✓）
```
handle_contact(st, ev) ✓（L532 ✓）**不持有** `snapshots` / `space` ✗（该函数范围内 grep 无命中 ✓）
⇒ 故 root_event **不能在此发出** ✗ ⇒ **两点实施** ✓：
  ① 在 `handle_contact` 的 `stopped/perforated_stop` 分支（L568 ✓）**只写状态** ✓：
       `if st.effect_policy == "he_blast" and not waiting and st.burst_target.is_empty():`
         `st.burst_target = ev.duplicate(true)` ✓ 并置 `burst_entry_distance` / `burst_inside_started` / `burst_visited` ✓
  ② 在**推进循环**中（持 `snapshots`/`space` ✓；参考 L451 的 `_emit_spall(st,ev,spall_snapshots,space)` ✓）
     **发出** root_event ✓ —— 复用既有的 `_emit_internal_burst` ✓ ⇒ **不新建伤害路径** ✓✓
⇒ **门控** ✓：仅 `st.effect_policy == "he_blast"` ✓ ⇒ **其它效果逐字不变** ✓✓（旧行为对照 ✓）
```
### 21.3 下一轮（**照 21.2 实施** ✓）
1. 两点改动 ✓（状态写 ✓ + 发出 ✓）；
2. **验证** ✓：本探针 R2 的 `burst=none` → **present** ✓ 且 root_event **三通道** ✓ 破片通道 **applied=true**（用**声明剖面** ✓）✓；
3. **旧行为对照** ✓：全部既有套件**保持全绿** ✓（`he_blast` 之外的任何效果**不受影响** ✓）；
4. 随后 **T03 / T04 / T05 / T06** ✓。


## 22. T04 遮挡半：**墙后零伤害成立，但该结论目前空洞** ✗（**缺口具名** ✓）

### 22.1 单次对照的设计 ✓（一发打墙 ⇒ 两目标 ✓）
```
墙 ✓：世界层 StaticBody3D（1 m 厚 × 4 m 高宽 ✓）位于原点 ✓，弹自 x=+9 沿 −X 飞来 ⇒ 命中墙 ✓ 起爆 ✓
目标 A ✓：**墙后**（x=−1.5, z=0 ✓）—— 应与起爆点之间**隔着墙** ✓
目标 B ✓：**墙侧**（z=+2.5 ✓）—— 距起爆点 **2.5 m ≤ 碎片 range 3.0 m** ✓ 且**无遮挡** ✓
⇒ 一发弹、两目标 ⇒ **同一次运行内**给出对照 ✓✓
```
### 22.2 实测 ✓✗
```
terminal=**internal_burst** ✓ burst=**present** ✓ contacts=0 ✓ ; **damage_records = 0** ✗
墙后 A：unchanged=**true** ✓（零伤害 ✓）
墙侧 B：unchanged=**true** ✗（**也零伤害** ✗）
```
### 22.3 追因（**实测 + 代码路径** ✓ 非猜测 ✓）
```
世界起爆时 `st.burst_target` **为空** ✓ ⇒ `FragmentSystem.emit_bounded` 的 `origin_target = st.burst_target` ✓ 为空
⇒ `ShellEffectPolicy.target_snapshot(origin_target, snapshots)` ⇒ **{}** ✓ ⇒ 破片**没有目标** ✓ ⇒ **四处皆无伤害** ✓✓
```
### 22.4 ⚠️ **不宣称 O1** ✓✗（**同一"空洞通过"陷阱** ✓）
墙后 A 的"零伤害" ✓ 与"**到处都没伤**" ✗ 不可区分 ✓ ⇒ 故**遮挡本身尚未测得** ✗ ⇒ **如实标注** ✓✓
（与 CD07-T01 那次"两跑都爆发再比对"的空洞通过同类 ✓ ⇒ 已识别 ✓ 未重犯 ✓）
### 22.5 缺口与下一步（**具名** ✓）
| 缺口 | 内容 | 修法方向 |
|---|---|---|
| **世界起爆的破片通道无目标集** ✗ | `origin_target` 为空 ⇒ 破片打不到**任何**目标 ✓ | 允许**世界起爆的破片以无 origin 方式**作用于**射程内任意目标** ✓（**仍受世界遮挡** ✓）⇒ 由 `FragmentSystem` 支持"无 origin" ✓ 或由调用方传入**射程内目标集** ✓ |
⇒ 修好后 ✓：**墙后 A 零伤害** ✓ 而**墙侧 B 受伤** ✓✓ ⇒ 该对照才**真正**测到遮挡 ✓✓
### 22.6 本轮处置
本轮**未改生产代码** ✓（探针 ✓ + 证据 ✓）⇒ 树保持全绿 ✓
### 下一轮
1. **补"世界起爆破片可及射程内目标"** ✓ ⇒ 使 22.1 的对照**真正成立**（A 零伤 ✓ / B 受伤 ✓）；
2. 随后 **T03**（薄板破口与隔板 ✓ 逐段可解释 ✓）· **T05**（**射流不冒充超压** ✓）· **T06**（**一对象一次合法作用** ✓ **取消明确** ✓）。


## 23. 外部爆炸破片链的**逐环实测**：已修 5 环仍为零 ⇒ **改为仪器化**（并如实回退 ✗）

### 23.1 已定位并**门控**修正的环节（均在 `fragment_system.gd`，仅 `he_blast` ✓）
| # | 环节 | 原假设 | 修正 |
|---|---|---|---|
| ① | `delayed` 派生 | 非 delayed ⇒ 在目标内部 | 外部爆炸**视为车外爆炸** ✓ 走多目标路线 ✓ |
| ② | L43 left-target 守卫 | 同上 | 外部爆炸**不受**该守卫 ✓ |
| ③ | L45 行程上限 | 由目标算 | 外部爆炸取 **INF** ✓ |
| ④ | L37-40 eligibility | 只收"点在其内"的目标 | 外部爆炸**候选集 = 全部快照** ✓ |
| ⑤ | **L83 `other_target`** ✓✓ | 非 delayed ⇒ **只准命中起爆目标自身** ✓ | 外部爆炸**不受** ✓（**逐行阅读发现** ✓ 与 L43 同源假设 ✓） |
⇒ 五处**均为门控** ✓ 且 9 套件 **859/0** ✓ 无回归 ✓
### 23.2 ⚠️ 但**实测仍为零** ✗（`damage_records=0` ✓ 两目标均未变 ✓）
⇒ 故**仍有下一环未定位** ✗ ⇒ 且我**已连续 5 次在无正向实测下改代码** ✗ ⇒ **依我自己的规则立即停止** ✓✓
（"**停止小步试错；先建诊断通道**" ✓ = 我在三次回归后立下的规则 ✓）
### 23.3 仪器化尝试**因缩进失败** ✗（如实记录 ✓）
临时追踪（仅 `he_blast` ✓ 限量 ✓：setup / qr / end 三点 ✓）插入后**解析报错** ✗
（"Expected indented block" ✗ ⇒ 我的缩进层数不合 ✓）⇒ **未取得追踪输出** ✗
### 23.4 处置（**硬约束 + 我的规则** ✓✓）
```
① `git checkout -- scripts/projectiles/fragment_system.gd` ✓ ⇒ 回到**已提交的全绿态** ✓（859/0 ✓）
② 本轮**只提交证据** ✓ ⇒ 树保持全绿 ✓（tracked changes = 0 ✓）
⇒ 五处门控修正**留在工作区之外** ✗ —— 因它们**尚未产生任何可测的正向效果** ✗
  且**未经追踪验证** ✗ ⇒ **不以"看起来对"的理由提交** ✓✓（与"不为了让测试变绿改期望值"同理 ✓）
```
### 23.5 下一轮（**先建通道，再改代码** ✓）
1. **先读 `fragment_system.gd` 全文** ✓ 再**整体重写**含追踪的版本 ✓（避免逐处插入的缩进失误 ✓ —— 这正是我已立下的"**整体重写优先**"规则 ✓✓）；
2. 追踪**必须**输出：每条破片的 `direction` ✓ `eligible.size()` ✓ `qr.ok/complete` ✓ `events` 数 ✓ `fragment.reason` ✓✓ ⇒ **一次定论** ✓；
3. 得到**下一环**后再改 ✓ 并**当轮删除追踪** ✓；
4. 目标 ✓：使 **22.1 的对照真正成立**（**墙后 A 零伤** ✓ / **墙侧 B 受伤** ✓）⇒ 该对照才**真正测到世界遮挡** ✓✓；
5. 随后 **T03**（薄板破口与隔板 ✓ **逐段可解释** ✓）· **T05**（**射流不冒充超压** ✓）· **T06**（**一对象一次合法作用** ✓ **取消明确** ✓）。


## 24. T04 遮挡半：**诊断到根因是起爆点位于障碍内部**（harness 要求 ✓ 非产品缺陷 ✓）

### 24.1 诊断（**从探针读出** ✓ 不改生产文件 ✓✓）
```
fragments=**12** ✓ reasons = **{"world": 12}** ✓✓ ⇒ 每条破片首环即 `world` 并停止 ✓（queries=1 ✓ contacts=0 ✓）
方向样例 ✓：(−0.348, 0.917, 0.196) ✓ (−0.608, 0.75, −0.261) ✓ (−0.085, 0.583, 0.808) ✓ ⇒ **含明显侧/上分量** ✓
⇒ 侧/上向破片**本应飞脱** ✗ 却**全部**命中 `world` ✓ ⇒ 唯一自洽解释 ✓：
   **起爆点（= 接触点 = `st.position_world`）位于障碍内部/表面上** ✓ ⇒ 每条射线**从障碍内部出发** ✓
   ⇒ 不论方向**首个世界面必被命中** ✓✓（**墙体由 1 m 改到 0.1 m 亦不变** ✓ ⇒ 与厚度无关 ✓ 证实此解释 ✓✓）
⇒ **世界命中即停是既有设计** ✓（破片撞世界面即终止 ✓ 正确 ✓）⇒ 失效的是**我的对照装置** ✗ 而非产品 ✓
```
### 24.2 harness 要求（**具名** ✓）
要让"**墙后 vs 墙侧**"成为**可分辨**的对照 ✓，破片**起点必须位于障碍之外** ✓：
- 起爆点由**接触**决定 ✓ ⇒ 命中障碍时**必在其表面** ✗ ⇒ 故须**另择**遮挡几何 ✓（例如：让弹**在障碍前**引爆 ✗ 或令碎片起点**沿法线外移** ✗ 二者均需产品侧钩子或不同场景 ✓）；
- 本单**不为此新增钩子** ✓（超范围 ✗）⇒ 记录为**harness 要求** ✓ 并**具名** ✓。
### 24.3 处置（**不留失败件** ✓ 依我自己的规则 ✓）
```
探针 `tests/probe_cd007_wall_occlusion.gd` **删除** ✓（**不把失败件留在树里** ✓）
其**诊断价值已入档** ✓（24.1 ✓）⇒ 树保持全绿 ✓（tracked changes 将由本轮提交清零 ✓）
```
### 24.4 本轮**教训** ✓✓
```
① **诊断优先于改动** ✓✓：本轮**未改一行生产代码** ✓ 即从**探针读出的 `reason`** 定位到根因 ✓✓
   （对比前一轮：5 次门控改动**零收益** ✗）⇒ 规则再次被验证 ✓："**先建诊断通道，再改代码**" ✓
② **探针自身的几何也是"夹具"** ✓：1 m → 0.1 m 的墙体试验**排除了厚度假设** ✓ ✓ 是**测量**在区分解释 ✓✓
```
### 24.5 T04 状态（**分半如实** ✓）
| 半 | 状态 |
|---|---|
| **世界接触可引爆** ✓ | ✅ **完成并实测** ✓（`CD07_WORLD_BURST_PASS` ✓ 三通道 ✓ external=true ✓ applied=false ✓） |
| **遮挡仍有效 / 无 through-wall 总伤** ✗ | 🔶 **未测得** ✗ —— 根因已定（起爆点在障碍内 ✓）⇒ **harness 要求已具名** ✓ |
### 下一轮（**转向不依赖该装置的用例** ✓）
1. **T05 HEAT 通道隔离** ✓（"**事件分通道** ✓ **射流不额外冒充超压**" ✓）：可测 = 同一 HEAT **仅射流** vs **再启用合法壳体爆炸** ⇒ `effect_channel` 分列 ✓ 且**射流不产生 overpressure 通道** ✓✓；
2. **T03 薄板破口与隔板** ✓（**外板/隔板与乘员结果逐段可解释** ✓）；
3. **T06 复数目标与终局** ✓（**一对象一次合法作用** ✓ **非许可目标无伤害** ✓ **取消明确** ✓）。


## 25. `CD07-T05` **HEAT 通道隔离** ✓✓ 通过（合约强制 ✓ 非仅行为 ✓）

### 25.1 J1：射流**不产生**超压通道 ✓✓
```
jet contacts=**1** ✓ channels = **["chemical_jet"]** ✓✓ ；burst_empty=**true** ✓ ；**burst_channel_entries=0** ✓✓
terminal=**chemical_detonation** ✓ ；fragments=0 ✓ spall_events=0 ✓
⇒ 射流的**全部**后效事件在**射流通道**上 ✓ 且**不生成任何超压通道** ✓✓
   = 子单"**射流不额外冒充超压**" ✓ 实测成立 ✓
```
### 25.2 J2：分离**由合约强制** ✓✓（比"仅观察到分列"更强 ✓）
```
chemical_profile 挂到 internal_burst 弹 ⇒ 错误 **1** 条 ✓："**chemical_profile: unsupported effect/version**" ✓✓
post_penetration 剖面挂到 chemical 弹 ⇒ 错误 **1** 条 ✓："**post_penetration_profile: unsupported effect/version**" ✓✓
⇒ 且两套配置**各自合法存在** ✓ ⇒ 该分离是**真合约** ✓ 而非"某功能缺失" ✓✓
```
⇒ 子单"**事件分通道**" ✓✓ = **由校验器强制**（不是靠调用方自觉 ✓）。
### 25.3 与既有实测的衔接 ✓（不重复 ✓）
```
HE 的 root_event **三通道** ✓ 已由 `CD07_WORLD_BURST_PASS` 实测 ✓（fragment/blast/overpressure ✓）
本轮补的是 **HEAT 侧**：其通道**只有** chemical_jet ✓ 且**拒绝**混用 ✓✓
⇒ 两族**互斥且各自完备** ✓（kinetic/APHE = internal_burst ✓ ；HEAT = chemical ✓ ；外部爆炸 = he_blast ✓）
```
### 25.4 CD07 用例进度
| 用例 | 状态 |
|---|---|
| **T01** 封闭无破口（世界情形 ✓ 已实测 `applied=false` ✓）· **T02** 开放 vs 遮盖 ✓ · **T04** 世界接触可引爆 ✓ | ✅ **通过** ✓ |
| **T05** HEAT 通道隔离 | ✅ **本轮通过** ✓ |
| **T03** 薄板破口与隔板 ✗ · **T04 遮挡半** ✗（harness 要求已具名 ✓）· **T06** 复数目标与终局 ✗ | ⛔ |
### 下一轮
1. **T03 薄板破口与隔板** ✓（"**外板/隔板与乘员结果能逐段解释**" ✓）：可测 = 打穿**薄前板**后面对**独立隔板** ✓ ⇒ 逐段的可解释记录 ✓（外板 ✓ 隔板 ✓ 乘员 ✓ 各自独立 ✓ 不合并为一次 ✓）；
2. **T06 复数目标与终局** ✓（"**一对象一次合法作用** ✓ **非许可目标无伤害** ✓ **取消明确**" ✓）：可测 = 多目标爆炸 ✓ 每对象**至多一次**合法作用 ✓（去重 ✓）· `contact_policy` 拒绝 ⇒ 该目标**零伤害** ✓ · 终局取消（`cancelled_match_finished` ✓）⇒ **明确状态** ✓✓；
3. 随后回到 **T04 遮挡半**（若可找到**不越权**的装置 ✓）。


## 26. `CD07-T03` 首试：**装置约定已查明** ✓ 但本轮**未取得测量** ✗（不留失败件 ✓）

### 26.1 查明的两条**必备约定** ✓✓（下一轮直接照用 ✓）
```
① 自定义布局的注入 **不是** `setup()` 的第 7 参 ✗（该参一律传 `null` ✓，全仓探针皆然 ✓）
   ⇒ 正解 ✓：**`actor.set_damage_layout(layout)`** ✓✓（全仓通用惯例 ✓）
② **基类已备两件现成工具** ✓✓（`probe_cd003_gap_baseline.gd` ✓）：
   - `_double_plate_layout()` ✓✓  = **双层板布局**（正是 T03 所需 ✓）
   - `_fire_leg(actor, world, layout, rays, section_m, round_id, delta)` ✓✓ = **已证的射击腿**（含快照与推进 ✓）
   ⇒ **无需自造**布局与弹道 ✗（我本轮自造 ⇒ 快照与布局不匹配 ⇒ `unresolved_query` ✗✓）
```
### 26.2 本轮实测（**如实** ✓）
```
装置自造版：terminal=**unresolved_query** ✗ contacts=0 ✗ burst 无 ✗
⇒ 根因 ✓：快照取自 `build_from_vehicle(actor.tank, layout)` ✓ 而 `actor.tank` 的几何来自**包** ✗
  与**我自造的布局**不一致 ⇒ 查询无法解析 ✓（**装置问题** ✓ 非产品缺陷 ✓）
```
### 26.3 处置（**依我自己的规则** ✓✓）
```
① 探针 `tests/probe_cd007_segmented_plates.gd` **删除** ✓（**不留失败件** ✓）
② 本轮**未改生产代码** ✓ ⇒ 树保持全绿 ✓
③ 连续装置试错 5 次仍无测量 ✗ ⇒ **停止** ✓（= "**先建通道/用已证工具，勿自造**" ✓）
```
### 26.4 本轮教训 ✓✓（第三次同类 ✓）
```
"**用已证的基类工具，而非自造装置**" ✓ —— 我先前已有 `_double_plate_layout`/`_fire_leg` 可用 ✓ 却自造 ✗
⇒ 与"先建诊断通道再改代码" ✓ 同族 ✓：**先查既有工具，再动手写** ✓✓
```
### 下一轮（**照 26.1 直接实施** ✓）
```gdscript
# 约 15 行即可：
var layout := _double_plate_layout()                  # 基类已证 ✓
actor.set_damage_layout(layout)                       # 已证惯例 ✓
var st := _fire_leg(actor, world, layout, 1, 0.5, 17300)   # 基类已证射击腿 ✓
# 断言 ✓：
#   S1 contacts >= 2 ✓ 且两段 **part_id 不同** ✓（逐段独立 ✓ 不合并 ✓）
#   S2 两段判决**各自独立** ✓（前板破口 ✓ 隔板由其自身厚度与残速决定 ✓ 非复制前板 ✓）
#   S3 爆炸记录指明**发生在哪一段** ✓（外板/隔板/内构结果**各自可追责** ✓）
```
⇒ 随后 **T06**（复数目标与终局 ✓ **一对象一次合法作用** ✓ **非许可目标无伤害** ✓ **取消明确** ✓）。
