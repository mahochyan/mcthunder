# PixelArmor / MCTHUNDER

原创 **low-poly（低多边形）装甲游戏**。视觉以准确车型轮廓、简洁分面和清楚的机械结构为准；总体玩法目标是尽可能还原战争雷霆式陆战。当前美术策略见 [低多边形方向](docs/ART_DIRECTION_LOW_POLY.md)，完整路线见 [开发计划](docs/handoff/DEVELOPMENT_007_036.md)。当前开发版包含装甲结算、内部损伤、弹药账本、火灾与维修/乘员替补、真实路径回放、中文车库与核心训练；1对1歼灭及4对4占点已有正常入口，正式HUD与第一张丘陵村落地图已接入。后续车型、第二地图与进度系统仍按计划开发。

## 启动开发版
双击本目录 **START_GAME.bat**，固定 Godot 4.7.2 stable 普通版 / GDScript / Compatibility。
开发目录：E:/AIprogram/mcthunder-development；原 E:/AIprogram/mcthunder 保留旧 main。
020候选新增四款具体历史配置：M4A3(75)W 1944 VVSS、M24 M6/T85E1 1951五人、M26(T26E3) M3 1945、M36 M4A1炮架1945。车库下拉选择后可检视外观/装甲/内构、查阅逐字段来源、正常驾驶与射击；4对4及再出击使用所选车型。M61在020暂只模拟动能，内部爆发进入021。所有局部几何、未实测性能与未知字段明确标注，详见[车型与来源](docs/vehicles/HISTORICAL_020.md)。
四个完整Blender源文件与GLB外饰已接入；使用本机已安装的Blender5.2.1LTS，编辑/导出及装甲一致性检查见[建模流程](authoring/vehicles/README.md)。
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
`pwsh -File tests/run_suite_checks.ps1 -Order 019`：固定引擎导入与18套检查，包含射击/装甲/内构/恢复/回放/驾驶/AI/对局/HUD/地图/统计；019候选1,236项通过。
运行器保存源码 SHA、命令、stdout/stderr、退出码、超时及错误扫描。只有布局套件三条指定负例错误允许出现；其他 ERROR/SCRIPT ERROR 即使退出0也判失败。

单套：`tools/godot/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tests/run_armor_checks.gd`

真实图形与正常输入演示：`tools/godot/Godot_v4.7.2-stable_win64_console.exe --path . --resolution 1280x720 --max-fps 60 -s res://tests/run_armor_demo.gd`

日志：logs/007/；截图：docs/evidence/007/。真人验收独立保持 not_run，不以自动截图代签。
进度见 [NEXT_ACTION](NEXT_ACTION.md)，既有基线签收见 [REVIEW_006_ACCEPTANCE](docs/REVIEW_006_ACCEPTANCE.md)。

回放：V开关、逗号/句号历史、N真实接触、J导出单炮JSON；[010交付](docs/DELIVERY_010.md)。


[011核心候选及947项回归/87项窗口证据](docs/DELIVERY_011.md)。真人体验仍待验收。

[019四对四独立候选](docs/DELIVERY_019.md)：10场固定种子比赛、正常玩家完整一局及下一局入口、真正Windows导出均已工程验证。候选exe位于backups/builds/019/d2afacfe7c360efdd4b8abd13173b9f9ac1f72e2/20260908-221404/PixelArmor.exe，与同目录PCK一起使用。当前八车窗口平均约53.6FPS，长帧仍需优化；真人三场试玩未进行。

