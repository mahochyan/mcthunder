
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
