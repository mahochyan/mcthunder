# DELIVERY — 003-R2（定向收尾）

- 分支：`work/003-vehicle-foundation`（追加提交，不强推、不合并 main、不退回 002、不开始 004）
- 授权：GPT 003-R2 工作单（003-R1 复审结论：配置驱动/碰撞坐标/射手过滤/自然装填演示**保留**；"四组全部关闭"不签收；授权四项定向关闭）
- 基准：`dfdcd1a`（003-R1 交付 HEAD）
- 人工逐项试玩（U003-01）：**NOT_RUN**，不代签。

## 1. SHA 对照（源码 / 被测版本 / 证据 / 交付）

| 用途 | SHA | 说明 |
|---|---|---|
| 被测实现 v1 | `81c4698` | 四项关闭初版（截图已按此 SHA 归档） |
| 被测实现 v2（最终） | `022c3ae` | 对齐 GPT 指导包参考实现（邮箱合并策略/TrialHitGate/显式暂停清理） |
| 被测证据（截图/日志） | `de1f094` | 两轮截图按被测 SHA 目录归档 + autoshot/回归/abort 日志 |
| 交付 HEAD | 见 `git rev-parse HEAD` | 文档提交 |

提交链：`dfdcd1a`（R1 交付）→ `81c4698` 实现 → `dc1d1a1` 证据 → `08874fb` 文档 →
`7178e2b` uid → `022c3ae` 对齐参考实现 → `de1f094` 证据（SHA 目录）→ 文档（HEAD）。
最终被测版本 = `022c3ae`；205 项回归与 13 张截图均为该版本时点产出。

## 2. 四项关闭（对应 GPT 工作单 §二/§三/§四/§五）

### ① 命令单一物理消费（工作单 §二）
- 新增 `scripts/command_mailbox.gd`：submit 只**复制+暂存**（不移动/不射击）；同一物理步多次提交最后者赢得本步；consume 每物理步恰好一次，无暂存返回零命令（保持"无输入=静止"语义，调用方不区分）。
- `VehicleActor.submit_command(cmd) -> bool`：唯一命令提交入口——暂停/离开树 → 拒绝并清空暂存；实体无效 → 拒绝；`aim_world_point` 非有限（NaN/INF）→ **整条拒绝**（修复 R1 只查油门/转向的缺口）；其余复制暂存。
- `VehicleActor._physics_process`：每车唯一物理执行器——有控制者先经同一提交入口收集本步命令（`controller.poll()` → `submit_command`），随后 consume 恰好一次 → `_apply_command_once`（原 apply_command 执行体改名，驾驶/瞄准算法未重写）。**脚本不再传 delta 决定运动时间**；旧 `apply_command` 已删除（不留双路径）。
- 暂停/重置/解绑清暂存：`NOTIFICATION_PAUSED` 清空（恢复不补执行上一轮待发请求）；`reset_vehicle()` 与 `set_controller()` 同样清空。
- 验证（新增断言，`tests/run_checks.gd`）：
  - **T003-02 每物理步恰好消费一次**：60 帧提交 60 次 → `tank.drive_call_count()` 增量恰为 60（旧实现的"脚本 apply + 无控制器零命令"双路径会多执行）；
  - **提交≠执行**：submit 后同步断言位置未变（下一物理步才消费）；
  - B 移动测试**不再 `set_physics_process(false)`**——生产回调全程开启，脚本命令经提交入口驱动（修复 R1 用测试专用方式绕开冲突的问题）；
  - 暂停时提交被拒（返回 false）且位置不动。
- 调试：`VehicleActor.debug_command_trace`（默认关）在提交/消费/执行三处打印 `entity_id / 物理帧号 / 来源 / throttle / fire`。

