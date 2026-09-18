# 来源、时点与证据限制

本文件只索引依据，不包含未授权模型/游戏资源。GitHub路径绑定审查SHA或本次抽查SHA；对标网页为2026-09-18读取的公开描述。此规范的任务、算法选择、阈值冻结流程和验收用例属于项目设计，不冒充官方算法。

## [R00] 本次主线与AGENTS抽查

类别：repository · 版本：`3b2fe165a69e1a777c5c4d02b852b7e5438e3388`

支持：2026-09-18 读取主线为3b2fe165；读取其HEAD元数据、AGENTS、DamageResolver和QuerySnapshotBuilder。

不能据此认定：没有重新全量审计该HEAD，不能声称全部旧差距仍未修。执行时保留后继内容。

- https://github.com/mahochyan/mcthunder/blob/3b2fe165a69e1a777c5c4d02b852b7e5438e3388/AGENTS.md

## [R01] 动态命中对象与空弹架风险

类别：repository · 版本：`3b2fe165a69e1a777c5c4d02b852b7e5438e3388`

支持：当前抽查快照主要包含布局/位姿；模块伤害按预算与阻力求解。与上一轮调用链一起提示空架仍可能参与损伤和阻力。

不能据此认定：这是待复现风险，不是本次已运行证明的Bug。

- https://github.com/mahochyan/mcthunder/blob/3b2fe165a69e1a777c5c4d02b852b7e5438e3388/scripts/query/query_snapshot_builder.gd
- https://github.com/mahochyan/mcthunder/blob/3b2fe165a69e1a777c5c4d02b852b7e5438e3388/scripts/damage/damage_resolver.gd

## [R02] 弹丸推进与几何查询

类别：repository · 版本：`b7da3e508b0dcf0a786eb7bc74cc2fc43ad6de60`

支持：上一轮审查显示主查询是线段；运动处理为有限平移扫掠，旋转/不连续有回退；飞行主要按重力。

不能据此认定：未证明最新后继已无改动，也未测体积或移动边缘漏判频率。

- https://github.com/mahochyan/mcthunder/blob/b7da3e508b0dcf0a786eb7bc74cc2fc43ad6de60/scripts/projectiles/projectile_manager.gd
- https://github.com/mahochyan/mcthunder/blob/b7da3e508b0dcf0a786eb7bc74cc2fc43ad6de60/scripts/projectiles/projectile_state.gd
- https://github.com/mahochyan/mcthunder/blob/b7da3e508b0dcf0a786eb7bc74cc2fc43ad6de60/scripts/projectiles/ballistic_math.gd
- https://github.com/mahochyan/mcthunder/blob/b7da3e508b0dcf0a786eb7bc74cc2fc43ad6de60/scripts/query/shot_query_service.gd

## [R03] 穿透、材料与反应装甲

类别：repository · 版本：`b7da3e508b0dcf0a786eb7bc74cc2fc43ad6de60`

支持：已有分弹族的版本化游戏规则、材料响应、复合系数和单次ERA状态。

不能据此认定：配置自洽不等于与战雷具体车型数值一致。

- https://github.com/mahochyan/mcthunder/blob/b7da3e508b0dcf0a786eb7bc74cc2fc43ad6de60/scripts/armor/armor_resolver.gd
- https://github.com/mahochyan/mcthunder/blob/b7da3e508b0dcf0a786eb7bc74cc2fc43ad6de60/scripts/armor/armor_impact_profile.gd
- https://github.com/mahochyan/mcthunder/blob/b7da3e508b0dcf0a786eb7bc74cc2fc43ad6de60/scripts/armor/armor_layer_profile.gd
- https://github.com/mahochyan/mcthunder/blob/b7da3e508b0dcf0a786eb7bc74cc2fc43ad6de60/scripts/armor/reactive_armor_profile.gd

## [R04] 车型几何和现代工程配置

类别：repository · 版本：`b7da3e508b0dcf0a786eb7bc74cc2fc43ad6de60`

支持：已有三环车体重建、逻辑装甲区和明确标为工程设计的两车弹药数据。

不能据此认定：原始资料、工程估算、游戏规则和历史真值不能互换；17逻辑区并非17块真实均匀板。

- https://github.com/mahochyan/mcthunder/blob/b7da3e508b0dcf0a786eb7bc74cc2fc43ad6de60/scripts/content/historical_vehicle_geometry.gd
- https://github.com/mahochyan/mcthunder/blob/b7da3e508b0dcf0a786eb7bc74cc2fc43ad6de60/configs/vehicles/engineering/ussr_t_80b.json
- https://github.com/mahochyan/mcthunder/blob/b7da3e508b0dcf0a786eb7bc74cc2fc43ad6de60/configs/vehicles/engineering/germ_leopard_2a4.json
- https://github.com/mahochyan/mcthunder/blob/b7da3e508b0dcf0a786eb7bc74cc2fc43ad6de60/configs/shells/modern_engineering_loadouts.json

