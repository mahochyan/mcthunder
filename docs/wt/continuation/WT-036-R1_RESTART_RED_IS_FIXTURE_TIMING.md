# WT-036-R1：`restart frees old world` 既有红 = **夹具时序**，非产品缺陷

## 1. 等价 setup 的秒级探针（`tests/probe_restart_release.gd`）
按套件 `transitions()` 的原样 setup（`AppFlow.new()` 直建 + **车辆选择并 `item_selected.emit(1)`** + `map_choice.select(...)`），三轮迭代结果一致：
```
id=industrial_edge build_match ok=true frozen_map=true
  entered=industrial_edge_023  released=true  new_round=true  map_kept=true
id=hill_village    build_match ok=true frozen_map=true  previous_freed=true
  entered=hill_village_018     released=true  new_round=true  map_kept=true
id=industrial_edge …           released=true  new_round=true  map_kept=true
```
⇒ **三子句全部通过**（旧场景已释放 ✓ / round id 已变 ✓ / 地图保持 ✓）⇒ **产品流程正确** ✓

## 2. 因此套件内的失败属**夹具时序**
- `restart_match()` 的首个守卫是 `if _transitioning or not (training is DuelRange or training is TeamRange): return` ⇒ **转场进行中会静默 no-op**；
- 套件每次动作用固定 **`await frames(8)`** 等待，而转场是**异步**的（`call_deferred("_enter_lab", …)` + 多次 `await process_frame`）⇒ 8 帧可能不足 ⇒ `restart_match()` 被吞掉 ⇒ 旧场景仍在 ⇒ 断言失败 ✓
- **修复（测试侧，语义不变）**：在每个转场动作后**等待 `_transitioning` 清零**（有界 240 帧），替换"固定 8 帧"的赌注 ✓

## 3. 状态
- 该检查**不再视为产品缺陷**；测试侧修复已应用，工业套件**完整复验**（约 24 分钟）在后台进行 ✓
- 结论仅在复验通过（该检查转绿且其余检查不退化）后才最终确认 ✓
