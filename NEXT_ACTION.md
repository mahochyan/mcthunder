# 接续开发

用户已授权按docs/handoff/DEVELOPMENT_007_036.md连续完成007—036，工程通过后不逐单等待签收。开发目录E:/AIprogram/mcthunder-development；原E:/AIprogram/mcthunder保持旧main及用户文件。

007—020已实现并通过工程自审，真人验收not_run。逐单证据见docs/DELIVERY_007.md至DELIVERY_020.md。020最终代码11ec52a19e572ff3ae04462c2df329a9088bdc4f，完整21套1461项在79ea36e通过，最后仅显示修复后两套247项及真实窗口84项再次通过；28张最终抓帧已助手读图。四个完整Blender模型和GLB使用已安装E:/blender/blender.exe（5.2.1LTS）。历史字段有primary/secondary/estimated/unknown/game_rule区别，不能把整车性能宣称全部已核验。

下一步work/021-shell-loadouts：扩展009的唯一弹药账本，使选择下一弹、膛内保持、装填中切换、真实架位容量与补给守恒一致；接入有限游戏化APHE车内爆发、至多12条有查询/装甲阻挡的碎片、固定种子和实际回放记录。不能加入真实爆药/引信工程参数，不使用“APHE固定0.8倍穿深”冒充历史资料。

当前四车：M4A3(75)W 1944 VVSS / M72；M24 M6/T85E1 1951五人选项 / M61；M26(T26E3) M3 1945 / M77；M36 M4A1炮架1945汽油敞顶 / M77。M24的M61在020尚只有动能路径，车库已明确提示，021应落实其游戏化内部效果并查询其他适配弹药。资料原文在E:/AIprogram/research-sources/020，完整引用索引在docs/vehicles/HISTORICAL_020.md。严禁跨改型移植装甲或炮盾。

继承016唯一生命身份、结束冻结、友军/保护/残骸挡弹；继承017HUD只读和敌情权限。正常入口演示不直接写成功状态、清冷却或造命中。Blender编辑及装甲一致性流程见authoring/vehicles/README.md，美术继续low-poly方向。

019长帧和局部驾驶恢复失败列P2；020四车道路矩阵16路线通过，但不代表所有动态拥堵均已解决。新模型GLB约1.46万—1.74万三角形，履带另约4800，025/029做LOD和预算，033做正式整场性能优化。

固定引擎4.7.2.stable.official.ed1daf0bf；不强推、不默认合并main、不付费或公开发行、不冒充真人验收。
