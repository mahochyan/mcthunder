# WT-030：苏德参考数据首批接入

2026-09-12。本工作建立可重复的本地数据候选入口及独立的运行时参考包准入，尚未新增可战车辆。输入为
`E:/AIprogram/tank_data/cache` 与 `E:/AIprogram/aimodel`，全部只读；输出在统一工程内。
第一增量仅生成候选；第二增量修改 VehicleContentPipeline 并新增 ReferenceEvidenceGate、
VehicleShellCatalog，保留 HistoricalEvidenceGate 原规则。第三增量连接车库。
没有发布现代车型、替换现有模型、扩大全局可售名册或修改用户存档。

## 本批交付

- `authoring/reference_data/import_reference_data.py`：Python 3.13 标准库 CLI。
- `assets/reference_data/index.json`：苏联205、德国188，共393份TXT的准确ID、版本、hash、快照和模型关联索引。
- `assets/reference_data/source_snapshots/`：393份原始TXT字节快照，便于复核字段定位和重现。
- `assets/reference_data/model_candidates.json`：按 build_report.json 的声明ID与目录ID精确匹配；不按车型近似名或修改时间自动选版本。
- `assets/reference_data/candidates/ussr_t_80b.json`、`germ_leopard_2a4.json`：动力、主炮、弹丸、弹架、乘员、光电、分组装甲候选及缺口。
- `tests/reference_data/`：两份真实源夹具、标准库测试、生成物验证脚本与各轮真实日志。

`assets/reference_data/.gdignore` 将候选隔离于常规Godot资源扫描。首批Python工具未运行Godot；
第二增量的实际引擎检查见下文。当前 `export_presets.cfg` 已增加 `assets/reference_data/*`
排除项，仍需实际导出检查包内清单，不能由配置检查或Python测试代签发行包验收。

## 数据契约

所有JSON的 `schema` 为1。整个索引、模型记录和深度候选只使用
`admission="candidate_only"`；所有来源均保留 `origin="warthunder_reference"`、
`historical_verified=false`，深度候选 `combat_definition=null`。逐字段、模块与武器的
`runtime_admitted=false`。本格式不是 HistoricalEvidenceGate 可接纳的历史车型包。

深度候选的顶层字段为：`id/source/admission/combat_definition/historical_verified`、
`fields/raw_fields/armor_groups/crew_roster/ammo_racks/damage_module_references/weapon_references/gaps/model_candidates`。
`source` 包含准确ID、原始SHA256、资源版本、绝对源路径及工程内快照路径。
`fields` 每项包含 `key/locator/raw_value/source_unit/unit/candidate_value/resolution_state`，
同时携带来源与未准入标记；locator 保存原始行号、章节、分组，不使用渲染后的行号。

字段状态：

| resolution_state | 含义 |
|---|---|
| explicit_reference_candidate | 摘要明确给出，已按声明单位转换的候选；不是历史verified或运行准入 |
| group_inherited_candidate | 同一装甲组内明确的默认属性，保留被局部覆盖的关系；尚未解析原资源include与模式 |
| missing / unresolved_empty | 没有该字段 / 字段存在但为空；candidate_value保持null |
| conflict_duplicate_field | 同一作用域出现多个字段；不采用最后一个覆盖 |
| unresolved_unit_or_format / unresolved_nonfinite | 单位/格式或有限数值验证失败 |
| unresolved_units_and_semantics / unresolved_invalid_json | 加速度/惯量语义未定义，或内嵌结构不能解析 |
| explicit_roster_candidate / partial_reference_candidate | 明确岗位表 / 尚缺几何及部分标记的弹架候选 |

模块存在性分别标 `unresolved_generic_reference`，装甲节点标
`unresolved_requires_active_geometry`。模型连接只标 `exact_candidates_unselected` 或
`no_exact_candidate`；外部报告的PASS/WIP只放 `declared_status`，不改变准入状态。

运行准入现已使用单独的工程准入状态和来源策略，具体契约及验证边界见下文。
两份候选JSON仍保持原格式和未准入标记；不能用默认AP/APHE替换尚未实现的HEAT-FS。

## 已防止的误读

- 75km/h换算为20.833…m/s，0.125/0.12m口径换算125/120mm；发动机RPM限定总体章节，避免与各武器同名“转速”混读。
- 设计质量、空车/含油/油/履带质量分别保留；不自动相加或认作实车质量。加速度/惯量无明确单位时不生成可用数值。
- T-80B取明确三岗位表，豹2A4取四岗位表。两车通用模块均含装填手和自动装填机名称，不能据此安装能力。
- 弹架28+10=38与15+27=42可核对；20s/13s存为补弹时间，主炮射击装填时间仍为null。空白首发/致命标记保持未知。
- IR JSON与改装名称只作来源记录；没有自动赋予热像、激光测距或稳定器。dummy_weapon明确不可用于发射。
- hitPower不是穿深，弹丸stabilityThreshold不是炮塔稳定器；Cx不因导入而使当前无阻力弹道获得阻力。
- 装甲卡片与局部/复合材料值分别保存；组默认与局部覆盖分明。没有原始几何、材料预设和穿深曲线时不拼造等效厚度。
- 摘要明确省略的148个弹药模块项登记为截断缺口；2018年的游戏首发日期不作为真实改型年份。

