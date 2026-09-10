# 030 接续交付

实现提交：`d91024e2388b322ecd13dd874b2e4455cee6328d`。分支 `codex/mainline-027-continuation`，Godot `4.7.2.stable.official.ed1daf0bf`，Compatibility。版本 0.3.0。

已打通加载/取消/错误返回、比赛退出确认、阵亡退出、结算统计、重复重开和双图循环。具体接口与剩余项见 `IMPLEMENTATION_030.md`。启动 `E:/AIprogram/mcthunder-mainline/START_GAME.bat`，原目录的 `启动主线试玩.bat` 转到此工程。

## 实际验证

- 407 项：挑战 140、团队 67、应用流程 127、HUD 54、输入 16、菜单开火 3，共 **407** 项。原始结果在 `logs/030-wip-r5/fc8a6823bbd5d06932103d890779fb447cf0cda9/20260910-145207/RESULTS.json`；各项退出 0、无意外错误。此批执行于源码提交前，记录中的 SHA 是 WIP 基线；测试功能源码随后提交为 d91024e，测试期间版本展示由 0.2.7 改为 0.3.0，没有改战斗逻辑。
- 另有核心训练 55、车库 151，共 206 项通过：`logs/030-wip-r3/fc8a6823bbd5d06932103d890779fb447cf0cda9/20260910-142909/RESULTS.json`。这一批的旧应用结果提示/挑战驾驶失败已保留，由上面的 r5 复测覆盖。两批相关检查合计 **613** 项，不把失败批中的其它项目重复加总。
- 双图自然比赛 **14/14**：`logs/030/natural-matches.log`，命令 `tools/godot/Godot_v4.7.2-stable_win64_console.exe --headless --path . --fixed-fps 60 -s res://tests/run_app_match_cycle.gd`，退出 0。是开发中版本的自然规则结算检查；此后补了显示去重、模态焦点和测试加载顺序。未伪造玩家驾驶/胜利，使用隔离内存档案。磁盘成绩另由车库和挑战检查。
- 真实渲染 **37/37，各两种尺寸**：`logs/030/window-final-720.log`、`window-final-1080.log`；分别用 `--resolution 1280x720` 与 `--fullscreen --resolution 1920x1080` 跑 `tests/run_localization_window.gd`。截图在 `docs/evidence/030/final-720` 和 `final-1080`。最后的弃局结果为明确的布局夹具。
- d91024e 独立 PCK：`logs/030/d91024e2388b322ecd13dd874b2e4455cee6328d/pack-20260910-145410/RESULTS.json`。四车、两图、音频、中文字体/许可正常，未回退读源码，导出与运行退出 0。SHA256 `2424A9DA3074F965286B76681C5A666BF4CA22D41855C8887C1EC3506F6E99A3`。
- 本地化静态检查：921 条文本、851 个引用键、0 错误；真实窗口无缺失键。

早期线程加载/键盘焦点/提示重复/困难驾驶及测试脚本资源加载错误均保留在 `logs/030` 和 `logs/030-wip-r3`。没有将测试失败改成通过、改弱敌方装甲或删去胜利条件。

## 验收边界

030 比赛流程工程检查通过，真人体验为 PENDING。不是 028—036 全部完成，亦不是性能或逼真物理验收。下一步补 028 教学章节与 029 设置恢复，再走 031 独立 Windows 构建。未合并 main、未公开发布；回退候选为 d91024e，原工作区均保留。
