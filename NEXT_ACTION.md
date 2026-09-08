# 接续开发
用户已授权按docs/handoff/DEVELOPMENT_007_036.md连续完成007—036，工程通过后不逐单等待签收。
开发目录E:/AIprogram/mcthunder-development；原E:/AIprogram/mcthunder保持旧main及用户文件。
007—017已实现并通过工程自查，真人验收not_run，当前车辆性能/厚度仍是test_only设计值。逐单证据见docs/DELIVERY_007.md至DELIVERY_017.md。
017源码4b3db50fa2746a086b7687e565555dfdc43ff7e1：15套1180项PASS，最终窗口25项、10截图和独立候选通过。正式HUD、受视线与6秒冻结约束的小地图、Tab战况、Q/E阵亡观察、字号/视觉设置和输入释放门已接入Team与Duel。
下一步work/018-map-village：先作出生/两主路/长侧翼/中央据点的原创丘陵村庄灰盒，检验八出生点可达、默认射线无出生直通、最大车型通行、真实挡弹与草丛语义，再完善原生低多边形环境表现。地图UI与导航共享公开布局数据，不在地图脚本赠送补给。
继承016唯一生命身份、结束冻结、友军/保护/残骸挡弹；继承017HUD只读和敌情权限。不得用直接写成功状态替代正常入口演示。
美术定位为low-poly低多边形，执行ART_DIRECTION_LOW_POLY与MODELING_STANDARD；外形保留车型特征。帧率有波动，017末尾快照32，不能宣称60FPS；033需正式性能采样优化。
固定引擎4.7.2.stable.official.ed1daf0bf；不强推、不默认合并main、不付费或公开发行、不冒充真人验收。
