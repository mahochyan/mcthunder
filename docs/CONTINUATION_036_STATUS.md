# 007—036 连续开发接续状态

日期：2026-09-10  
候选分支：`work/stab-dev`  
源码基线：`73893f4`

## 已实测

- Godot `4.7.2.stable.official.ed1daf0bf` 可启动。
- `tests/run_ai_recovery_checks.gd`：15/15 PASS。
  覆盖无弹且不可驾驶时维修请求不被撤退命令吞掉、自然恢复后继续任务、起火灭火、缺员替补及路径重规划。
- `tests/run_traffic_telemetry_checks.gd`：场景启动、逐车逐生命遥测记录、合法 hold 状态三项 PASS。
  完整场景仍是长时间采样，未完成的运行不计为整局 PASS。

## 当前结论

F01（无弹失能 AI 丢维修命令）已由 `f7a4ca3` 修复，并由 `ce6d424` 的真实 Actor 回归收口。`73893f4` 只修复了归因 harness teardown 顺序；没有改变战斗参数。

交通问题仍按条件观测记录，不能宣称绝对消除。工业图、村落图的完整 `--full` 采样需要独占 CPU；目前没有新的完整局证据。

027—036 的真人验收字段仍为 `not_run`。中文字体来源、完整首次用户流程、损坏存档替换失败、完整激战帧时间分布和音效辨识度均不能由 headless 检查代替。

## 下一执行点

1. 在独占 CPU 环境续跑 `run_traffic_telemetry_checks.gd`、industrial/map full sampling，并保留原始 stdout、退出码和源码 SHA。
2. 以当前稳定候选开展 027 输入/本地化与 028 教学的实际 UI 回归；没有合法可再分发中文字库时保持明确阻塞。
3. 继而处理 029 存档异常恢复和 030 主菜单闭环；每项保留独立小提交与 `DELIVERY_0xx.md`。

未完成内容保持 `not_run`，不以计划条目数量替代实现或真人验收。
