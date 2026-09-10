# DELIVERY 027：输入改绑与基础易用性（工程自审）

候选：`work/stab-dev`  
源码：`e88d131`  
Godot：`4.7.2.stable.official.ed1daf0bf`

当前候选已具备持久化输入绑定服务、冲突与保留键检查、Esc 取消、恢复默认、设置面板和按键提示同步。战斗场景会自初始化绑定服务，直接运行场景时也不会丢失 Tab/回放/观察等动作。

## 实测

命令：

```text
tools/godot/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tests/run_input_binding_checks.gd
```

结果：`16/16 PASS`，覆盖改绑开火键、旧键失效、新键真实发射、冲突拒绝、Esc 取消、恢复默认、设置损坏安全回退和菜单火控交接。

## 未验证

- 中文字库的合法再分发来源与独立导出显示：`PENDING`。
- 1280×720/1920×1080 实际窗口布局、高 DPI 溢出和仅键鼠完整通路：`PENDING`。
- 用户真人验收 U027-01：`PENDING`。

因此本记录只签收已运行的工程输入回归，不把 027 的图形与真人验收标为完成。
