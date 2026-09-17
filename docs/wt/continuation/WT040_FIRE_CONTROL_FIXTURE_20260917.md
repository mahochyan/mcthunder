# 干净构建中的火控输入夹具时序修复

AI 表面重选的生产修复和原河谷 8/0 结果见 [AI 接续](WT040_AI_SURFACE_RETRY_20260917.md)。本修复只改 `tests/run_fire_control_checks.gd` 的输入投递、观察时序和完整性断言，不修改游戏火控、AI、弹药、地图、测距时限或原验收容差。

## 实际构建失败

99c966745944920535af5ddf201fdeb46631598b 首次内部快照构建：

- 构建目录：`backups/builds/031/99c966745944920535af5ddf201fdeb46631598b/20260917-154228-437/`。
- 日志：`logs/031/99c966745944920535af5ddf201fdeb46631598b/build-20260917-154228-437/`；外层 `logs/WT040-ai-fire/build-99c96674-console.log`。
- 干净导入通过，但默认运行方式下 `run_fire_control_checks` 只有 **45 项、2 失败、exit 1**，并有缺失字典 `direction` 的 SCRIPT ERROR。构建按原门禁停止，**没有导出通过验收的新包**，未添加豁免或删除该套件。
- 新 AI 三场景 35 项、六车内构 HUD 109 项和其它选择的套件均通过，不能掩盖上述构建失败。

## 最早失败环节与修复

原 `drive()` 每送一次命令，等待 physics_frame 再等 process_frame。在一个渲染帧内执行多个物理步时，后续步的邮箱已经空了，生产代码收到中性命令，依法以 `observation_changed` 取消持续测距。此前局部 `--fixed-fps 60` 检查没有暴露这种输入空档。

`fire-control-gap-before.log` 使用同引擎、真实场景和原测距规则，加 `--max-fps 20` 明确构造多物理步/渲染帧调度：记录 tick 284 测距尚余 2 秒时收到中性命令，随后 `status=failed / reason=observation_changed / range=0`；**45 项、8 失败、exit 1**，同样保留 SCRIPT ERROR。这是输入调度夹具，不采集帧率统计，也不修改正式游戏性能配置。

修复将测试命令泵放在 VEHICLES 阶段之前，将完成信号放在 SNAPSHOT 阶段之后，每个物理步通过原 Actor.submit_command 和邮箱送入命令。夹具在步完成后立即断言，不依赖渲染帧一一对应。新增“全部真实射击场景走完”和“测距期间无意外中性输入”两项检查，未放宽任何原有断言。缺失求解结果先明确失败，避免后续直接读 direction 抛错。

中间 `fire-control-gap-after.log` 虽 59/0、exit 0，但发生在信号回调内销毁发信节点的引擎 ERROR，因此该次不算通过；先离开该物理回调再销毁场景后复验，保留原错误日志。

最终 `fire-control-gap-final.log` **59/0、exit 0**，600 米测距正常、neutral_gaps=0，无 SCRIPT ERROR/ERROR。构建默认时序 `fire-control-default-final.log` 同样 **59/0、exit 0**、无 SCRIPT ERROR/ERROR，但退出时有 2 ObjectDB 实例的 WARNING；为核查来源，同默认时序加 verbose 的 `fire-control-default-verbose.log` **59/0、exit 0**，该警告未复现。保留原警告，不根据一次复跑宣称已找到它的根因。

后继包仍需重新构建及实际独立包检查，不能使用被拦住的 99c96674 构建冒充交付。生产游戏代码保持 99c96674 的 AI/HUD 版本；本次后继只修测试夹具与记录。
