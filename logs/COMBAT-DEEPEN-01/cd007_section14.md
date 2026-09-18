
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
