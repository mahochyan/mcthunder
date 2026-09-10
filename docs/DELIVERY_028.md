# 028 教学交付

实现提交 `612170e03cfc5ba943fa44bc25888502ea33aad5`，分支 `codex/mainline-027-continuation`。Godot 4.7.2 Compatibility，版本 0.3.1。十章具体规则与接口见 `IMPLEMENTATION_028.md`。

教学 49、核心 55、车库 151、改绑 16、应用流程 127，共 398 项通过，实际日志 `logs/028/d91024e2388b322ecd13dd874b2e4455cee6328d/`。该目录记录的是提交前 WIP 基线，功能代码随后提交为 612170e，不能冒充对最终提交重新执行的证据。

最终真实窗口运行 `logs/030/tutorial-window-final.log`：12/12，退出 0。`tests/run_tutorial_window.gd` 使用正常键鼠驾驶和炮镜完成前两章，截图 `docs/evidence/028/window-720`；驾驶提示截图已目视，当前目标、按键、停车与继续条件清晰。其余章节的实际炮弹/恢复/占点/再出击管线由 49 项教学检查覆盖。

入口 `E:/AIprogram/mcthunder-mainline/START_GAME.bat`，在车库上方选择继续初训或复习章节。章节进度使用 schema 3 双槽存档，旧 schema 1/2 保留并迁移。回退提交为 612170e；使用更早程序前备份用户档案，因为旧程序不认识新增字段。

工程检查通过；陌生玩家独立完成教学仍为 PENDING，不代签用户。继续 029 保存恢复和后续独立包，不提前进入后坐/悬挂美化。
