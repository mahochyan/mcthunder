# 012：坡地驾驶与 M4 外形重建
implementation=implemented；engineering=passed_self_review；human=not_run；content_history=test_only / silhouette_estimated。
分支work/012-terrain-drive；最终候选a853fcdfb23bda47db1a501cbaa413c26e506b48；运行代码1482f1defb73bcabeeba7a40e820ea5ed9d0faf6。两者只差AGENTS要求登记、窗口输入测试与日志读取器，没有游戏逻辑差异。起点011登记3ed3dd9608bfafecaa0448eb9b674bc93dffea5e。

## 实际结果
中文车库下方“专项实验室→地形”，滚动左栏可达。1/2/3对应10°/20°/30°坡，4为低台阶、窄道、墙角区域，西侧有真实下凹地面。W/S前后、A/D转向；Tab接管坡上B；Esc返回车库；R或1—4显式开始新训练，清理旧飞弹和损伤。边界有可见实体围墙。

Tank沿真实WORLD五点探测取法线，以VehiclePose构成正交车体姿态。前缘探测覆盖碰撞体鼻端，避免可爬坡被竖直前缘卡住。可行坡投影速度、自然减速后驻坡；默认28°上限，超限前缘阻止继续上行，允许倒退。CharacterBody仍负责所有碰撞和重力。地面法线不用于伪造装甲/炮口位置，查询直接读同一个Tank/Turret/Barrel世界变换。Turret在完整车体基下求局部瞄准角。

响应用户外形要求，用M4A3(75)W VVSS轮廓研究替换车库/七个核心课目/地形场的旧盒子车。斜车体、分面炮塔、宽炮盾、三组VVSS双轮悬挂、履带板、观察塔、舱盖、格栅、灯罩、牵引点与工具保留。4,176个细节方块合为19组实例；履带按真实速度沿闭环滚动，炮管跟随后坐。车库左右旋转可看侧后，驾驶相机距离按车型调整以容纳完整车长。主要装甲皮肤共用真实查询顶点。装饰小件不作为额外装甲。

外形原型、估算几何、训练装甲性能三者明确区分。正面240mm与其他20mm仍为教学设计，内部尺寸/细节未历史认证；旧专项实验室保持原夹具。本单不能据此宣布正式历史M4完成。后续建模标准已写入MODELING_STANDARD与AGENTS。

## 检查与证据
- 1482f1d运行代码：`tests/run_suite_checks.ps1 -Order 012`，十套972PASS（216/123/140/144/81/57/64/67/55/25），全部exit0，无非预期ERROR/SCRIPT ERROR。完整输出/命令/引擎在`logs/012/1482f1defb73bcabeeba7a40e820ea5ed9d0faf6/20260908-171727/`。此前1f42454同样972通过。
- 25项地形检查含10/20坡升降驻坡、30坡拒绝退离、60秒模拟贴墙前进与转向、两车实际阻挡、下凹碰撞地面、损伤驱动限制、完整倾斜查询变换、真实弹丸击穿坡上车辆后部并打坏发动机、代次重置。数学夹具初始化与正常玩家流程分开，不用传送制造到达。
- a853fcd：`tests/run_window_checks.ps1 -Order 012 -Script run_core_player_checks -TimeoutSeconds 180`，七课87PASS、10张实机图、末尾60FPS。日志/截图同名目录`window-20260908-172110`。
- 同候选：`tests/run_window_checks.ps1 -Order 012 -Script run_drive_player_checks`，19PASS、7张实机图、末尾59FPS，目录`window-20260908-172307`。真实鼠标旋转/滚动车库/点地形；真实W爬坡、松键驻坡、S倒车、3键超限坡、2与Tab坡上接管、Esc暂停/按钮返回。
- 实际目视检查最终前侧/后侧模型与10°坡上截图，车体完整入镜、中文状态可读。真人外形与手感评价NOT_RUN；没有代签。

## 发现并修复
早期皮肤非共面四边形改为实际三角面；换模时按专用组清理旧外观，避免删掉火焰特效；残骸材质收集支持实例网格。WIP失败输出保留`logs/012/wip-uncommitted/`。

长接触说明现使用180px滚动区，结果操作一直可见。两次旧窗口夹具在返回按钮点击后未激活，后续访问空车库导致超时；截图确认修订结果页按钮在屏内，夹具补齐真实鼠标移动/全局坐标、布局等待并记录pressed信号，最终全流程通过。1f42454与1482f1d失败窗口原stdout/stderr保留；旧运行器超时后读重定向文件被锁，未产出RESULTS.json，不能当作通过。日志读取改为共享只读并保留失败状态。

## 本机候选与下一步
`tests/package_candidate.ps1 -Order 012`生成`backups/candidates/012/a853fcdfb23bda47db1a501cbaa413c26e506b48/PixelArmor/START_GAME.bat`；独立导入和默认车库启动exit0。是本机源码+固定引擎候选，不是公开发布或导出游戏exe。工程证据已满足，继续013电脑驾驶/路点与有限脱困；不合并main。
