
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
