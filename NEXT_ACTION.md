# 接续开发
用户已授权按docs/handoff/DEVELOPMENT_007_036.md连续完成007—036，工程通过后不逐单等待签收。
开发目录E:/AIprogram/mcthunder-development；原E:/AIprogram/mcthunder保持旧main及用户文件。
007—019已实现并通过工程自查，真人验收not_run，当前车辆性能/厚度仍是test_only设计值。逐单证据见docs/DELIVERY_007.md至DELIVERY_019.md。
019运行源码c0f1e4fa725364f21ca71de614b3a67b37a4f3ac，窗口/导出候选d2afacfe7c360efdd4b8abd13173b9f9ac1f72e2（仅验证脚本差异）：18套1236项、10场完整AI比赛50项、正常玩家16项/10截图与真正独立exe10项均PASS。官方同版本模板已下载校验并安装，候选位置见DELIVERY_019。真实玩家自动输入313秒自然胜利后再开第二局，真人三场仍NOT_RUN。
下一步work/020-historical-vehicles：完成锁定M4A3(75)W 1944 VVSS及其余三款具体改型资料审核、共享数据管线、独立布局/装甲/武器适配与可玩入口。其他三车尚待按完整资料选型，不按四职业拼接历史配置。研究原PDF位于工程外E:/AIprogram/research-sources/020；尚未登记的字段不能称已核验，必须保留primary/secondary/estimated/game_rule来源区别。
继承016唯一生命身份、结束冻结、友军/保护/残骸挡弹；继承017HUD只读和敌情权限。不得用直接写成功状态替代正常入口演示。
美术定位为low-poly低多边形，执行ART_DIRECTION_LOW_POLY与MODELING_STANDARD；外形保留车型特征。019八车窗口测得平均53.642FPS、P95 41.904ms、P99 69.222ms（i5-13400/RTX4070 SUPER），长帧与局部驾驶恢复失败列P2；033正式优化。Minimap静态道路已缓存，但整体帧率收益未证明。
固定引擎4.7.2.stable.official.ed1daf0bf；不强推、不默认合并main、不付费或公开发行、不冒充真人验收。
