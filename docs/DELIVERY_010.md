# 010：不可变实弹记录与只读回放
implementation=implemented；engineering=passed_self_review；human=not_run；content_history=test_only。
源码73c24ea122e409d3490b432b7e1ac5fcb4c5fe52；基线009登记d85f3c04989ab8d43461c5d191527729e68d5c1a；分支work/010-shot-replay。

正常射击后右下角播放约3秒实际弹丸路径。V关闭/重看，逗号/句号浏览最近16炮，N选择真实接触，J导出当前炮JSON。暂停菜单可关闭自动播放。装甲/模块面板在回放期间让出右侧空间，切换控制恢复操作信息。

ShotRecord保存schema/rules版本、发射身份/seed、实际推进路径、每次接触前本物理步目标装甲/模块/乘员世界几何及部件姿态、预算、损伤before/after和终止原因。事件引用自己的geometry_frame。所有冻结容器只读；Store和外部消费者得到深副本。目标后来移动、转塔或删除不改旧记录。
ReplayView独立SubViewport/World3D只有Mesh/Camera/Light，无碰撞/车辆/武器。仅高亮实际damage记录中的部件，不重新结算。管理器先终止、冻结再通知；取消清缓冲/代次，终止回调重置后旧记录不进入新局。权限回调必填，当前明确训练场允许；未来正式战斗需另接权限。
JSON只允许基础类型及显式Vec2/Vec3/Transform3D编码，有限数/版本/几何索引/姿态/目标身份/深度/大小校验，禁止对象反序列化。路径512点、帧96、缓冲16、JSON2MB；超限显示回放不可用，真实弹丸继续原有结算。J导出只写本机user://shot_records，错误可见。

固定引擎4.7.2.stable.official.ed1daf0bf：tests/run_suite_checks.ps1 -Order 010，八套892项通过（216/123/140/144/81/57/64/67），全部exit=0，非预期ERROR/SCRIPT ERROR=0。日志logs/010/73c24ea122e409d3490b432b7e1ac5fcb4c5fe52/20260908-155914/含真实命令/版本/exit/完整输出。
真实窗口tests/run_window_checks.ps1 -Order 010 -Script run_replay_player_checks，30项通过、5张1280×720抓帧、60FPS/60Hz、exit=0；正常菜单/鼠标瞄准/四次发射/自然装填/回看/导出/重置，未直接制造命中。日志对应window-20260908-155938，截图docs/evidence/010/73c24ea122e409d3490b432b7e1ac5fcb4c5fe52/window-20260908-155938/。模型目视检查了跳弹及发动机选中画面；真人NOT_RUN。

下一步011中文车库、真实配弹及核心任务闭环。尚非历史M4A3认证，不冒称AI/完整比赛已实现。未合并main、未公开发布。
