# WT-036-R1：`restart frees old world` 既有红的细化（假设已否证一半）

## 1. 事实
该检查（工业套件 `transitions()` 末段）在**四份日志一致失败**，含**未改动基线**：
```
[FAIL] restart frees old world and preserves selected map industrial_edge
```
断言原文（三子句）：
```gdscript
check(previous.get_ref()==null and app.training.get_round_id()!=old_id
      and app.training.definition.id==MapRegistry.definition(id).id, "restart frees …")
```
⇒ 失败可能来自 **①旧场景未释放** · ②round id 未变 · **③地图未保持** 三者之一 ✓

## 2. 用秒级定向探针（`tests/probe_restart_release.gd`）取得的结果
```
[restart-probe] entered map=hill_village_018 actors=8 transitioning=false
[restart-probe] after 2 frames: old_released=true new_round=true map_kept=false
[restart-probe] VERDICT old_released=true
```
- **① 旧场景确实被释放**（`old_released=true`）⇒ **"重启泄漏旧世界"的读法被否证** ✓
- ② 新 round id 已变 ✓
- ③ `map_kept=false` **暂不可作证据**：本探针的 setup 未到位（`build_match ok=false`，因此进入默认 `hill_village_018` 而非 `industrial_edge` ✗）；套件用的是 `map_choice.select(MapRegistry.IDS.find(id))` ✓，我照改后仍未构建成功 ⇒ **还需套件 setup 的前置步骤**（车库阵容/准备状态）✓

## 3. 结论与下一步
- **剩余可疑子句**：**③ 地图是否跨重启保持**（子句 ① 已否证）✓
- 下一步：把探针的 setup 补齐（照抄套件 `_run()` 开头的准备步骤）→ 再测；若 ③ 仍为假 ⇒
  **产品缺陷为"重启后未保持已选地图"**，届时按产品修复流程处理（含四门回归）；
- 在此之前**不声称**任何修复 ✓

## 4. 状态
`tests/probe_restart_release.gd` 已入库（秒级、可复现）；该既有红仍**登记**为未结项 ✓