## 实际验证

执行命令：

```powershell
python -m unittest discover -s tests/reference_data -p 'test_*.py' -v
python authoring/reference_data/import_reference_data.py
python tests/reference_data/verify_generated.py
```

最终记录在 `tests/reference_data/logs/unittest-r3.txt`、`import-r3.txt`、
`generated-verification-r3.txt`。18个unittest通过、进程退出0；393份快照hash与索引、
两份深度候选的身份/来源/字段行定位及未准入标记验证通过、退出0。重复导入测试在
隔离目录对两份真实夹具运行两遍，输出逐字节一致，源缓存及模型夹具逐字节未改变。
上述Python验证未启动Godot，没有新增真人验收。

本次真实r3导入：源错误0；101条精确模型报告候选、23份未连接报告、93个数据ID有模型候选关联；
新可战车辆0、发布模型0。模型目录仍有其他制作活动，首轮是100/22/92，后轮变为101/23/93；
每轮报告独立保留，不把可变外部输入冒充固定状态。实际最新清单以IMPORT_REPORT为准。

新增RPM结构化测试曾失败：总体RPM与武器同名转速被识别为重复字段。已将查询限定在总体章节；
失败日志 `unittest-final.txt` 保留，修订后18项通过。第一轮命令行日志中文受Windows代码页影响；
CLI已显式UTF-8，r2/r3日志可读，源快照/JSON始终按原字节/UTF-8写入。

工具hash、索引hash由 `IMPORT_REPORT.json` 绑定；尚缺的完整车型、弹族材料、镜位/光电、
自动/人工装填、实际几何与联机能力由后续WT-027/028/030/031按原路线完成。

## 运行时参考包准入：已实现的第二增量

来源内容、历史证据、工程准入、正式发布是四个不同状态：

| 层次 | 当前契约 | 能证明及不能证明的内容 |
|---|---|---|
| 原始候选 | `admission=candidate_only`、`combat_definition=null` | 能定位来源与未解决项；不能直接注册车辆 |
| 史料策略 | `evidence_profile=historical_verified`（旧包省略时默认） | 保留旧 HistoricalEvidenceGate 的必要史料/身份要求；不由参考TXT冒充 |
| 游戏参考策略 | `evidence_profile=game_reference` | 每项明确 `warthunder_reference` 或 `game_rule`，值只能 `estimated` 或 `unknown`；不允许历史 `verified` |
| 工程准入 | `admission_status=candidate/validated` | 正式注册重跑完整管线；只有全部通过才产生 validated 定义，输入JSON标记不是证明 |
| 正式名册 | `VehicleCatalog.IDS` 及正式资产/存档/研发配置 | 当前仍为四款原有车辆；候选索引或临时注册不扩大此名册 |

`scripts/content/reference_evidence_gate.gd` 要求：准确项目ID与来源车辆ID绑定；source记录
`origin/source_vehicle_id/applies_to_identity_ids/excluded_identity_ids/sha256/artifact/read_state`，
WarThunder来源另需 `resource_version`；字段记录 `value/status/origin/source_refs/location/note/unit`。
必要身份、尺寸、乘员/几何、运行参数与装甲字段不能是unknown；允许的非必要unknown必须为null。
工程单位约定是米、米/秒、米/秒²、度、度/秒、秒、千克和毫米，并逐字段检查可判定单位。

该门验证声明格式、关联及一致性，不重新读取任意外部artifact，也不认证文献事实。
SHA-256表示文件内容身份，不表示历史准确。本地快照哈希已有独立Python全量检查；
引擎专项额外复核两份实际TXT快照及夹具来源hash。将来新增参考包仍要保存可复核快照与字段定位。

`VehicleContentPipeline.validate_package` 在选择证据策略后继续执行相同的组合身份、
完整包形状、实际值与字段记录相等、装甲面/开口、内构/乘员布局、弹架容量和定义校验。
因此参考策略不是跳过布局/伤害模型的捷径。`VehicleDefinition` 分开保存
`evidence_profile/admission_status/verification`；成功参考定义仍为 `verification=estimated`。

`VehicleShellCatalog.build(packet)`／`install(actor,packet)` 是统一弹种接口。
旧历史包分发到原 HistoricalShellCatalog；参考包使用：