### ② 发射时轮次/生命周期身份（工作单 §三）
- `Gunner.try_fire()`：通过全部开火检查（冷却/宽限/炮管遮挡）后**立即** `shot_id += 1` 并冻结发射上下文 `{round_id, shooter_id, shooter_life_id, shot_id, target_id, target_life_id}`——**round_id 取开火那一刻**（`round_provider` 注入，`main.get_round_id()`），不在命中送达时补填。空射/打墙同样消耗编号（修复 R1 只在命中分支递增的问题）。
- 命中分流：`col is TankVehicle` → 补齐目标身份（来自实际碰撞对象的 `entity_id`/`life_id`）→ `register_hit(identity)`；靶板等非车辆 → 只触发自身反馈，不产生任务事件。
- `TankVehicle.register_hit(identity)` / `hit_registered(identity)`：事件携带完整身份；`TankVehicle` 新增 `entity_id`/`life_id`（actor setup 注入）。
- `VehicleActor.life_id`：static 计数器在 setup 生成——**同名车销毁重建后生命周期不同**。
- `main._on_b_hit(identity)`：校验 当前轮次 + 射手=A + 目标=B + **双方 life_id 存续** + 本回合去重（`_round_shots`，`reset_range` 清空；旧事件已由轮次+生命周期拒绝，不再无限保留历史编号）。
- 强反例（真实引擎运行，`tests/run_checks.gd` T003-09）：
  - **旧轮次事件重开后首次送达不计分**：重开前冻结身份（round=旧轮次）→ `_reset_all()`（轮次递增+去重清空）→ 事件此刻才首次送达 → 拒绝。R1 接收器在此场景会错误计分（GPT Python 模型反例）；R2 接收器实测拒绝。
  - **旧生命周期身份事件不计分**：其余字段合法但 `shooter_life_id` 为已销毁实体的旧值 → 拒绝。
  - **同名车重建**：despawn C2 → 重 spawn 同 id → `life_id` 递增不同（实测断言）。
- 诚实说明：新反例与实现同提交落地（未保留"先红后绿"的中间失败日志）；R1 接收器对旧轮次迟到事件错误计分由 GPT 的独立 Python 模型反例证明，R2 用 GDScript 在真实引擎中复现了拒绝路径。

### ③ 启动失败短路（工作单 §四）
- `main._ready()` 三处失败点（默认配置加载失败 / A 装配失败 / B 装配失败）→ `_abort_initialization(reason, errors)` 后 `return`：不再继续使用半初始化组件。
- `_abort_initialization`：`set_process/set_physics_process/set_process_input/set_process_unhandled_input(false)`；清理已建 VehicleActor；显示 `INIT FAILED` 错误画面；headless/autoshot 模式 `get_tree().quit(1)` 非零退出。
- `VehicleDefs.resolve_vehicle()`：装配边界**再次校验三个定义本体 validate()**——手工注册绕过 `load_defaults()` 的定义在此被拦截（引用存在 ≠ 定义有效）。
- 验收（`tests/abort_check.gd`，独立运行）：向 `configs/player_tank_vehicle.tres` 注入坏值（verified 无实质来源）→ **子进程真实启动主场景**（非只调 validate）→ 断言：子进程非零退出 + 输出含 `003-R2 ABORT` 短路记录 + 生产配置恢复后字节一致（自愈备份防中断污染）。实测：`exit=0`，子进程 `exit=1`，`abort_log=true`，`config_restored=true`。日志：`logs/003-R2/abort_check.log`。

### ④ 自然瞄准演示（工作单 §五）
- autoshot 步骤 332 不再调用 `turret.snap_to_aim()`（snap 证明的是"程序预先对齐"）——改为**等待炮塔以有限转速真实追赶意图瞄点并稳定对准**：`TurretRig.aim_error_deg()`（只读，不改炮塔角）> 0.5° 时原地驻留，**有限超时 900 帧**超时记错误推进。
- 实测：`[003-R2] natural aim locked: err=0.05° polls=6`（有限速追赶 6 帧收敛至 0.05°）。
- 阈值未放宽、炮塔角未改、历史截图未重拍（R1 旧图与说明原样保留）；本轮新增任务完成/重开画面见 §3。

## 3. 测试与证据