## [R05] 穿后与引信后效

类别：repository · 版本：`b7da3e508b0dcf0a786eb7bc74cc2fc43ad6de60`

支持：已有APHE内部路径/有限破片、定向剥落和HEAT射流；旧内部爆炸有固定预算/范围模板。

不能据此认定：没有本次完整HE/超压链的运行证明；数量多不自动意味着更真实。

- https://github.com/mahochyan/mcthunder/blob/b7da3e508b0dcf0a786eb7bc74cc2fc43ad6de60/scripts/projectiles/shell_effect_policy.gd
- https://github.com/mahochyan/mcthunder/blob/b7da3e508b0dcf0a786eb7bc74cc2fc43ad6de60/scripts/projectiles/fragment_system.gd
- https://github.com/mahochyan/mcthunder/blob/b7da3e508b0dcf0a786eb7bc74cc2fc43ad6de60/scripts/projectiles/chemical_jet_system.gd

## [R06] 状态、乘员、模块和恢复

类别：repository · 版本：`b7da3e508b0dcf0a786eb7bc74cc2fc43ad6de60`

支持：已有独立状态、死亡去重、能力推导、起火/恢复/隔舱保护；部分能力是完整度零阈值，乘员以alive表示。

不能据此认定：不能据HUD颜色认定乘员已具有伤势或所有模块都有渐进功能。

- https://github.com/mahochyan/mcthunder/blob/b7da3e508b0dcf0a786eb7bc74cc2fc43ad6de60/scripts/defs/vehicle_runtime_state.gd
- https://github.com/mahochyan/mcthunder/blob/b7da3e508b0dcf0a786eb7bc74cc2fc43ad6de60/scripts/damage/vehicle_capabilities.gd
- https://github.com/mahochyan/mcthunder/blob/b7da3e508b0dcf0a786eb7bc74cc2fc43ad6de60/scripts/damage/vehicle_recovery.gd
- https://github.com/mahochyan/mcthunder/blob/b7da3e508b0dcf0a786eb7bc74cc2fc43ad6de60/scripts/vehicle_actor.gd

## [R07] 装填与弹架后继成果

类别：repository · 版本：`b7da3e508b0dcf0a786eb7bc74cc2fc43ad6de60`

支持：已实现T-80B自动装填、豹2待发/备用及隔舱策略的接续和实弹专项记录。

不能据此认定：不重新设计一套库存；专项证据不能代替全部自然对局。

- https://github.com/mahochyan/mcthunder/blob/b7da3e508b0dcf0a786eb7bc74cc2fc43ad6de60/scripts/defs/loading_profile.gd
- https://github.com/mahochyan/mcthunder/blob/b7da3e508b0dcf0a786eb7bc74cc2fc43ad6de60/scripts/gunner.gd
- https://github.com/mahochyan/mcthunder/blob/b7da3e508b0dcf0a786eb7bc74cc2fc43ad6de60/docs/wt/continuation/WT040_MATERIAL_AND_STOWAGE_20260917.md

## [R08] 驾驶、悬挂、机构

类别：repository · 版本：`b7da3e508b0dcf0a786eb7bc74cc2fc43ad6de60`

支持：已有CharacterBody3D驱动、等效动力区间、履带与四点运动学悬挂，实际姿态参与查询。

不能据此认定：本单不将换刚体节点或逐轮物理设为目标，也未实测对标驾驶曲线。

- https://github.com/mahochyan/mcthunder/blob/b7da3e508b0dcf0a786eb7bc74cc2fc43ad6de60/scripts/tank.gd
- https://github.com/mahochyan/mcthunder/blob/b7da3e508b0dcf0a786eb7bc74cc2fc43ad6de60/scripts/drive/drive_powertrain.gd
- https://github.com/mahochyan/mcthunder/blob/b7da3e508b0dcf0a786eb7bc74cc2fc43ad6de60/scripts/drive/suspension_response.gd
- https://github.com/mahochyan/mcthunder/blob/b7da3e508b0dcf0a786eb7bc74cc2fc43ad6de60/scripts/turret_rig.gd

## [R09] 战斗规则和归因

类别：repository · 版本：`b7da3e508b0dcf0a786eb7bc74cc2fc43ad6de60`

支持：现有300票等项目规则、事件去重和结果冻结；个人SP与完整贡献结算不由固定胜负奖励替代。

不能据此认定：这里只引用审查时实现；不把建议新增的RB规则认定为当前已有。

- https://github.com/mahochyan/mcthunder/blob/b7da3e508b0dcf0a786eb7bc74cc2fc43ad6de60/scripts/battle/match_rule_preset.gd
- https://github.com/mahochyan/mcthunder/blob/b7da3e508b0dcf0a786eb7bc74cc2fc43ad6de60/scripts/battle/respawn_service.gd
- https://github.com/mahochyan/mcthunder/blob/b7da3e508b0dcf0a786eb7bc74cc2fc43ad6de60/scripts/battle/team_match_director.gd

