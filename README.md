# PixelArmor / MCTHUNDER

原创 **low-poly（低多边形）装甲游戏**。视觉以准确车型轮廓、简洁分面和清楚的机械结构为准；总体玩法目标是尽可能还原战争雷霆式陆战。当前美术策略见 [低多边形方向](docs/ART_DIRECTION_LOW_POLY.md)，完整路线见 [开发计划](docs/handoff/DEVELOPMENT_007_036.md)。当前开发版包含装甲结算、内部损伤、弹药账本、火灾与维修/乘员替补、真实路径回放、中文车库与核心训练；1对1歼灭及4对4占点已有正常入口，正式HUD与第一张丘陵村落地图已接入。后续车型、第二地图与进度系统仍按计划开发。

## 启动开发版
双击本目录 **START_GAME.bat**，固定 Godot 4.7.2 stable 普通版 / GDScript / Compatibility。
开发目录：E:/AIprogram/mcthunder-development；原 E:/AIprogram/mcthunder 保留旧 main。
车库选择“4 对 4 占点”进入团队战：300票，阵亡扣30票，中央据点占领扣敌票；阵亡等待8秒后选择再出击，出生保护3秒。正式R不能复活；Esc菜单可放弃当前车并正常扣票。
当前地图“丘陵村落”320×320米：从左右入口绕过出生区石墙，向中央据点推进；西侧外路可爬坡绕到另一侧。村舍、石墙、实板围栏挡车挡弹，低草不挡弹，后勤预留区暂不提供补给。
正式战斗HUD显示自己真实的部件、乘员、装填与限制原因；小地图只给敌方目击或限时最后位置。Tab查看战况，阵亡Q/E观察友军；Esc→显示与辅助提供大字、高对比与闪光/稳定镜头/结算回放选项。
启动后中文车库选择AP70/AP120、携弹量与七个课目，进入训练；Enter结果，Esc暂停/返回。M4A3外形工程样车可旋转检视；形状估算，性能仍为训练设计。专项实验室包含装甲、近远弹道、恢复和地形；左栏向下滚动可见。地形1—4新开10/20/30度坡或障碍路线，Tab接管坡上车。
Esc → **Damage Range** 验证模块损伤；Tab接管受损车，X切换训练透视，R重开。
Esc → **Recovery Range** 验证损伤后应对；1—5开始训练新局，正常射击后Tab接管B，T维修、F灭火、C乘员换位、G取消。
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
`pwsh -File tests/run_suite_checks.ps1 -Order 018`：固定引擎导入与17套检查，包含射击/装甲/内构/恢复/回放/驾驶/AI/对局/HUD/地图；018候选1,228项通过。
运行器保存源码 SHA、命令、stdout/stderr、退出码、超时及错误扫描。只有布局套件三条指定负例错误允许出现；其他 ERROR/SCRIPT ERROR 即使退出0也判失败。

单套：`tools/godot/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tests/run_armor_checks.gd`

真实图形与正常输入演示：`tools/godot/Godot_v4.7.2-stable_win64_console.exe --path . --resolution 1280x720 --max-fps 60 -s res://tests/run_armor_demo.gd`

日志：logs/007/；截图：docs/evidence/007/。真人验收独立保持 not_run，不以自动截图代签。
进度见 [NEXT_ACTION](NEXT_ACTION.md)，既有基线签收见 [REVIEW_006_ACCEPTANCE](docs/REVIEW_006_ACCEPTANCE.md)。

回放：V开关、逗号/句号历史、N真实接触、J导出单炮JSON；[010交付](docs/DELIVERY_010.md)。


[011核心候选及947项回归/87项窗口证据](docs/DELIVERY_011.md)。真人体验仍待验收。

