# COMBAT-DEEPEN-01 原件补发与继续执行裁定

标识：MCT-CD-REISSUE-20260918-01  
性质：本次对话新增的收件说明、既有验收范围澄清与接续指令。不是原包中曾经存在的文件。  
原规范：MCT-COMBAT-DEEPEN-01 v1.0.0（原件保存在 `../original/`，逐字节不改）。

## 1. 收件裁定

本次补发原包全部35个载荷文件及1份原清单。原件来自会话中实际挂载的 `MCTHUNDER_战斗后端深化工作单_COMBAT_DEEPEN01_20260918.zip`，不是按记忆重写，不是从UI规范改名。

原ZIP SHA-256：`d98480389f27fd176e931c0b7e4aa779fb7948b5c64fb40474f1a3dfd78e00a4`。

原包CRC检查通过；35项载荷的字节数与SHA-256全部符合原 `PACKAGE_MANIFEST.json`。本次运行原 `validate_spec.py` 验证16个子单、96个场景（每单6个）、依赖无环、来源ID有效；没有运行Godot，不代表任何游戏检查通过。

原包在此会话可取，不代表此前已经送达执行模型。此次直接交付缺失内容，停止搜索34个分支、历史提交、Downloads、QQ目录或反复等待原文。把设计资料保存在本分支的一处目录，仅增加一个当前入口链接即可。

## 2. 你请求的内容对应哪些原件

1. 16单及依赖：`07_WORK_ORDERS.json`。
2. 16单全文：`03_ALL_WORK_ORDERS.md`；逐单原件 `work_orders/WT-CD-001.md` 至 `WT-CD-016.md`。
3. 96场景：`08_ACCEPTANCE_CASES.json`，ID为 `CD01-T01` 至 `CD16-T06`，通过 `work_order` 对应子单。
4. 接口：`04_INTERFACE_CONTRACTS.md` 与 `09_INTERFACE_CONTRACTS.json`。这些是拟议契约，不承诺现有API同名存在；允许映射原字段、扩展原类，不另起平行系统。`05_DELIVERY_AND_ACCEPTANCE.md` 是交付协议，不是第二份接口文件。
5. 规则迁移：原 `05_DELIVERY_AND_ACCEPTANCE.md` 第6节、`templates/RULE_CHANGE.template.json`，以及各子单的新旧规则要求。原包没有一份已经执行过的“迁移结果表”；不要编造。旧 `team_standard_300` 与新 `ground_rb_like_v1` 的边界见 `work_orders/WT-CD-014.md`、`CD14-T01/T06`。
6. 模板：`templates/RESULTS.template.json`、`templates/REQUIRED_CONTENT.template.json`、`templates/RULE_CHANGE.template.json`。允许沿用仓库现有DELIVERY_TEMPLATE作为报告外壳，但补齐05协议要求的身份、执行范围、错误和回退字段，不强制迁移全部旧文档。
7. 战雷来源：`11_SOURCES.md`、`11_SOURCE_REGISTER.json`，以及 `10_BENCHMARK_MATRIX_TEMPLATE.json`。原包已有R00—R11、W01—W07及H01共20条来源索引。本次额外网页核对记录见本目录 `SOURCE_RECHECK_20260918.json`。
8. 分支：继续现有 `work/combat-deepen-01` 和其合理隔离工作树，不重新从main建一遍。远端本次读取为 `2a06e70f12ac20115e2d85d1b9e183d5a4dc6822`；实际执行若有后继则保留后继。未独立检查本地工作树，不对用户本地未跟踪文件作操作。

原文件的planned/NOT_RUN只代表规范发布时状态，不覆盖你已经产生的结果。规范副本保持不变，运行结果另存；不要让规范结构校验误读执行进度。

## 3. CD001的现有结果保留，但“不成立”需要收紧

本次读取了该分支的 `COMBAT_DEEPEN01_CD001_EVIDENCE.md` 和 `tests/run_ammo_three_state_probe.gd`。原57项结果、库存守恒和受影响回归保留，不推翻已支持的结论。

原风险不是仅指“空架会殉爆/丢弹”，而是“空弹药内容是否仍参与损伤与预算消费”。你的证据表中，两车空架仍标为“打到弹架”；`lost=0`、车辆存活只证明无额外库存损失及未被此场景击毁，不证明空架命中没有消耗穿透预算。

此外，当前 `_measure()`记录的budget是首个装甲接触的before/after；damage行只保留item_id/ammo_event/destroyed，没有空架模块本次实际消费及完整前后状态。原来的假设应记为“空架无库存损失已验证；动态弹药受击与预算消费待补直接检查”，而不是直接宣称风险不存在。

