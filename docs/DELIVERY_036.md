# 036 本地主线候选冻结与交付

主线007—036已推进到可独立试玩的 **1.0.0-rc.2**。运行源码 `b90511496fe84195ee8421bd3b4c6bfce2768b7a`，工作分支 `codex/mainline-027-continuation`，固定Godot 4.7.2-stable Windows x64 Release/Compatibility。后补文档提交不改变此运行身份。

交付目录：`E:/AIprogram/PixelArmor交付/1.0.0-rc.2-b9051149/`。双击`开始试玩.bat`或`游戏/PixelArmor.exe`；完整ZIP为`PixelArmor-1.0.0-rc.2-Windows-x64-b9051149.zip`，保留EXE与PCK同目录，无需Godot编辑器或Blender。开始游戏、字体/引擎许可和恢复说明已随原始ZIP提供，补充交付记录放在旁边的`交付资料/`。

该版本包含四个历史配置、两图、靶场/装甲内构查看、两类弹种效果、4v4占点、有限出击与补给、三挑战、十章初训、主要中文菜单/设置、车库配弹/轻量研发、本地档案、结算与真实射击回放。99A建模成果不是本包的第五辆车。

同一运行源码的干净全量回归 **2796项**，独立内容 **34项**、窗口 **35项**，最终包玩家流程 **80项**，最终包1876.26秒/20生命周期稳定性 **67项** 均通过。固定姿态1536发与优化前黄金记录完全一致。原始命令、退出码、JSON及截图分别见DELIVERY_031—035，汇总状态见GATE_E和QA_REPORT_RC。

| 冻结对象 | SHA256 |
|---|---|
| ZIP | `04EDB54E8099F24D0948A1D2F7B541D6D2B32401C5ED3935C4CD6A3AFEB55FF0` |
| PixelArmor.exe | `8E6C6A7782B22965569CE4CBA6CE7B7E6BD357C33302E2BE420AC22556DC17C9` |
| PixelArmor.pck | `89E86493219D5624F34A781932C40006D5EC64F8D3FBD93020BA7FF4256A7CC2` |
| BUILD_MANIFEST.json | `C140EB221EEA98A6D112425B5EB7F520CC6F1BC20B8F531703D2A9E08AE2F494` |

RELEASE_FREEZE_RC.json绑定包、源归属、测试证据和验收边界；RULESET_1_0_RC.json锁定15个关键规则/内容文件。交付目录的DELIVERY_MANIFEST.json校验原始ZIP、全部解压文件和补充文档；此清单不修改原始构建清单与ZIP。

保留三类P2：PERF-RC2-01村庄卡顿（全程平均51.86FPS、最大帧2.65秒，未达稳定60FPS）；HUD遮挡和结算字幕重叠；UI-L10N-RC2-01少量乘员角色名仍为英文。本次长测后的16次释放计数完全一致，后段进程内存中位数不单调增长；不由此保证所有硬件和任意时长无问题。

技术记录由Codex自审；**真人接受PENDING、陌生试玩PENDING、跨机器/DPI等NOT_RUN、公开参考图权利PENDING_HOLDER_REVIEW**。未代签1.0正式接受，未合并main、未推送或创建公开Release、未提交商店。候选可以本地试玩，不将其包装成已完成公开发行审查。

备份位于`backups/builds/031/b90511496fe84195ee8421bd3b4c6bfce2768b7a/20260910-181711-688/`：原始ZIP、干净源码和committed-source.zip均保留。RC1及失败构建也保留，RC1本地目录为`E:/AIprogram/PixelArmor交付/1.0.0-rc.1-9998f448/`。回退换用整个旧包，不混搭EXE/PCK；先备份用户档案，旧版本遇未来schema不覆盖，参照DATA_RECOVERY_029.md。

后续按照PATCH_PROTOCOL_RC.md新分支/新版本/复现与回归推进。先定位卡顿并改善HUD与动态角色文本，再处理用户指出的侧射车体后坐、侧倾回弹、阻尼悬挂与火光/烟尘；这些真实车体反馈目前未实现。99A包仍位于`E:/AIprogram/mcthunder/authoring/ztz99a/delivery/ZTZ99A_HIGH_AND_BAKED_LODS.zip`，外形真人验收与玩法集成分别处理。
