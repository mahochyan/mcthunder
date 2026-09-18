
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