```text
shell_catalog = { schema_version: 1, default: <local_shell_id>, shells: [ ... ] }
shell = { id, label, gun, family, source_bullet_type, effect_policy,
          caliber_mm, muzzle_velocity_mps, penetration_curve,
          gravity_scale, max_flight_time_s,
          evidence: { identity: <claim>, ballistics: <claim>, effect: <claim> } }
```

identity/ballistics/effect的claim值必须与实际弹种字段相等。当前目录数量1..8；仅支持已经实现的
`AP/ap_tank/kinetic`、`APHE/aphe_tank/internal_burst` 组合。HEAT、APFSDS以及将来弹族必须
先实现各自规则，当前拒绝其伪装成AP。运行ID为默认弹 `<vehicle_id>_shell`，
其他弹 `<vehicle_id>_<local_shell_id>`。build返回
`ok/errors/options:Array[ShellDefinition]/default_id/entries/sources`；其结果不单独替代整车准入。

`VehicleActor.setup` 已通过统一install连接Gunner真实库存。单弹全部装载该弹种；多弹默认
主弹约70%、其他弹共享余下约30%，整数余量依目录顺序分配。Gunner既有换膛规则保持：
选择下一弹不变更膛内或搬运中的弹；发射扣弹、自然装填、再发射、重置均走真实库存账本。

## 76项实际检查证据

主任务实际执行 Godot `4.7.2.stable.official.ed1daf0bf`：

```powershell
tools/godot/Godot_v4.7.2-stable_win64_console.exe --headless --path E:/AIprogram/mcthunder -s res://tests/run_reference_admission_checks.gd
```

证据目录 `logs/WT-parallel/c193693-integrated-wip1/20260912-145437/`：

- `RESULTS.json` 中 `run_reference_admission_checks`：76项、passed=true、exit_code=0、无超时、无SCRIPT ERROR或非预期错误。
- `run_reference_admission_checks_stdout.log`：76项逐条PASS，结尾 `REFERENCE_ADMISSION_CHECKS_PASS`。
- `run_reference_admission_checks_stderr.log`：0字节。该目录import也退出0；其他专项结果应分别读取，不能由本专项通过声称整轮全绿。

检查包含：四个旧历史包不放宽；假verified/错车型/缺来源/单位错/缺几何内构/错误弹族/弹族伪装
等反例；1和3弹种完整参考夹具准入；0/9弹拒绝；两份真实TXT候选仍被拒绝；本地来源hash一致。
运行部分实际经 `VehicleCatalog.register → VehicleDefs.resolve_vehicle → Actor.setup → Gunner → ProjectileManager`：
1弹48发、3弹34/7/7；原膛首发、选择第3弹、自然6秒装填、第三弹真实发射冻结自身ID/640m/s初速/
穿深曲线、两次发射后46发守恒、车辆重置恢复。

这些是明确标为game_rule的M24几何/已有模型夹具，仅注册在测试实例中。
它们不是T-80B或豹2A4成品，也不是实车数值验收；76项尚不涵盖正常玩家第三弹按键或整个车库流程。
早期47项版本曾因typed Array赋值导致实际运行失败，已使用`.assign()`修复并由本次76项覆盖；
失败日志仍保留在 `logs/WT007-range/c193693-range-wip4/20260912-144320/`。

## 车库连接增量与剩余发布边界

76项之后完成的新改动：

- `scripts/garage/garage_service.gd` 的默认/自定义配弹统一用 VehicleShellCatalog；默认份额覆盖1..8弹。
- `vehicle_ids()`/`has_vehicle(id)`/`vehicle_label(id)` 按“正式名册中成功准入的包”供车库枚举，不扫描外部候选。
- `scripts/garage/garage_preparation.gd` 与 `scripts/core/garage_shell.gd` 共用Profile服务目录，按钮、弹量和首发选择按目录数量建立；预览不再硬取第2弹。
- 参考档案读取参考shell.evidence结构；明确显示游戏参考/工程估计，不再显示不适用的文献速度、M72史料注记或旧历史弹种字段。
- 专项新增两组真实GarageShell、Profile校验、候选拒绝、配弹保存、service.install和重置检查，扩至96项。

后续实际记录 `logs/WT-parallel/c193693-integrated-wip3/20260912-151049/`：
参考专项96项中94项通过，两项1/3弹种档案文字断言失败；旧车库专项151项通过。
档案检查随后改用 `RichTextLabel.get_parsed_text()` 读取 `append_text/add_text` 创建的实际文字，
补等待和失败文本诊断；没有放宽参考来源/无伪verified断言。修订后在
`logs/WT-parallel/c193693-integrated-wip4/20260912-151736/` 实际重跑96项全部通过、退出0。
失败日志保留，不用76项或旧车库通过代替该修订证据。

