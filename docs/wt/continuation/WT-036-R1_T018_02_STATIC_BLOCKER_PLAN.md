# WT-036-R1：`T018-02` 的三种让行修法对照（含**我上一轮的错误更正**）

## 1. 更正：我上一轮宣称"T018-02 已修复"是**错的**
`T018-02` 的判据为：
```gdscript
check(blocked.phase == "arrived" and recovered, "T018-02 …")
```
其中 `recovered` 要求事件中出现 **`reverse`**。
我在轮 95 只看了 `[real parked vehicle blockage]` 的 `phase=arrived` 就下结论 ⇒ **漏看了 `recovered` 子句** ✗。
本轮实测（当前 HEAD，含轮 95 的"仅重规划"让行修法）：**`T018-02` 两轮均失败** ✗ ✓（与判据一致）。

## 2. 三种修法对照（全部实跑）
| 变体 | `T018-02`（需 arrived **且** reverse） | 村庄（七单位离出生点） | 结论 |
|---|---|---|---|
| **0. 无让行修法**（仅我 WT-039-R1 的油门门限） | ✗ 永久 `yielding`（用满 250 s） | 21/0 ✓ | 基线为绿 ⇒ **回归** |
| **1. 仅重规划**（轮 95 已提交 `bcbfb49c`） | ✗ `arrived` 但**无 reverse** | **21/0 ✓** | 到达✅ 判据❌ |
| **2. 恢复（2.5 s 超时）** | **✓ 两轮均通过**（地图最好一轮 **47/2**） | **20/1 ✗** | 扰动村庄 ⇒ 被门禁拒绝 |
| **3. 静止阻挡物才计时**（下一版） | 待测（预期 ✓） | 待测（预期 21/0 ✓） | **首选** |

## 3. 下一版实现（结构性区分，已设计）
```gdscript
if phase == "yielding":
    var blocker: Object = obstacle.get("collider") if obstacle is Dictionary else null
    var blocker_still := true
    if blocker != null and blocker.has_method("get_real_velocity"):
        var blocker_velocity: Vector3 = blocker.get_real_velocity()
        blocker_still = blocker_velocity.length() < 0.3        # 移动=交通流；静止=死锁
    yield_elapsed = (yield_elapsed + delta) if blocker_still else 0.0
    if yield_elapsed >= GameConfig.AI_YIELD_TIMEOUT_S:
        … 与卡死恢复同路径：attempts+1 / 标记阻塞边 / _phase_left=AI_REVERSE_SECONDS / _transition("reverse",…) …
```
- **依据**：村庄的阻挡物是**行驶中的 AI 对手**（>0.3 m/s ⇒ 不累计 ⇒ 不恢复 ⇒ 不扰动 ✓）；停放车是**静止刚体**（累计 ⇒ 恢复 ⇒ `reverse` ✓ 判据满足 ✓）；
- `_obstacle()` 返回射线命中字典，含 `collider` ✓（已读源码确认）；
- 常量沿用 `AI_YIELD_TIMEOUT_S = 2.5`。

## 4. 状态
- 变体 0/1 的差异已由提交 `bcbfb49c` 固定（**仍留一处回归**：`T018-02` 判据未满足）；
- 变体 2 已**回退**；变体 3 的编辑因"文件已回退到变体 1 文本"而**未应用**（编辑工具报 old_string 不匹配）⇒ 下一轮以**变体 1 的原文**为基准重做；
- 铺装 supply 边（`83805e64`）**门禁中立**（地图 46/3、村庄 21/0、历史 33/0、T039-E 3/3）✓
