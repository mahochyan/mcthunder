# DELIVERY 005-R1 — 统一命中查询与多层交点排序（修订循环 R1）

状态：needs_revision → 已整改待复核
分支：work/005-shot-query（追加提交，未合并 main；基准 ddd92b822a1d0a7e69f3202e6abc0f36a8a0f7d 未重写）
本单 tested sha：`5671401`（源码提交；证据目录 docs/evidence/005-R1/5671401/ 与之对应）

---

## 0. 反例先行（按评审意见先复现后修复）

- **组 A（查询几何 ≠ 显示模型）**：旧 fixture `test_query_vehicle` 车体装甲 z 0..3（相对车体 +1.5m 前移），
  与显示网格（z −1.7..1.7）错位；`tests/diag_r1.gd` 探针证明旧 T003-03 发射线按**对齐后真实几何**
  命中 hull_rear 6.24m——即旧夹具的"命中"建立在错误几何上。
- **组 B（内部模块候选被当成车辆命中）**：查询事件里 module/crew 与装甲面同列，旧开火路径把
  "任意第一个候选"当作命中（模块-only 接触也被判车辆命中）。
- **组 C（开火/准星/调试面板三条判定路径不收敛）**：Gunner 开火（真实射线）、准星（另一段代码）、
  面板（独立复算 + 假墙 enter/exit 事件）各算各的。

## 1. 组 A：查询几何与显示模型对齐（不重校准历史测试目标）

- **新对齐布局 `configs/layouts/test_player_vehicle_layout.tres`**：hull 六面与世界坐标轴对齐且与显示盒
  完全一致（front z=−1.7 法线 −Z / rear z=1.7 +Z / left x=−1.15 −X / right x=1.15 +X / top y=1.35 +Y /
  bottom y=0.55 −Y；tri (0,1,2),(0,2,3)）；turret 六面（front z=−0.75 −Z … bottom y=0 −Y）；
  parts：hull fixed / turret yaw bind (0,1.35,0) / barrel pitch bind (0,0.15,−0.75)；
  模块：engine (hull) local (0,0.95,0.3) size (1.2,0.5,1.2)、barrel_box (barrel) local (0,0,−1.2) size (0.22,0.22,2.4)。
- **`configs/player_tank_vehicle.tres` 切到对齐布局**；旧 fixture `test_query_vehicle` 仅用于离线几何单测，
  其 hull_front/hull_rear/turret_front 法线修正为朝外（front 从 +Z 改 −Z），并新增独立法线校验
  （外法线 · (面中心 − 盒内部点) > 0，`_normals_point_outward`）。
- **T003-03/06/09 目标全部不动**：经验证明旧发射线在真实（对齐）几何上依然命中（T003-03 命中
  对齐 hull_rear ~6.24m），校准动作不需要。
- **通过条件实测**：demo run1 首事件 = B hull_rear ~6.49/6.66m（两分辨率，真实自然收敛炮管）；
  run_query_checks 手算案例（5/6/7/8m 基准、yaw90 姿态、端点、接缝、共面）全部按新法线重算通过。

## 2. 组 B：模块/乘员候选不冒充车辆命中；世界遮挡与保守未决

- **`scripts/query/external_contact_selector.gd`（class_name ExternalContactSelector）**：
  - 有效车辆命中 = **第一个装甲面外部接触**（外部向量语义）；module/crew 只作为调试候选，不参与计分；
  - 世界命中 = 最近 LAYER_WORLD 遮挡（墙优先；与装甲同距时 TIE_EPS=1e-5 判墙）；
  - 查询失败 / 不完整 → `unresolved`（保守不计命中，宁可不打不可错杀）。
- **`scripts/query/world_query_adapter.gd` 统一语义**：`{ok, hit, reason, contact}`——
  ok=false（no_space/invalid_input）→ 调用方必须按"空间无效"保守未决；ok=true hit=false → 畅通；
  hit=true → 标准世界接触（kind/event_type/distance_m/point/normal/normal_known/collider/face_index）。
- **查询服务层明确失败语义**：缺部件变换 / 非有限变换 → 整实体跳过 + complete=false（诊断注明，不伪装单位变换）；
  共面未决 → complete=false（"不构成畅通证明"）；>8 实体 → 明确失败（不静默截断）。
- **模块-only 外部接触实测**：探针命中 barrel_box（车体装甲外）→ 选择器 status=miss（不判车辆）；
  不完整查询（缺变换/共面）→ unresolved；墙前于装甲/墙装甲同距 → world。

## 3. 组 C：开火 / 准星 / 调试面板三条路径收敛到同一数据流

- **Gunner 统一**：`_physics_process` 每物理帧跑同一查询（全段几何 + excluded=[自身] + 世界适配器 world_stop 接触），
  缓存进 `_aim_query_cache`；`_update_actual_aim` 经 ExternalContactSelector 取命中点（装甲/世界/60m 兜底）；
  `try_fire` 同流：barrel-root 到 muzzle 的近距离遮挡保留 → 世界适配器（!ok → `unresolved`，仍生成曳光/后坐/冷却/
  shots_fired++，不挂起状态机）→ 全段服务查询 → 选择器：vehicle → register_hit + 命中点=首个装甲面；
  world → register_hit + 命中点=世界接触点；miss/unresolved → 命中点=段末。**开火与准星共用同一命中点语义。**
