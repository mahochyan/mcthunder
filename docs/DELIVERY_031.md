# 031 独立 Windows 候选交付

运行源码：`9998f4483637ad5d0b73ca23060e235b46f908c2`，分支 `codex/mainline-027-continuation`，版本 `1.0.0-rc.1`。固定 Godot `4.7.2.stable.official.ed1daf0bf` 与匹配 Windows x64 Release 模板，Compatibility 渲染。

构建命令为 `tests/build_release.ps1`，2026-09-10 17:23:11 启动，退出 0。从 Git archive 创建干净源码，重新导入全部资源，39 套测试共 **2786** 项断言通过（RESULTS 另含一个零断言 import 行）；导出、默认启动、工程外内容检查 34 项与真实窗口 35 项全部通过。回归中的 layout 负面夹具按精确预期检查错误，旧 query 脚本的退出生命周期警告另行保留，不宣称日志无任何警告。

完整日志：`logs/031/9998f4483637ad5d0b73ca23060e235b46f908c2/build-20260910-172311-739/`。`regression/RESULTS.json` 绑定每套真实命令、源码 SHA、退出码与断言数；`release_battle.png` 是实际独立程序帧，已检查中文 HUD、工业地图和本车显示。原始试安装位于工程外的 `%TEMP%/PixelArmor 独立测试 20260910-172311-739`。

稳定交付目录：`E:/AIprogram/PixelArmor交付/1.0.0-rc.1-9998f448/`。原样复制成功 ZIP，解压到其中 `游戏/`，逐个复算包清单的文件哈希后，使用该目录继续 033/034。双击 `游戏/PixelArmor.exe` 即可，无需开发工程、Godot 编辑器或 Blender。

| 文件 | SHA256 |
|---|---|
| PixelArmor-1.0.0-rc.1-Windows-x64-9998f448.zip | `87A63206E7DC1BF7F3E9DD585BD374B1F3E5F4CEB32A8A7E46B027D65A040DD9` |
| PixelArmor.exe | `8E6C6A7782B22965569CE4CBA6CE7B7E6BD357C33302E2BE420AC22556DC17C9` |
| PixelArmor.pck | `7182D9C9F3B8C4663EF046291BC2987D147234C0E9299BD8D8C6B2620840A875` |
| BUILD_MANIFEST.json | `2863BDE0D3B5E532C01485CBB2B0D3AAE02EAE612AFF3AD8BBB3B23A277A3C34` |

清单含引擎/模板身份、源 SHA、规则与存档 schema、文件长度和哈希、实际回归/安装结果。随包保留完整引擎许可、字体 OFL、开始游戏与数据恢复说明。PCK 排除开发脚本/原始文档/工具；GLB 导入生成图像依赖由干净导入重建并保留，避免导出后贴图缺失。

此前失败候选仍留在 backups 与 logs：e3b3755 的合法失焦暂停暴露安装检查未恢复；859a0d1 为加入完整玩家流程而主动停止。当前检查用普通 Esc 输入与真实倒计时恢复，保留原断言，不修改暂停、冷却和比赛时钟。村庄出生路线绕开邻车停车位的修复在当前全量自然比赛中验证。

031 工程检查通过；真人与其它机器验收 PENDING。最终性能/玩家全流程见 033/034，许可与冻结状态见 035/036。本地交付不等于公开发布。