## [R10] 反馈与网络边界

类别：repository · 版本：`b7da3e508b0dcf0a786eb7bc74cc2fc43ad6de60`

支持：反馈有真实事件来源；审查的网络服务仍是本机双客户端技术会话。

不能据此认定：本计划不自动授权公网部署/付费账号服务/容量冲刺。

- https://github.com/mahochyan/mcthunder/blob/b7da3e508b0dcf0a786eb7bc74cc2fc43ad6de60/scripts/feedback/combat_feedback.gd
- https://github.com/mahochyan/mcthunder/blob/b7da3e508b0dcf0a786eb7bc74cc2fc43ad6de60/scripts/network/network_battle_server.gd
- https://github.com/mahochyan/mcthunder/blob/b7da3e508b0dcf0a786eb7bc74cc2fc43ad6de60/scripts/battle/observation_policy.gd

## [R11] 已完成后继必须保留

类别：repository · 版本：`b7da3e508b0dcf0a786eb7bc74cc2fc43ad6de60`

支持：已记录现代包入口、同一玩家受控实弹死亡再出击、内构分色HUD及AI后继成果。

不能据此认定：不沿用更老的“现代包不可用/没有悬挂”等结论；包身份与每次测试分别绑定。

- https://github.com/mahochyan/mcthunder/blob/b7da3e508b0dcf0a786eb7bc74cc2fc43ad6de60/docs/wt/continuation/WT040_CE697_PACKAGE_20260917.md
- https://github.com/mahochyan/mcthunder/blob/b7da3e508b0dcf0a786eb7bc74cc2fc43ad6de60/docs/wt/WT033_DAMAGE_HUD_20260917.md

## [W01] 官方：体积弹丸

类别：official

支持：官方开发说明解释以弹丸尺寸处理窄缝和边缘接触的机制动机。

不能据此认定：不是可直接复制的全部当前算法或完整误差规格。

- https://warthunder.com/en/news/6856-development-volumetric-shells-in-the-raining-fire-update-en

## [W02] 官方Wiki：地面模块

类别：official

支持：空弹架、不同模块损伤方式及隔舱等公开机制是行为参考。

不能据此认定：乘员章节正文与表格对中间伤势效能表述不一致；不得据此硬编码统一伤势罚率。

- https://wiki.warthunder.com/mechanics/4775-ground-vehicle-modules

## [W03] 官方Wiki：坦克弹药

类别：official

支持：弹族、引信和后效差异作为对标范围。

不能据此认定：不是所有具体弹药的完整参数或保密物理模型。

- https://wiki.warthunder.com/weapon/2544-tank-ammunition

## [W04] 官方Wiki：高爆与超压

类别：official

支持：区分爆破/破片/超压；HEAT射流与爆炸通道不等同。

不能据此认定：本单不提供现实爆炸工程设计或将未公开阈值冒充已知。

- https://wiki.warthunder.com/mechanics/4236-the-mechanics-of-high-explosive-effect-and-overpressure

## [W05] 官方Wiki：自动装填

类别：official

支持：机制损坏、待发弹架与已装膛最后一发需要区别对待。

不能据此认定：车型性能、时间与规则仍须明确版本化。

- https://wiki.warthunder.com/mechanics/5255-autoloader

## [W06] 官方Wiki：稳定器

类别：official

支持：不同稳定能力、瞄具与炮管跟随的区分。

不能据此认定：不将镜头稳定直接等价为武器稳定。

- https://wiki.warthunder.com/mechanics/199-gun-stabilizer

## [W07] 官方Wiki：常规陆战拟真

类别：official

支持：常规Ground RB的个人出击资源、编成和情报边界作为本轮目标。

不能据此认定：活动模式例外不纳入；费用/收益不是冻结不变的常数。

- https://wiki.warthunder.com/gamemode/realistic_battles

## [H01] 用户附件：当前项目开发进度报告（历史快照）

类别：user_attachment · 版本：`a1bac406d2bc12b32c7f7d130590f1c1a17907c9`

支持：说明原项目模块、旧/新WT台账及长期目标；原文保留自己的时点与术语。

不能据此认定：其2026-09-13未推送、0 completed、旧导出预设和远端落后等结论不代表当前状态。


## 已知资料冲突处理

W02乘员部分的正文与表格对伤势效能有不一致表述。本计划只把伤势与岗位独立作为设计要求，不以此武断采用线性罚率。具体版本未复核前，战雷行为比较保持NOT_COMPARED。

常规Ground RB作为本轮参考，不把临时活动的SP规则混入。正式拟真preset使用项目版本和显式偏离表，不直接复制未知BR或费用。