- **面板提交模型**：run_query = 提交（返回 {}），冻结线段与快照，`_physics_process` 中执行
  （世界适配器 ok=false → 面板结果 ok=false/complete=false + 诊断）；墙体物理体（LAYER_WORLD）经
  WorldQueryAdapter 进入世界接触（不再编造 wall enter/exit 事件）；墙后候选保留并标 occluded_by_world。
- **面板墙生命周期（005-R1-C）**：草稿参数 vs 已应用参数分离；`apply_wall` 校验（非有限/非正尺寸拒绝）；
  自动重跑同线段；墙移除立即 `free()`（避免 queue_free 延迟一帧导致重跑命中旧墙——实测发现并修复）；
  非法更新不破坏已应用墙；独立 Remove Test Wall 按钮。
- **火键释放门**：`close_query_debug` 关闭面板 → `require_fire_release()`——面板期间按住/关闭瞬时的 fire
  不得成为开火边沿（`reset_pending` 不臂门，保持 002"无冷却按下即射"语义——实测回归发现并纠正）。
- **暂停先关面板**：`_pause()` 覆盖焦点丢失/暂停键两条路径——面板开着进暂停 → 先 close（清理物理墙/标记），
  后暂停；恢复后无需重开面板。
- **演示/面板/测试共用同一入口**：真实 F6、真实鼠标点击 Run/Add/Remove/Clear、真实 Esc 全链断言。

## 4. 行为保留（未获新增范围）

- 纯几何核心与服务分层未改；身份排除（实体级）语义未改；弹药/任务计数不被调试查询消耗（demo shots=0 trial=0）。
- run_checks 209 项 0 失败——T003-03 墙挡现走 world 联系语义断言 `result=miss`；T003-03/06/09 发射目标未动；
  autoshot 300 状态 3 次 MISS 设计行为保留（打印-only，无断言）。
- 不新增穿透/伤害/弹道/AI/历史车型；未知装甲厚度保持 UNKNOWN；史料转存与人工验收状态不变。

## 5. 测试与证据

| 套件 | 项数 | 结果 | 日志 |
|---|---|---|---|
| run_checks.gd（001/002/003 回归 + R1-B 墙挡 miss + 火键门回归） | 209 | 0 失败 PASS | logs/005-R1/5671401/run_checks.out.txt |
| run_query_checks.gd（005-a..d 全套 + R1 新增：法线朝外/快照副本隔离/缺失与非有限变换/模块旋转/选择器全状态/适配器语义/occluded_by_world/墙生命周期/火键门/暂停先关面板） | 106 | 0 失败 PASS | logs/005-R1/5671401/run_query_checks.out.txt |
| run_layout_checks.gd（004 回归） | 123 | 0 失败 PASS | logs/005-R1/5671401/run_layout_checks.out.txt |

三套件最终运行：0 条 SCRIPT ERROR（err 日志见 logs/005-R1/5671401/*.err.txt）。

- 截图证据（真实窗口 `-- --query-demo --shot-dir docs/evidence/005-R1/5671401/<res>`，全链断言 errors=0、
  shots_saved=6）：
  - `docs/evidence/005-R1/5671401/1280x720/query_debug_{1_panel_open,2_barrel_events,3_test_wall_before_b,4_cleared,5_wall_removed,6_panel_closed}.png`
  - `docs/evidence/005-R1/5671401/1920x1080/` 同名 6 张
  - 像素校验（System.Drawing 采样）：全部尺寸正确（1280x720 / 1920x1080）、mean_luma 109..164、std 22..68——非空白真渲染帧。
- demo 关键输出：run1 events=3 first=6.49/6.66m（B hull_rear）；run2 world=5.09/5.26m 先于 armor=6.58/7.24m；
  ammo/task untouched；Esc 关闭后 commands_enabled=true。

## 6. 验收对照（005-R1 A/B/C）

- [x] A：查询几何与显示模型一致（对齐布局 + 法线朝外校验 + 手算/演示距离全部与显示面一致）。
- [x] B：内部模块候选不再冒充车辆命中（选择器装甲面-only；模块-only → miss；失败/不完整 → unresolved 不命中）。
- [x] C：开火/准星/面板同一查询数据流收敛（同适配器 + 同选择器 + 同命中点语义；面板提交模型 + 墙生命周期 + 火键门 + 暂停先关面板）。
- [x] 保持：纯几何核心、服务分层、身份排除、既有行为（209 项回归全绿；未重校准历史目标）。
- [x] 交付物：DELIVERY_005_R1.md + logs/005-R1/5671401/ + 12 张新截图 + 分支推送（未 merge main）。

## 7. 保留项（不属于本单/待后续）

- 历史装甲厚度目视核验（保持 UNKNOWN）；7 张史料原页转送 ChatGPT；真人体验验收（最迟 011 前）。
- 面板车辆过滤 B 时模块行仍显示（调试候选语义，按设计）。
