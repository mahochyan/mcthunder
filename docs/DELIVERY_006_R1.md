# DELIVERY 006-R1 — 006 整改：出生/路程边界、生命周期身份与可见近远靶体验

状态：待复核（提交后由 GPT 裁决签收）
基准：44bb5d1a1f0b611a4a24c9705c202cbf2ce9b543（006 交付 HEAD，needs_revision）
分支 work/006-projectile-flight（同分支追加提交，未合并 main，无 force-push）
本单 tested sha：ac8bfb336284da59608782bbdd64583baec6444a（证据目录 docs/evidence/006-R1/<sha>/ 与日志 logs/006-R1/<sha>/ 与之对应）
工作单：docs/planning/work_orders/WO006_R1_authorized.md（006 暂不签收 → 三组整改）

---

## 0. 整改总览与保留边界

按 006-R1 审核意见分三组整改。**未重做**已保留成果：BallisticMath、分段查询服务、
Gunner 接收成功后扣弹装填、物理装填时钟、006 已实现的延迟命中与测试迁移。
先存能暴露问题的反例（新增 35+6 项检查），修复后做变异验证（回退出生门/裁短记账均精确变红）。

四套检查全绿（退出码均 0，脚本错误 0）：
- run_projectile_checks：**122 项** 0 失败（81 + 006-d 迁移扩量 + R1 新增反例/visuals）
- run_checks：**214 项** 0 失败；run_query_checks：**140 项**；run_layout_checks：**123 项**

## 1. A 组：推进边界（006-R1-A）

- **出生 tick 门**：删除"无条件批量晋升 pending"，在唯一推进循环内显式检查
  `now_tick <= born_physics_tick → continue`。新增两种提交时机反例：探针节点
  `process_physics_priority=50`（管理器之前）与 `=200`（之后，同旧演示）各发射一发，
  出生 tick 结束时位置/年龄/路程均不变，下一 tick 恰推进 1 步（5m@60Hz）。
  不通过调整演示优先级绕开检查。变异验证：回退该门 → prio=50 反例变红
  （prio=200 本就不触发，与审核分析一致）。
- **路程裁短统一记账**：`alpha = min(1, remaining/seg_len)`；查询长度、位置、路程、
  时间、速度全部用同一裁短比例（`used_h = h·alpha`；接触用时 `used_h × event.t`；
  无接触且已裁短 → 停在裁短端 `expired_distance`；剩余路程近零不再加完整 h 立即到期；
  端点接触先于到期）。三条反例（GPT 独立复核同款）：
  ① 5m 子段剩 2m 无接触 → 精确停 2m、age=2/300s（修复前 5m/1/60s）；
  ② 裁短段内 0.9m 碰墙 → 用时 0.003333s（修复前 0.008333s）、路程 0.9m（修复前 5m）；
  ③ 墙在路程上限附近的接触不被到期吞掉。
- **active_states()** 只从 `_active` 枚举一次（pending 的 id 已在其中，不再重复返回）。

## 2. B 组：生命周期身份与终止顺序（006-R1-B）

- **完整发射身份去重**：键改为 `JSON.stringify([round_id, shooter_id, shooter_life_id, shot_id])`。
  反例四连：同身份首发接收 → 同生命周期同 shot 重复拒绝 → **同名新车（新 life_id）第 1 发
  可发射** → 新轮次可发射。训练场 `round_id=0` 语义不变（明确允许训练值）。
- **公开入口暂停/清理拒绝**：`Gunner.try_fire()` 与 `ProjectileManager.try_spawn()` 在
  扣弹/占容量/记编号之前检查（树暂停 → 拒绝；管理器 `_exit_tree` 置关闭位 → 拒绝）。
  反例：暂停 + 无冷却 + 有弹 → 两入口均拒、账本不变；恢复 → 新请求可发射。
  不以冷却或无弹替代暂停条件验证。
- **世界接触先提交终止再反馈**：世界分支改为"计算终态 → finish_once（标 terminal、
  移出集合、发记录）→ 再 `collider.register_hit({})`"。反例：世界目标 register_hit 内
  触发整场重置——撞墙发保持 `impact_world` 恰一次终止、另一在飞弹 `cancelled_reset`
  正常取消、不重复计分、世界对象引用只当次使用。
- **Main 目标反馈前校验记录轮次**：`_on_projectile_finished` 在 `target.register_hit`
  之前核对记录 round_id 与 gate 当前轮次——旧轮次记录不得改变目标 `hits_taken`（反例直测）。

## 3. C 组：可见体验与近远靶证据（006-R1-C）