审查时发现CommandCodec仅收第1/2弹、Mailbox可能丢失选择边沿，正常输入/HUD也仅有1/2。
协议现支持0..7编号，Mailbox保留选择边沿，默认M循环弹种（可重绑），1/2快捷保留。
同目录 `run_shell_cycle_player_checks` 的41项通过，实际事件经PlayerController、Mailbox和权威Actor，
覆盖1/3/8种目录、第三弹自然装填/640m/s发射、重绑、暂停清边沿与旧设置迁移。
这是自动注入真实输入事件的工程测试，真人体验仍为NOT_RUN。

`VehicleCatalog.IDS` 在ProfileStore/Lineup/ResearchGraph中的使用目前是正式名册和经济边界，
本轮没有移除。真正加入新ID时仍要完成名册/科研节点、旧存档新增载具配弹迁移、AppFlow、
BallisticsRange、TeamRange与网络生成端的统一注册；TeamRange目前还有四车AI轮换和原型车回退分支。
这些不能通过把候选直接append到IDS解决。性能优化按用户要求仍暂停；此增量不代表后期帧率问题已关闭。

## T-80B／豹2A4完整包仍缺的最小项目

两个源ID分别是 `ussr_t_80b`、`germ_leopard_2a4`；具体缺口也保存在各candidate的`gaps`。
下列项目必须分开补数据、实现机制及验证，不用默认值冒充来源结论：

| 必需项目 | 两车现状与继续实施要求 |
|---|---|
| 组合身份和来源 | 补确切改型/年份、悬挂、炮/炮座/弹种组合，解析默认继承、模式与改装应用。2018游戏首发不能填成改型年份；关键未知仍阻止整车准入。每个采用值保留原文、行定位、单位、hash和估计理由。 |
| 正式模型和命中几何 | 外部GLB仅精确ID候选、尚未发布。必须选定并验收模型、比例、hull/turret/barrel及炮口/后坐/轮履节点，建立同位命中壳和完整内构。现管线仍依赖三层车体/8–32点炮塔模板；现代复杂形体不能只挂外观而沿用错误旧壳。 |
| 装甲分组和材料 | 将卡片、各层材料、组继承与局部覆盖映射到实际面/法线/厚度/层序；解析材料预设。不能求和当等效厚度。现代复合装甲/附加防护尚需对应WT-027机制及边界测试。 |
| 乘员与设备 | T-80B明确三岗位、豹2A4四岗位；补位置/体积/部件归属和实际发动机、传动、炮闩、横向/纵向炮驱、稳定器、光电等设备布局。通用模块表不能用于证明设备安装或增加乘员；源摘要省略148弹药项仍需补源。 |
| 弹架与装填机制 | T-80B已知28+10=38、豹2A4为15+27=42，但仍缺准确位置、容量分配/取弹顺序/空架表现与主炮射击装填。20s/13s是补弹时间，不能填reload。T-80B需真实自动装填设备与损伤规则；当前VehicleCapabilities把缺loader岗统一降速，不能给三人车虚构装填手绕过。豹2A4需人工装填与待发架补充规则。 |
| 主炮和弹族 | 摘要展开T-80B 3BK18M、豹2A4 DM12的HEAT-FS片段，125/120mm及初速候选可定位；完整弹种目录、穿深/引信/毁伤行为与兼容炮仍未完成。hitPower不是穿深；HEAT-FS/APFSDS不得套AP/APHE。必须先有对应结算实现，才可生成正式shell_catalog。 |
| 炮塔和光电 | 补真实俯仰/方位限位、转速/动态、稳定器条件、炮手/车长镜位与FOV、变倍、测距器与夜视/热像装备。IR/改装名字不能直接授予热像能力。现VCP只为M4/M24绑定专用drive/optics profile，现代包需明确接入独立配置。 |
| 驾驶和运动 | 发动机hp/RPM及质量类别只是候选；补模式一致的前后速度、加速/转向与真实项目单位，编制注明game_rule/参考出处的传动驱动配置。摘要通用75/10km/h、30度/秒值须先解决继承/模式冲突。 |
| 完整包与发行准入 | 补当前VCP所需assembly/facts/unit_contract/source_binding/geometry/runtime/armor/modules/crew/shell_catalog/license等一致结构，通过布局与Actor实际装配、换弹、损伤/维修、光电/驾驶/战斗回归，再走正式名册/模型清单/存档迁移和发布包检查。AssetManifestValidator仍是旧四车/旧贴图及1100三角面契约，需按现低模标准显式演进，不能静默跳过。 |

可继续工作的顺序是：补可核对来源与主动几何→实现缺失现代弹族/材料/装填设备→作者化完整参考包
及专用驱动/光电配置→运行时与正常车库/玩家/战斗链验收→明确发布名册与存档迁移。
当前完成的是参考入口和受约束工程接口；苏德全量内容、现代整车、空海扩展及正式发布仍按完整路线推进。
