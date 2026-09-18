
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
