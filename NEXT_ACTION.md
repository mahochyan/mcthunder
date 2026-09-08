# 接续开发
用户已授权按docs/handoff/DEVELOPMENT_007_036.md连续完成007—036，目标体素/低模方块风、尽可能还原战争雷霆陆战内容；工程通过后不逐单等待签收。
开发工作区E:/AIprogram/mcthunder-development；原E:/AIprogram/mcthunder保持旧main及用户文件。
007、008、009已实现并通过工程自查，真人均not_run，历史数据test_only。009源码ad8fdf13713e23871b8973f038200fdcfff271e3，七套825项和窗口34项均通过；详见docs/DELIVERY_009.md。
下一步从009登记HEAD建立work/010-shot-replay，实现不可变ShotRecord、有限缓冲、明确序列化、命中时几何快照及独立只读SubViewport回放，继续后续依赖阶段。
固定引擎4.7.2.stable.official.ed1daf0bf。tests/run_suite_checks.ps1和run_window_checks.ps1保存真实命令/exit/错误分类。
不强推、不默认合并main、不付费或公开发行；不冒充真人验收。
