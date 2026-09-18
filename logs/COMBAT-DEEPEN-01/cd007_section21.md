
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
