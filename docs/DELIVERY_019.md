# 019：完整团队战与 Windows 候选

工程自审通过；完整比赛批测、独立候选与最终独占性能采样已完成。真人三场试玩仍未进行，不作真人签收。
分支work/019-team-slice；运行代码c0f1e4fa725364f21ca71de614b3a67b37a4f3ac；最终窗口与导出源码d2afacfe7c360efdd4b8abd13173b9f9ac1f72e2。两者游戏运行文件完全相同，后者只修改tests/run_team_slice_demo.gd的窗口等待与正常暂停恢复。固定Godot4.7.2.stable.official.ed1daf0bf，版本0.2.0，Compatibility。真人三场试玩NOT_RUN。

MatchScenarioRunner在实际VillageRange中配置八个AI和固定种子；普通车库仍为一个玩家和七个AI。使用真实命令、炮弹、伤害、占点、阵亡与8秒重生规则，不能直接指定胜负或缩短比赛。TelemetrySnapshot只读对象与性能指标；小地图静态道路只在地图赋值时准备，标记更新与窗口大小改变复用道路数据。

`tests/run_suite_checks.ps1 -Order 019 -TimeoutSeconds 300`：18套1,236项PASS，全部exit0，无未解释ERROR/SCRIPT ERROR。完整命令、逐套输出在logs/019/c0f1e4fa725364f21ca71de614b3a67b37a4f3ac/20260908-220258。新增8项检查覆盖八AI控制器/观察相机、只读统计、动态标记和缩放不重建道路、切换地图清理、重新开普通比赛恢复唯一玩家、帧间隔统计及节点清理。

独立导出：`tests/build_team_candidate.ps1`，logs/019/d2afacfe7c360efdd4b8abd13173b9f9ac1f72e2/export-20260908-221404。官方模板导出、默认启动与10项资源/输入检查均exit0。模板从官方4.7.2发布资产取得，与发布SHA256一致；只安装匹配的Windows x86_64模板，安装清单见logs/019/template_install.json。模板不是把编辑器改名。候选目录没有project.godot，用真正导出的exe+pck加载车库、字体、地图、弹种、导航、8车，驾驶/重开/返回及user://读写均实际通过。

本机候选入口：backups/builds/019/d2afacfe7c360efdd4b8abd13173b9f9ac1f72e2/20260908-221404/PixelArmor.exe。同目录PCK必须保留。exe SHA256=9F5673E0A94D761F0367A6A66D4E4318E598F519B40E85323B26F8853276EEE5；PCK SHA256=49A05D25717D8DDE9F229AE0A7F0F3D46D529767C2561BFFAD207B344BE05BAB。引擎/第三方库许可证、字体OFL和运行说明随候选保存。未公开发行，二进制不进Git。

最终正常玩家流程：`tests/run_team_player_checks.ps1 -Executable <上述exe>`，logs/019/d2afacfe7c360efdd4b8abd13173b9f9ac1f72e2/player-20260908-221503，16项PASS，10张真实图形帧，exit0。对应docs/evidence目录保存PNG和SESSION.json。车库鼠标进入→真实W/A/D绕侧上坡→公开可见敌情辅助鼠标瞄准→真实射击/维修→普通弃车及随后实际敌方造成阵亡→8秒等待后鼠标再出击→自然胜利→再来一局→返回车库。313.0667模拟秒，56:0票，玩家65次发射，4次阵亡中1次为65秒时普通菜单弃车，不能把这次记为敌方击毁。截图已目视，结算、维修和下一局按钮可读。自动输入不代替真人体验。

第一次固定版本窗口尝试在120.2模拟秒后无后续输出，未出现脚本错误，目标也没有可供桌面工具操作的窗口句柄；主动终止，真实exit=-1、passed=false保留在c0f1e4f/player-20260908-220435。仅凭日志无法确认是隐藏窗口停止绘制还是失焦暂停。随后脚本改为按process_frame驱动输入，暂停时点击正常“继续”按钮；游戏原有失焦暂停规则不变，截图仍取实际渲染帧。最终运行未触发自动恢复，完整通过。

十局批测：`tests/run_match_batch_checks.ps1 -Runs 10`，logs/019/c0f1e4fa725364f21ca71de614b3a67b37a4f3ac/batch-20260908-220404，50项PASS、exit0。种子19001起每次增加137，10局均按票数自然结束，双方各胜5局；183.43—287.87模拟秒，122—221发/局。每个席位都曾进入目标接近区域，阵亡账本唯一，所有接受的炮弹都有唯一终止记录。最大18个车辆实体（含残骸）、11残骸、3在飞弹、16条回放；最大静态内存123,137,217字节。清理后每场节点1、孤立节点0、资源90，对象1695后保持1696；静态内存从79.01MB到80.57MB，末几场有升有降，不能据此宣称绝无内存泄漏。

局部驾驶问题如实登记：累计69次recovery_limit、6次unreachable_or_insufficient_width，逐生命位置、AI/驾驶阶段与失败计数在seed_*.json。它们未导致整队卡出生或比赛无法完成，但不能把批测通过说成没有局部卡路；列P2，后续车型通行矩阵及032/033继续复测。

最终独占窗口：`tests/run_frame_profile.ps1`，logs/019/d2afacfe7c360efdd4b8abd13173b9f9ac1f72e2/profile-20260908-230351，exit0、两项PASS，截图已目视。i5-13400 / RTX4070 SUPER / 1280×720 / Compatibility / 限帧60，八AI，预热15秒再采样30秒，共1610帧：平均18.642ms（53.642FPS）、P50 16.503ms、P95 41.904ms、P99 69.222ms、最长80.609ms。静态内存采样最大115,756,541字节；Godot物理计时采样均值38.75ms，需进一步分解热点。早期独占基线约54FPS，道路缓存没有证明整体帧率显著改善；长帧列P2，033继续优化，不能宣称稳定60FPS或最低硬件配置。

回退点为018登记88aa5af6585b4dc570d856ff90d4794a090c7ebb，原main未改。按连续开发授权进入020，真人与历史内容审核状态仍单列。
