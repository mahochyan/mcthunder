# DELIVERY 028：交互教学与失败提示（工程自审）

候选源码：`5dfbd4b`  
Godot：`4.7.2.stable.official.ed1daf0bf`

现有训练入口提供 7 个真实课目，课目由 `TrainingDirector` 根据实际移动、瞄准、命中、模块损伤、维修和结果状态推进；重试会创建新 round 并清理旧回放/飞行物。训练无限补给只作用于训练玩家，正式战斗仍使用真实弹药账本。

命令：

```text
tools/godot/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tests/run_core_checks.gd
```

结果：`55/55 PASS`，包含错误配装可恢复、训练/正式补给边界、真实课目构建、错误回合与 shooter lifetime 拒绝、暂停/结果/重试生命周期，以及 7 个课目的实际靶场状态。

真人首次用户教学观察、窗口布局和完整键鼠通路仍为 `PENDING`；本记录不宣称 028 真人验收完成。
