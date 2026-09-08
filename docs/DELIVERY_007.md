# 007：装甲接触、穿甲预算与可玩训练
implementation=implemented；engineering=passed_self_review；human=not_run；content_history=test_only。
继承 006 的 3a9326ddebc9c1ca88dadaf3d0943bcad7601641；最终源码候选 1e0fa40371caac1d97250830e159505dd4abc6c4。
用户已授权按接手计划持续推进；本单不等待旧模型签收，不改写 006 的历史 accepted_sha。

## 玩家新增能力
启动开发目录 START_GAME.bat → Esc → Armor Range。正常驾驶、鼠标瞄准、左键射击，1—6切换薄/厚/斜/双层/跳弹/UNKNOWN靶。
同一发可击穿第一层后继续飞，在第二层消耗剩余预算；结果面板显示真实角度、等效厚度、接触顺序、预算和路程。跳弹尾迹来自真实反射轨迹。切换靶不重置弹药或装填；R 明确重开。

## 实际接口
- PenetrationCurve 校验并线性采样 (m,mm)，非法输入拒绝。
- ArmorResolver 纯计算；P(s)=max(0,k*P_base(s)-C)，按累计消耗处理前后面；未知厚度/掠射保守停止。75度跳弹、速度0.6、预算0.5与最多一次均为集中 TEST ONLY 游戏规则。
- ProjectileManager 用当前剩余物理时间重新规划接触后的路线；不位置硬跳、不排除整车；同面起点去重，最多8接触/步、32/发。
- projectile_contact 与 projectile_finished 分开；记录先提交再通知。每目标生命期 first_for_target 只出现一次，Main 新模式从首次接触计分。回调清理守卫保持。
- 记录包含发射身份、接触编号、布局/部件姿态、入/出速度、预算与结果，为后续损伤/回放保留真实输入。
- 旧 ap_75 和006测试夹具明确标记 legacy_contact_only / TEST ONLY。新 resolve 模式不会把 UNKNOWN 当0。
- ArmorRange 复用原 PlayerController → VehicleCommand → VehicleActor → Gunner → ProjectileManager，没有训练专用伤害捷径。

## 修复与失败证据
上轮真实核验复现的 projectile_visuals.gd 入树顺序和 run_checks.gd 测试墙 look_at 顺序已修复。
新增真正的测试墙朝向断言。
初次全量候选 f91b562 的基础套件因头less默认64×64视口，新增菜单后继续按钮中心不在视口内而失败；d67c836初次设置过早仍失败。最终将测试执行延后至根窗口初始化后，再使用项目1280×720视口，真实鼠标点击恢复通过。原断言未删除，失败日志完整保留。
图形自检中发现并修复屏幕外面板锚点、UNKNOWN/跳弹等效厚度显示不明确的问题。

## 真实执行
固定 Godot 4.7.2.stable.official.ed1daf0bf，Windows，Compatibility。
同一最终源码候选 1e0fa40371caac1d97250830e159505dd4abc6c4：
| 套件 | 结果 | exit |
|---|---:|---:|
| run_checks |216/216|0|
| run_layout_checks |123/123|0|
| run_query_checks |140/140|0|
| run_projectile_checks |144/144|0|
| run_armor_checks |81/81|0|

共704项，非预期 ERROR/SCRIPT ERROR=0。布局3条负例 push_error 精确按内容和次数校验。
基础日志：logs/007/1e0fa40371caac1d97250830e159505dd4abc6c4/20260908-141232/。
其余四套：同 SHA 的20260908-141444/。RESULTS.json 含命令/版本/源码/exit/timeout/错误分类；stdout/stderr 为完整原始记录。

图形：docs/evidence/007/d67c836069df8c7ad68455c1fe50048a9edc123a/1280x720/；日志在对应 SHA 的 logs/007/.../demo/。
实际窗口 1280×720 / OpenGL3 / RTX4070SUPER，末尾实测60FPS；Esc、鼠标菜单点击、鼠标瞄准与6次开火、自然装填、弹药守恒全部演示断言通过，7PNG。
d67c836 到最终源码只改 run_checks 初始化时机，游戏与演示源码不变；没有把截图重新归属为最终SHA。
本模型目视检查了面板布局、双层结果、反射在飞尾迹与UNKNOWN说明；这属于模型图形自查，不能冒充真人验收。

## 保留项与下一步
目前仍为早期低模原型；英文游戏UI暂沿用默认字体限制，中文产品界面按后续计划完善。标准板只是规则夹具；历史厚度继续UNKNOWN，旧7页原图/12张历史演示截图与真人验收不代签。双层板线框有轻微共面闪烁，作为视觉整理项保留。
没有AI、完整战斗、损伤/维修/回放或正式历史弹种；下一步008接入真实内部路径与独立功能状态。
未合并main、未发布安装包、未更换引擎。
