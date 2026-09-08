# 009：弹药账本、火灾、维修、换位与残骸
implementation=implemented；engineering=passed_self_review；human=not_run；content_history=test_only。
源码ad8fdf13713e23871b8973f038200fdcfff271e3；基线008登记2d413a434eb2c72c10712c8c5fb62a44f92fd9f2；分支work/009-damage-recovery。

## 玩家新增能力
START_GAME.bat → Esc → Recovery Range。1—5分别开始断履带、发动机起火、炮手替补、有弹架、空弹架训练新局；伤害来自正常瞄准射击。Tab接管同一辆受损B，T维修、F灭火、C替补、G取消。R重新开始当前情形。
面板显示真实部件/乘员、弹架/膛内/装填途中库存、动作进度、消耗品、拒绝原因与阵亡来源；火焰和灰色残骸只读取状态。

## 实际规则与接口
- AmmoInventory独立保存racks+chamber+in_transfer；成功发射消耗膛内一发，装填搬移一发，失败发射不消耗。supplied=available+fired+lost可校验；重复转移/取消/死亡不复制弹药。旧rounds_remaining为该账本兼容读数，显式设置用于训练初始配弹/既有夹具。
- 有弹架直接命中后完整度<=0触发一次本车殉爆；空架不殉爆，膛内有弹也不会把空弹架算成有弹架。首版无邻车爆炸伤害。
- RecoveryRules集中游戏参数：发动机有效直击后<=25%点火；1秒tick使布局明确关联模块损失5%最大完整度。布局明确关联乘员累计暴露20秒失能，这是公开的测试游戏规则。环境火源为空，不冒领最近玩家。
- F动作4秒、初始2次、开始扣一次，取消不退。T驻车且未起火，按履带/炮闩/发动机/传动/炮塔驱动选择一个模块，12秒修到50%；移动意图、实际速度>=0.2或起火中断，本生命期保留进度。普通维修不复活、不补弹、不补耗材。
- C动作8秒，优先炮手再驾驶员；由车长/副驾驶/装填手中的可用人员补位，原人员不复活，一人不占双岗。替补受伤/目标已补位/重置/死亡会取消。
- VehicleCommand/CommandMailbox/PlayerController只提交动作，VehicleActor一次物理消费驱动VehicleRecovery；暂停冻结火灾、动作、装填和残骸时间；恢复边界要求释放旧动作。
- destroy_once保存来源及死亡前弹药快照并幂等通知。target_generation随重置推进，旧查询不能损伤新状态；外部通知后也检查代次。
- WreckRegistry保留真实车辆碰撞/装甲，默认12具/120秒，清理不发第二次死亡。当前固定双车训练保护两车供接管观察，人口上限始终为2，R/换场清理登记；通用注册器的数量/寿命清理另有真实实体测试。

## 本轮修复
首次正常流程发现第三人称意图射线使用驾驶碰撞盒，瞄炮塔上部时可能越过模型而把炮管压向后方世界点。CameraRig现在在resolve模式的物理阶段读取同一装甲快照及外露模块，准心意图可命中真实炮塔轮廓；不是通过扩大伤害盒或篡改截图修复。新增高于驾驶碰撞盒的瞄准反例与重置缓存检查。旧legacy夹具保留旧模式。
失败窗口日志保留在logs/009/wip-uncommitted/window-20260908-150752/（3个换位流程断言失败）；修正后WIP与最终源码均通过。失败证据不记为通过，也不冒称属于已提交源码。

## 真实验证
固定Godot4.7.2.stable.official.ed1daf0bf，Windows/Compatibility。
同一最终源码ad8fdf1：tests/run_suite_checks.ps1 -Order 009，全量基础216、布局123、查询140、弹道144、装甲81、损伤57、恢复64，共825项通过，全部exit=0。非预期ERROR/SCRIPT ERROR=0；布局三条预期负例按内容/次数校验。
记录：logs/009/ad8fdf13713e23871b8973f038200fdcfff271e3/20260908-152227/，含命令、版本、exit、完整输出与RESULTS.json。

tests/run_window_checks.ps1 -Order 009：真实菜单/鼠标瞄准/五发射击/Tab接管/T/F/C/W/Esc/R与自然计时，34项通过，exit=0，1280×720，末尾实测60FPS/60Hz。八张真实截图在docs/evidence/009/ad8fdf13713e23871b8973f038200fdcfff271e3/window-20260908-152227/；完整日志及元数据在对应logs/009/.../window-20260908-152227/。
本模型目视检查了换位、殉爆残骸与灭火进度画面；真人验收仍NOT_RUN。

## 边界与下一步
仍是明确设计参数的工程测试车，非已认证历史M4A3性能。英文HUD和简化方块火焰暂保留，中文核心界面在011接入。历史材料及真人保留项不代签。恢复系统在Recovery Range启用，008 Damage Range保留无火灾的原对照规则。
下一阶段010保存有限且不可变的真实ShotRecord并做独立只读穿透回放。未合并main、未公开发行、未购买资产或更换引擎。
