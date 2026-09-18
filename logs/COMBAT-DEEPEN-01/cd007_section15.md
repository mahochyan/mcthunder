
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
