
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