- **ProjectileVisuals**（`scripts/projectiles/projectile_visuals.gd`）：
  `sync_projectiles(states)`（按 projectile_id 创建/更新可见弹体 + 短尾迹——尾迹只用
  已模拟位置，不向目标预画）、`present_terminal(record)`（真实终止位置收尾 + 0.25s
  接触标记）、`clear_all()`（重开/切场景清空）。只读模拟状态：不写回位置、不参与命中
  /计分；headless 检查：在飞对象与模拟状态对应、终止后移除、clear_all 清空。
  接入主场景（`main._process` 同步 + 终止事件收尾 + `reset_range` 清空）与训练场。
- **HUD 按 projectile_id 区分在飞/已终止**：Gunner 暴露 `last_projectile_id`；终止记录
  登记 pid；HUD 终止后显示 `LAST SHOT: #n TERMINATED`，不再出现 PROJECTILES=0 而
  LAST SHOT 永远 IN FLIGHT；整场重开清登记。
- **近/远射道互不遮挡**：同一射击位切换"近靶/远靶"（`_set_lane`，T 键手动 + 演示自动），
  只启用对应靶板与背墙（禁用 = 隐藏 + 退出 WORLD 碰撞层）。修复近靶+近背墙常驻挡住
  远靶直射路线的问题。
- **意图射线修复（生产代码）**：`get_aim_point()` 射线长度 150→300m。根因：相机在炮管
  后方 ~6.5m，150m 射道从相机处已超 150m，意图射线打不到远靶，炮管收敛到 60m 回退
  瞄点（实测 barrel +2.15° 上仰，远靶不可用）。上限覆盖 gun_range 200m + 相机偏移。
  演示机远瞄另加两遍俯仰收敛（轨道相机高度随俯仰变化，一次近似不准）。
- **重开训练闭环**：`_reset_range()` 除取消本车飞弹 + 车辆复位外，同步复位靶板反馈、
  最近结果、HUD 登记与视觉状态（演示断言 hit_count 清零）；返回靶场先清视觉（切场景
  本就不残留飞弹，`cancelled_scene_exit`）。
- **演示机重写**（六时点）：刚发射未命中（背墙 28.369m）/ 近靶飞行中 / 近靶接触后
  （**NearBoard hit_count 恰 +1、FarBoard 不变**——目标身份验证，非仅 WORLD）/
  远靶飞行中（0.4887s，明显长于近靶 0.0887s）/ 远靶接触后（**FarBoard 身份验证**；
  **真实炮口→接触面 146.602m**，按飞弹实际路程记录）/ 重开已清空。
- **实际帧率分离对照**：`--disable-vsync`（引擎官方选项）+ `--max-fps 15/60`，
  实际 **15.0 vs 60.0 fps**（明确分离）；飞行窗口逐帧间隔实时打印（覆盖主要飞行时段）；
  `--fixed-fps` 未使用。双跑物理帧数同为 1133，四条撞击记录逐字节一致
  （接触点差 0 ≤ 0.005m、飞行时间差 0 ≤ 1 物理步）。
- **截图捕获时点**：全部在 `RenderingServer.frame_post_draw`（渲染完成后）捕获，
  并打印捕获时点真实模拟状态（projectile_id/age/位置/在飞数）——低帧率下捕获时点
  可能晚于请求 tick，以打印状态为准。PNG 全部标 NOT_REVIEWED。
- 006-d 旧 30/144 证据保留原归属；其表述改为"两次运行结果一致"（两跑实际帧率相近），
  低/高帧率分离对照由本单 15/60fps 承担。

## 4. 证据与登记

- 无头：`logs/006-R1/<sha>/`（四套 stdout/stderr/退出码；RUN_METADATA.md 含完整
  SHA/引擎/实际命令/物理频率/帧率/无超时声明）。
- 画面：`docs/evidence/006-R1/<sha>/1280x720/{15,60}fps/`（各 6 张 + README 断言链）。
- 006-d 旧证据（docs/evidence/006/370242e4…、logs/006/…）保留原归属，不补造历史失败
  或退出码。
- 完整源码 SHA ac8bfb33…；证据提交与交付 HEAD 见 git log（本单提交序列）。

## 5. NOT_RUN / 保留项

- 12 张演示截图为渲染完成后真实抓帧（71–85KB）+ 断言链全过；**人工目视未做**（并入
  011 前人工验收，不代签）。
- 真人体验验收最迟 011 前（既有保留项）；历史装甲厚度 UNKNOWN；史料原页目视待人工
  转送（既有）。
- 不新增穿透/损伤/AI/素材采购/历史战斗车型；不开始 007；不合并 main。