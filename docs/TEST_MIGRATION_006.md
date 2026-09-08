# TEST_MIGRATION_006 — 即时命中测试 → 真实飞行迁移记录

状态：006-d 授权范围内执行（WO006 authorized；见 `docs/planning/work_orders/WO006_authorized.md`）。
日期：006-d 实施期间。分支：`work/006-projectile-flight`。

## 背景

006-b/c 将 `Gunner.try_fire()` 从"射线即时命中结算"改为"经 `ProjectileManager.try_spawn`
生成有限速度炮弹，真实飞行（重力 + 分段子步推进 + 每物理步快照查询）"。命中不再在开火
当帧同步发生：300 m/s 下约 5 m/物理帧，A→B（~11 m）约 2–3 帧，A→中靶板（~35 m）约 8–9 帧。

因此 `tests/run_checks.gd` 中所有"发射后立即断言命中"的旧即时命中测试会失败。
本文件记录每一处的旧编号、原行为、旧断言、新断言与迁移原因。

## 迁移总原则（工作单授权口径）

- **等待真实飞行**：发射成功后以物理帧轮询等活动飞弹归零再断言
  （新辅助 `_wait_flight_done(main, timeout_frames=480)`；上限对应
  `ShellDefinition.max_flight_time_s=8.0` = 480 帧）。
- **不清除冷却来跳过装填**（原有语义保持；仅原测试已清冷却处保持不变）。
- **不传送射弹到终点、不调用隐藏即时命中入口**——没有这类入口。
- 命中计数、试射计数、反馈触发的**语义不变**，只改变"何时可观察到"。

## 逐项迁移记录（run_checks.gd，213→214 项）

| # | 旧编号/原行为 | 旧断言（即时命中时代） | 新断言（真实飞行时代） | 迁移原因 |
|---|---|---|---|---|
| 1 | 遮挡段"移除墙后命中靶板" | `try_fire()` 后立即 `board.hit_count == 1`（同帧即时结算） | 拆分为两断言：`开火成功` + `await _wait_flight_done` 后 `hit_count == 1` | 命中在弹到达靶板时发生（~8–9 帧后）；检查总数 213→214（拆分） |
| 2 | 遮挡段"命中后靶板变色反馈" | 开火当帧 `board._flash_left > 0` | 等待飞弹终止后断言（`TargetBoard.FLASH_TIME=0.25s`，飞行 ~0.17s 后仍可见） | 反馈由命中事件触发，命中后仍处于 0.25s 闪烁窗口内 |
| 3 | 遮挡段"遮挡墙后靶板未被命中"→移墙 | 移墙前不等待；被墙拦截的弹不存在（即时结算） | 断言后 `await _wait_flight_done` 再 `wall.queue_free()` | 真实飞行下被拦弹已起飞；若不移墙前等待，移墙后旧弹会继续飞向靶板造成 `hit_count` 双计（曾表现为"穿墙未命中 hits=1"） |
| 4 | 穿墙段"穿墙未命中墙后靶板" | 依赖上段无遗留飞弹 | 无新断言改动；由 #3 的等待消除遗留弹污染 | 同 #3 |
| 5 | R3-A 五处实射（B1/B1二炮/B2/B3/车体非零 yaw） | `try_fire()` 后立即断言 `bN.hit_count` | 每次开火后 `await _wait_flight_done` 再断言 | 命中在弹到达时发生（近靶 ~4 帧、远靶 ~8 帧） |
| 6 | T003-03 "A 命中 B（自身排除生效）" | 开火后立即 `actor_b.tank.hits_taken == +1` | `await _wait_flight_done` 后断言 | A→B ~9.6 m ≈ 2–3 帧飞行 |
| 7 | T003-03 "墙挡不命中 B" | 开火后立即断言 B 未被命中 | `await _wait_flight_done` 后断言（弹撞墙终止） | 同上 |
| 8 | T003-03 "墙挡结果 = miss（世界接触优先）" | `gunner.last_shot_result == "miss"`（即时命中同步写回） | `main._last_impact.reason_upper == "WORLD"`（飞弹终止记录） | 即时命中时代的同步 `last_shot_result="miss"` 写回不再存在；世界接触优先语义改由终止记录的 reason 体现（`main.gd _on_projectile_finished`：`impact_world → WORLD`） |
| 9 | T003-06 四处真实命中推进试射计数 | 每次 `try_fire()` 后立即断言 `trial_hits` 递增 | 每次开火后 `await _wait_flight_done` 再断言 | 试射计数由真实命中（飞弹终止）推进 |
| 10 | T003-09 正常输入链路 / 自然装填第二次命中 | 输入开火后立即断言 `trial_hits` | 输入开火后 `await _wait_flight_done` 再断言 | 同 #9 |

## 未迁移（保持原样）的即时结算语义

- **开火拒绝类断言**（冷却、宽限、炮管遮挡、容量满、无效规范）：仍在 `try_fire()`
  返回值上同步断言——拒绝发生在开火入口，与飞行无关。
- **管理器直发（try_spawn）类断言**：由 ProjectileManager 直接推进/终止，套件内
  已按真实飞行时序编写（006-d 新增 `tests/run_projectile_checks.gd`，81 项）。
- **005-F-A 炮根/炮口在实体墙内**：拒绝路径不变。

## 迁移后基线（tested_code_sha 见交付记录）

- `tests/run_checks.gd`：214 项检查，0 失败（CHECKS_PASS）
- `tests/run_projectile_checks.gd`：81 项检查，0 失败（PROJECTILE_CHECKS_PASS）
- `tests/run_query_checks.gd`：140 项检查，0 失败
- `tests/run_layout_checks.gd`：123 项检查，0 失败