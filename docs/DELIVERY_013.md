# 013：电脑驾驶与 low-poly 策略落地
implementation=implemented；engineering=passed_self_review；human=not_run；content_history=test_only_silhouette_estimated。
分支work/013-ai-drive；源码371b44bbbc9878254ae3409f25af1d98f48c993f；起点012登记4cb815e479c869f09500841ce101fd8aafec506f。

## 正常可见结果
中文车库左栏向下滚动→“电脑驾驶实验室”。默认电脑车绕箱区到达黄框；1直行、2直角、3绕箱、4窄道拒绝、5被玩家车挡住后倒车脱困。Tab在全景观察与玩家驾驶之间切换，电脑绑定不变。可把玩家车开到前方挡路；P显示/隐藏只读路径，Esc返回车库，R或数字键明确重开案例。

DriveNavigator读取随工程打包的有限路点图，确定性A*按碰撞宽度+0.6m筛边，图外/过窄/断路明确返回。AIPathDriver只产出VehicleCommand，仍由VehicleActor一次物理提交/消费/执行；没有AI位置写入、穿墙或独立驱动。拐角停车转向、目标区驻车、三条实际物理射线探测前方障碍，真实移动不足2秒后短倒车、改角与重新规划。最多3次脱困，失败后停止意图并自然减速。图是灰盒场地的配套设计，不宣称自动适配任意地图。

发动机/履带失能仍由共享Capabilities约束。死亡/状态代次变化/解绑/释放清掉旧目标；AI无法获取本地键鼠。相机只由VehicleActor显式给予本地控制者，新AI初始化不会抢当前观察镜头。控制器poll期间发生重置或解绑时，Actor代次门拒绝旧命令。

## 用户最新总策略
用户在本单明确将总定位改为**low-poly低多边形**，继续要求外形贴近原型。ART_DIRECTION_LOW_POLY、MODELING_STANDARD、AGENTS、总计划、接手计划、游戏规则、025美术单、README/启动说明/车库标题已同步；旧交付记录保留历史状态。

M4模型圆轮/舱盖改为16边平法线圆柱，主炮为分面锥形管与开口炮口；保留斜车体、炮塔、三组VVSS悬挂和附件，不改射击表面/厚度/模块数值。程序构造迁移为M4LowPolyDetails。细节实例网格670实例、13,500三角形、21组；炮管等单独网格另计，不能把这一数字当成整场开销。原“最少体素数”断言按用户策略改为三角形与批次预算；结构靠共用几何与实际多视角截图复核。

## 验证
- `tests/run_suite_checks.ps1 -Order 013`：11套1,012PASS（216/123/140/144/81/57/64/67/55/25/40），全部exit0，无非预期ERROR/SCRIPT ERROR。源码371b44b；完整命令/版本/输出在`logs/013/371b44bbbc9878254ae3409f25af1d98f48c993f/20260908-175825/`。
- AI的40项含5路线实际Actor执行、逐步位移上限、绕箱侧向位移、拒绝窄道、有限失败、毁伤/重置/销毁/解绑、全局输入隔离与poll重入保护。会车案例按真实PhysicsServer逐帧同步，最近两车中心距5.446m，双方在有界时间内明确停止为不可达；没有把“会车最终都到达”作为已实现结果。该套使用`--fixed-fps 60`加速真实物理帧，不跳过动态碰撞同步。
- `tests/run_window_checks.ps1 -Order 013 -Script run_ai_drive_player_checks -TimeoutSeconds 180`：20PASS、8张实机图、exit0、末尾59FPS，目录`window-20260908-175916`。正常鼠标旋转low-poly预览/进入、实时绕障停车、4拒绝、5倒车换路到达、Tab/W只驱动玩家、Esc返回。全程未通过写车辆坐标制造行驶结果。
- 目视检查最终low-poly车库与此前同场景绕障构图，机械轮廓/路径/中文阶段可读。真人手感与外观认可NOT_RUN。

## 边界与修复
早期会车测试在单个物理帧内批量移动两个动态Body，缺少引擎同步导致错误的重叠结果；修正夹具为逐真实帧后验证通过。旧相机ready自动current逻辑确实会抢镜头，已移除并保留多AI回归。自动规划为有限图与有限脱困，狭窄会车仍可能以明确失败结束；当前不做全局交通协调。感知/开火/战术为下一单014，013电脑不生成开火请求。

## 本机候选
`tests/package_candidate.ps1 -Order 013`生成`backups/candidates/013/371b44bbbc9878254ae3409f25af1d98f48c993f/PixelArmor/START_GAME.bat`。独立导入与默认启动exit0；包含导航JSON和新模型文件。源码+固定引擎本机候选，未公开发布，未合并main。下一步014感知、反应延迟、公平瞄准/射击与搜索。