- 无窗口回归：**205 项检查，0 失败，CHECKS_PASS，exit=0**（003-R1 的 200 项行为要求全部保留；新增 5 项 R2 断言：单次物理消费 / 提交不立即执行 / 暂停拒绝提交 / 同名车重建 life_id / 旧轮次迟到事件拒绝——以实测记录为准，日志 `logs/003-R2/checks.log`）。旧测试行为要求未删；不以维持或增加 200 项为目标。
- 截图自检：`--autoshot` **13/13 张，0 错误，exit=0**，日志 `logs/003-R2/autoshot_1280.log`（两轮被测 SHA 各一套，归档于 `docs/evidence/003-R2/<tested_sha>/1280x720/`）：
  - `autoshot_9_trial_normal_complete.png`：正常输入完整演示（自然瞄准 → Input 开火 ×3 → 自然装填 → TRIAL COMPLETE 3/3；normal trial: trial_hits=3 b_hits=3）——本轮起瞄准为**自然追赶**（无 snap）；
  - `autoshot_10_trial_restarted.png`：真实 R 事件整场重开（TRIAL 0/3）；
  - `autoshot_11/12/13`：演示后两车同框 / 炮镜见 B / HUD；
  - `autoshot_1~8`：002-R1/003 回归画面（R1 版原样保留）。
- 启动失败验收：`logs/003-R2/abort_check.log`（见 §2③）。

## 4. 与 GPT 技术指导包的对照（已对齐）

初版（81c4698）按工作单文字规格实现，GPT 随后通过正文提供了两个参考 .gd 全文与
接入要点；`022c3ae` 已逐项对齐，残余差异仅命名（本地化去掉 Review 前缀）：

| 参考要点 | 本工程落地 |
|---|---|
| `ReviewCommandMailbox` 合并策略（同一步多提交：驾驶最新样本 / fire 逻辑或 / 保留显式瞄点） | `CommandMailbox` 同语义 |
| submit 验证：非有限油门/转向整条拒绝、瞄点非有限拒绝、aim+clear 冲突拒绝 | 同 |
| `set_blocked()` 供暂停状态切换显式调用（不指望已停止回调自清） | 同；`main._pause/_resume` 显式对两车 `pause_block` + 控制者 `reset_pending()`（`NOTIFICATION_PAUSED` 仅作兜底） |
| `ReviewTrialHitGate`：轮次/命中数/去重唯一来源，Main 只读 | 新增 `scripts/trial_hit_gate.gd`（`TrialHitGate`）；`main._on_b_hit` → `gate.accept_hit`；`_round_id/_round_shots` 删除 |
| `begin_round()` 任务开始/整场重开调用（不在单车重置调用） | `_ready` A/B 装配后调用一次；`reset_range()` 调用 |
| 同一车不得玩家+脚本争抢输入；零命令只在消费时产生 | B 无控制器时不额外提交零命令（consume 无暂存才生成） |
| 事件字典传独立副本 | `tank.register_hit` emit 前 `duplicate(true)`；`main` 侧 `gate.accept_hit(identity.duplicate(true))` |
| 演示去 snap + 有限超时 | 已做（§2④） |
| 截图按被测 SHA 目录 `docs/evidence/003-R2/<tested_sha>/1280x720` | `81c4698/` 与 `022c3ae/` 两轮归档 |
| 不要访问正常 HUD 显示 HUD 创建前的错误 | `_abort_initialization` 自建 Label（不依赖 hud） |

说明：本工程 gate 校验在"车辆命中事件真实来自生产射击路径"的前提下使用
（参考实现同此边界）；集成测试的加分路径全部来自真实开火（见 §2②）。

## 5. NOT_RUN / 保留项

- U003-01 人工逐项试玩与人工截图：**NOT_RUN**（待人工验收，不代签）；
- 自动截图 ≠ 人工验收；
- 003-R1 已交付且被 GPT 复审确认保留的部分（配置驱动 / 碰撞与坐标 / 射手过滤与基本去重 / 自然装填演示）本轮未重做、未回退；
- GPT 技术指导包原始参考实现：未获取（见 §4）。

## 6. 约束合规

同分支追加提交、不强推、不合并 main、不退回 002、不开始 004；未接入外部 API/联网；未新增历史车型/装甲/AI/正式菜单；引擎 Godot 4.7.2-stable 未更换；`tools/` 与 `.godot/` 不入库；旧日志归属未改动（R1 时点日志原样）。