# PixelArmor / MCTHUNDER

原创体素／低模方块视觉的坦克战斗原型。总体目标是尽可能还原战争雷霆式陆战玩法；完整路线见 [开发计划](docs/handoff/DEVELOPMENT_007_036.md)。当前开发版在 006 弹道基础上实现 007 装甲结算。内部损伤、维修、回放、AI、车库与完整比赛仍按依赖推进；计划不是已完成内容。

## 启动开发版
双击本目录 **START_GAME.bat**，固定 Godot 4.7.2 stable 普通版 / GDScript / Compatibility。
开发目录：E:/AIprogram/mcthunder-development；原 E:/AIprogram/mcthunder 仍为旧 main 001。
启动后 Esc → **Armor Range** 进入装甲训练；**Ballistics Range** 保留近远弹道训练。
训练中 Esc → Return to Range 返回主靶场。

## 操作
| 输入 | 功能 |
|---|---|
| W/S、A/D | 驾驶、车体转向 |
| 鼠标、右键 | 瞄准、炮镜 |
| 左键 | 发射，扣弹并自然装填 |
| R | 重开当前训练 |
| Esc | 暂停/恢复与场景入口 |
| 1—6（装甲训练） | 薄板、厚板、斜板、双层板、跳弹、未知装甲 |

训练 AP70 与标准板为明确游戏设计值，非历史性能认证。穿甲累计消耗不恢复；跳弹保留一半剩余预算、速度乘0.6；UNKNOWN 停止并说明数据不足。详情来自真实接触记录。

## 自动验证
`pwsh -File tests/run_suite_checks.ps1`：固定引擎导入 + 基础/布局/查询/弹道/装甲五套检查。
运行器保存源码 SHA、命令、stdout/stderr、退出码、超时及错误扫描。只有布局套件三条指定负例错误允许出现；其他 ERROR/SCRIPT ERROR 即使退出0也判失败。

单套：`tools/godot/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tests/run_armor_checks.gd`

真实图形与正常输入演示：`tools/godot/Godot_v4.7.2-stable_win64_console.exe --path . --resolution 1280x720 --max-fps 60 -s res://tests/run_armor_demo.gd`

日志：logs/007/；截图：docs/evidence/007/。真人验收独立保持 not_run，不以自动截图代签。
进度见 [NEXT_ACTION](NEXT_ACTION.md)，既有基线签收见 [REVIEW_006_ACCEPTANCE](docs/REVIEW_006_ACCEPTANCE.md)。