| 原场景 | 现有证据可保留 | 尚需直接闭合的要求 |
|---|---|---|
| CD01-T01 | 空态确实达到；lost=0；该场景存活 | 空弹药内容无损伤/无预算消费；记录对应模块before/after、consumed_mm、弹丸进出预算和路径；独立支架/隔板另算 |
| CD01-T02 | 全车19/38与21/42消耗状态 | 逐架/逐子区占用；总携弹一半不等于目标架一半，不能只比较总数 |
| CD01-T03 | chamber+in_transfer<=1及账本守恒 | 同一发在查询几何/占用快照中只存在一处；原架不留幽灵，膛内弹可追踪 |
| CD01-T04 | 同event重复拒绝、直接事件处理守恒 | 两枚真实查询按时序先后接触；首发清空后第二发不使用旧占用。直接调用伤害入口不等于查过此路径 |
| CD01-T05 | reset与旧generation拒绝 | 正常切弹/补弹后占用重建，旧回放不写新生命；已有同范围集成证据可以引用，不无意义重复跑 |
| CD01-T06 | 库存预留token只提交一次 | 命中查询快照的occupancy/revision、缺字段和过期缓存处理。预留事务token不能直接替代毁伤查询revision |

本次不预判补查必然失败。若原日志已有足够数据，直接提取引用；没有则最小补测。生产缺陷证实后按CD001已有授权修复，未复现不制造diff。没有生产代码变动是客观结果，不是本任务必须保持的限制。

当前探针通过 `ProjectileManager.try_spawn/advance_projectile` 发射固定条件的工程弹，并使用TEST ONLY工件；它是明确的生产组件集成夹具，不是正常炮口输入/已交付模型的整车验收。保留其价值，后续正常Actor证据另行提供。`reset_vehicle()`对应重置/generation检查，不自动等于比赛生成新life_id的再出击证明。

feed_empty但仍有其他弹种：先查所选弹种及可用供弹架。其他弹种有库存不能单独证明选中弹可装。该点作为现有观察保留，不默认改自动选弹策略。

## 4. CD003边界及落点

CD003A是静态有限截面，CD003B是相对平移，CD003C是旋转部件，均属于WT-CD-003。CD03-T01—T03为静态核心，T04跨阶段检查细分/预算，T05是平移，T06是旋转。只交3A时标G1检查点，B/C未完成就不关闭整单。

3A主要落在ProjectileState/ShellDefinition的shape输入、ProjectileManager、ShotQueryService/QueryGeometry及世界遮挡的接触路径，ArmorResolver负责接触已经成立后的材料与穿透。只改ArmorResolver或impact_profile不能证明有限截面已经参与窄缝几何。

CD002先复用现有17区映射和炮盾开口工作，不为拿到原件而重做它们。先建立实际模型—板件—内构对照，再有证据地修炮孔/炮盾/关键空隙。

## 5. 对标来源与缺失数据

W01—W07用于公开机制边界；它们不提供全部车型数值、概率、误差界和未公开代码。比较时记录页面/游戏版本、模式、具体车型/弹、条件和证据。

- SOURCE_RULE：公开文本支持的规则，不冒充已跑过两款游戏。
- PROJECT_FIXTURE：本项目对冻结的工程规则或独立几何答案检查。
- WT_BEHAVIOR_COMPARISON：只有具备战雷固定版本实际对照时才使用。
- HUMAN_PLAYTEST：真人实际反馈，不由模型代签。

数值缺失或来源互相冲突时，允许按本单范围制定并冻结项目design/estimated初值，标NOT_COMPARED，原始事实字段继续unknown。不得虚构官方数据；也不因缺某个战雷精确值阻塞所有可以独立推进的几何和正确性工作。

W02正文与表格对乘员中间伤势效能仍有冲突；不把任一统一线性罚率直接认定为战雷真值。W01是2020开发说明，只支持机制动机，不是2026完整现行实现规格。官方规则核对/版本化实验与一般论坛意见分开；不把论坛帖子冒称开发者裁定。

## 6. 继续执行与停机边界

缺件阻塞在执行端实际收到并校核一次这些文件后解除。继续现有goal/分支/7个提交，保留UI线、main与用户未提交图像；不重建阶段0或重跑全部1512项来制造新进度。

接续：补闭合CD01-T01/T06及受影响场景 → 按CD002核对炮盾/关键几何 → CD003A真实静态截面 → G1内部增量候选。CD002只读测量可以与CD001补测并行；共改查询/Actor等共享文件时协调写入。

96个场景是必需覆盖清单，不是测试数量上限，原05第3节已经允许细分。可以在现有ID下补子检查/标签，不删除原场景或以自行增加的检查覆盖未经运行的要求。

权限：在工单范围内必要的生产实现、配置、测试和本地构建可以继续；不自动合并main/强推、不升级引擎、不公开发布或采购、不改用户未提交资产。性能HOLD_BY_USER，真人PENDING，release_ready/public_release均false。

下一轮交付实际命中/预算/占用对照或限定范围补丁，不再只交搜索目录/权限清单。工具确实不可用或权限缺失时，仅阻塞受影响项，不执行无限自动续跑。
