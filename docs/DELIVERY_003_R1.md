# 003-R1 交付报告：多车辆基础修订（003 needs_revision 闭环）

分支：`work/003-vehicle-foundation`（同分支顺序子提交，未动 main、未 force push、未回退 002、未开始 004）
基：`4fe8797`（003-RC001）。授权依据：GPT 003-R1 工作单（RC-001 变更 + 四组关闭项）。

## 1. SHA 对照（源码 / 测试 / 证据 / 交付）

| 组 | 子提交 | 被测源码=提交内容 | 时点日志 | 检查数 |
|---|---|---|---|---|
| A 配置驱动真实表现 | `6186d12` | 6186d12 | `logs/003-R1/checks_A.log` | 178/178 exit=0 |
| B 统一命令与生命周期 | `d2082ef` | d2082ef | `logs/003-R1/checks_B.log` | 181/181 exit=0 |
| C 多车碰撞与坐标 | `4144be4` | 4144be4 | `logs/003-R1/checks_C.log` | 191/191 exit=0 |
| D 真实任务闭环 | `0c8e6f7` | 0c8e6f7 | `logs/003-R1/checks_D.log` | **200/200 exit=0** |

- 最终回归在被测源码 0c8e6f7 内容上运行（工作区=提交内容，无后续源码改动）。
- 截图证据（13 张）与 autoshot 日志随 D 提交 → **证据提交 = 0c8e6f7**。
- **交付 HEAD = 本文档提交**（推送后 `git rev-parse HEAD` 为准；源码终态 = 0c8e6f7）。
- 旧 `logs/003/`（155/163 项）保留原归属不重写；`docs/evidence/003/autoshot_8`
  的快搭性质说明移入 003-R1 截图 NOTE（见 §5）。

## 2. 四组关闭项 ↔ 实现 ↔ 测试

### A 配置真的改变车辆（6186d12）
- VehicleActor 生成时注入 VehicleDefinition/WeaponDefinition 到 tank/turret/gunner；
  驾驶速度/加速度/转向、炮塔转速/俯仰限位、装填时间/射程全部读配置
  （GameConfig 常量仅作缺省后备）。T003-07：两套不同配置（4m/s/20°/s/3s/100m vs
  12m/s/60°/s/1s/300m）同测试 spawning，实测驱动/炮塔/装填/射程均不同。
- 共享配置不被运行时动作污染：A 真实行驶后 B 与共享 Resource 数值不变，
  每实体运行时状态以组件为唯一权威源、HUD/查询值与组件一致（T003-01）。
- 校验硬关闭：production 必须 verified；verified 必须有实质 source_refs
  （空串/TEST ONLY 拒绝，T003-05）。测试车显式 `content_tier="test"` +
  `source_refs=["TEST ONLY: development fixture, no historical basis"]` +
  `verification="unknown"`。历史数据核验自 004 起，本轮不做。

### B 两类控制真的走同一路径（d2082ef）
- PlayerController 不再直呼 Gunner：只生成 VehicleCommand（fire 边沿经
  `Input.is_action_just_pressed` → fire_requested），由 VehicleActor.apply_command
  每物理帧统一消费；脚本命令与玩家输入过同一合法性检查
  （暂停拒绝/实体有效/NaN→0/油门转向钳 [-1,1]，T003-02）。
- 短点按仍一发、暂停不补射、恢复后旧请求不复放（002 回归保留）。
- reset_vehicle 清旧瞄点/待发命令/炮镜请求/瞬态；set_controller 统一绑定解绑；
  未控制车辆不抢玩家相机（T003-02/04）。

### C 车体不会互穿（4144be4）
- tank.collision_mask = WORLD|VEHICLE：A 行驶撞 B 稳定阻挡、不互穿、不推移
  （T003-08；CharacterBody3D 互不推移为引擎语义，符合"不穿"要求）。
- 非原点 + 非零 Y 旋转出生：apply_drive 前向改 `-global_transform.basis.z`，
  实测沿车头行驶、重置回正确世界出生变换（T003-08）。
- 曳光示踪线 `_tracer.top_level = true`：顶点即世界坐标——起点=真实炮口、
  终点=命中点，无双重父变换，不随车辆运动拖动（T003-08）。
  自身排除/A 命中 B/炮管遮挡/炮镜见 B 回归保留（T003-03/06）。

### D 任务确实由正确射手通过正常操作完成（0c8e6f7）
- 命中事件携带 shooter_id + shot_id（每发递增）；main 记录 射击编号→轮次
  （`_shot_rounds`），整场重开 `_round_id` 递增且不清历史：
  T003-09 证明 C 射击 B 可命中但不计分、同一发重复投递不重复计分、
  重开后旧编号投递无效。
- 正常输入链路（T003-09 + autoshot 演示）：Input 开火 → PlayerController 边沿 →
  apply_command → 真实命中 → 自然装填（不清零冷却）→ 计数推进；
  真实 R 事件整场重开归零。
- HUD 车辆标识来自实际状态：`entity_id + (PLAYER|TEST TARGET)` +
  content_tier=test 时追加 `[TEST ONLY]`（非共享配置实例造假）。

## 3. 测试汇总

- 200 项全过（001 52 项 + 002 新增 + 003 T003-01~09；旧测试入口未删行为要求，
  部分等待方式随帧序修正调整，见 logs/003-R1/checks_A~D.log 演进）。
- 头less 命令：`godot --headless --path <工程根> -s res://tests/run_checks.gd`。

## 4. 可见体验增量

- 车辆标识：A (PLAYER) / B (TEST TARGET)，来自实际控制者与实体状态。
- HUD：控制车 / 实际装填剩余 / 最近射击结果 / 试射目标 0/3→3/3 COMPLETE / R 重开。
- 全部 13 张自动截图：`docs/evidence/003-R1/`（1280×720，真实窗口抓帧）。

## 5. 截图证据（自动截图，非人工试玩）

| 文件 | 内容 |
|---|---|
| autoshot_1~5 | 003 原有：第三人称/炮镜/位移/暂停/恢复（回归） |
| autoshot_6/7 | 两车同框（B 在屏内）/ 炮镜见 B（cull_mask=1048573 保留 B） |
| autoshot_8 | **构造状态演示**（清零冷却+直接 try_fire）——证明真实命中函数推进 HUD，仅此而已 |
| autoshot_9 | **正常输入完整演示 3/3**：自然瞄准→Input 开火×3→自然装填→TRIAL COMPLETE（shot1 后 cooldown=1.97s 自然装填中，日志为证） |
| autoshot_10 | 真实 R 事件重开后 TRIAL 0/3（round=6，轮次递增） |
| autoshot_11/12/13 | 演示后：两车同框 / 炮镜见 B / HUD（CONTROL: A (PLAYER) [TEST ONLY]） |

autoshot 完整输出：`logs/003-R1/autoshot_1280.log`（13 张 0 错误，exit=0；
必需截图缺失/失败时退出码非 0 的自检生效）。

## 6. 保留项 / 未验证（不冒充）

- **人工逐项试玩与人工截图 NOT_RUN**（U003-01：同靶场两车、仅玩家车随键盘移动、
  靶板与对方车可见）——待 GPT/用户人工验收，本报告不代签。
- 自动截图与像素统计不等于人工验收；炮口火花/音效等感受项未实现（003 边界）。
- 快搭截图（原 autoshot_8 构造状态）已注明，正常输入演示见 autoshot_9。

## 7. 禁令遵守

未 merge main、未 force push、未回退 002、未开始 004、未接外部 API/联网、
未更换引擎栈、tools/ 与 .godot/ 未入库、数值为设计初值非真实车辆性能。