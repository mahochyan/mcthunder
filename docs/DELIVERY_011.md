# 011：中文车库与核心训练候选
implementation=implemented；engineering=passed_self_review；human=not_run；content_history=test_only。
源码9faa1b6022ed5c0ee3e5daf21256169d02b7af66；基线010登记8143c24dc3e1779ad8bce49161bea48a7de6e9bf；分支work/011-core-slice。

## 正常玩家流程
START_GAME.bat直接进入中文GarageShell，可选AP70/AP120、1至30发、训练无限补给及七个课目；外观/实际装甲/五名乘员内构为独立只读预览。可驾驶项仅工程测试车，不把未核验M4A3作为正式车型。
进入CoreRange后使用原VehicleActor/命令/Gunner/ProjectileManager真实操作，TrainingDirector只接收本轮A身份的真实ShotRecord与目标状态。五个基础实验为正面厚甲、侧后弱点、发动机、炮闩、空弹架；附加断履带维修及78度斜板跳弹。
一炮解释展示接触角/实际预算/真实损伤/目标剩余能力，默认关闭X-ray仍可理解反馈。Enter结果，继续观察/重试/返回；失败/耗尽弹药可恢复。R显式重开本课目并复原双方、弹药/火灾/残骸/记录，保持配弹与X-ray设置；不是用维修复活。Tab操作受损B，T驻车维修。
无限补给只在成功发射后向训练射手实际弹架补1发并计supplied，原2秒自然装填不变；失败开火不补给。共享定义、目标库存、旧实验室默认不启用。车库返回不自动保存长期进度。

## 界面与资源
中文核心车库/HUD/回放/结果使用随工程分发的Noto Sans CJK SC及OFL原文，详见ASSETS_011.md。旧专项实验室部分工程标签仍英文；训练主反馈已中文。体素履带纹理块、轮组、舱盖、格栅均原创程序化几何，仅视觉层，无碰撞/毁伤坐标移动。当前外观是可辨识的临时工程标杆，非最终美术。
原--autoshot/--inspect-demo/--query-demo/--ballistics-demo入口保留原场景路由。
原始M4A3手册实际目视核对PDF14/24/350页，记录在车辆资料VISUAL_REVIEW_011.md；装甲厚度和精确内构缺口仍未解决，没有用游戏测试参数替代史实。

## 修复及完整证据
首次WIP窗口发现重复叠加Actor局部出生偏移，使B落在背墙后；修为Tank世界坐标，并新增七个课目真实30米位置断言。失败日志保留在logs/011/wip-uncommitted/window-20260908-161656/（14个失败）。此前选择器演示把输入投向错误窗口的失败也原样保留；最终使用真实鼠标点下拉项，未直接调用select制造玩家结果。
源码9faa1b6：tests/run_suite_checks.ps1 -Order 011，九套947PASS（216/123/140/144/81/57/64/67/55），全部exit=0，非预期ERROR/SCRIPT ERROR=0。完整输出/命令/版本见logs/011/9faa1b6022ed5c0ee3e5daf21256169d02b7af66/20260908-162831/。
同源码tests/run_window_checks.ps1 -Order 011 -Script run_core_player_checks -TimeoutSeconds 180：87PASS、exit=0，1280×720末尾59FPS/60Hz。真实车库选择AP70、鼠标增加携弹到11、七课目每次正常瞄准/射击、自然维修、Enter结果/鼠标返回。截图与对应日志在docs/evidence/011/9faa1b6022ed5c0ee3e5daf21256169d02b7af66/window-20260908-162955/及logs对应目录。模型目视检查了车库、发动机回放/结果、维修进度，未发现核心中文遮挡；真人NOT_RUN。

## 独立本机候选
执行tests/package_candidate.ps1 -Order 011，生成backups/candidates/011/9faa1b6022ed5c0ee3e5daf21256169d02b7af66/PixelArmor/。这是源码+固定引擎运行目录，不是导出游戏exe。仅runtime目录/配置/字体/启动说明及engine；无Git、历史证据或旧缓存。独立首次导入和默认入口启动均exit0，字体hash匹配，日志logs/011/9faa.../candidate/RESULTS.json。引擎和候选未入Git，未对外发布。

## 阶段状态
GATE_A.md分列工程证据与人工PENDING。尚无AI、比赛、长期成长/正式车型；继续012坡地驾驶。原main未合并，旧工作目录仍保留。
