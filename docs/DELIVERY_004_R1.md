# DELIVERY 004-R1 — 装甲检视器修订（修订循环 R1）

状态：needs_revision → 已整改待复核
基线：3f079988218bb8e5ecd0067be463fb494f608ec1（004 补充提交）
分支：work/004-armor-inspector（同分支追加提交，未合并 main）
本单 tested sha：见 git log（本文件所在提交为 R1 整改提交；证据目录 docs/evidence/004-R1/<sha>/ 与之对应）

---

## 0. 玩家可见答案（先说结论）

- **能看到什么**：暂停菜单 → "Vehicle Inspector" → 检视 M4A3 (75mm wet stowage, VVSS, 1944) 历史研究布局：
  - 外观模式：低模车体/炮塔/炮管/履带 + 灰色地面（独立预览世界，不进靶场）。
  - 装甲模式：全部面片着色——厚度未知 → 灰色（不是任何默认厚度值），estimated 几何面片正常显示，选中面片橙色高亮。
  - 内构模式：发动机（后置）、变速箱（前置）、传动轴、弹药架、发电机（左舷战斗室后端）、电台、液压转向机、炮闩、油箱等内部方盒 + 外部履带盒；乘员五岗位盒（车长/炮手/装填手/驾驶员/副驾驶兼航向机枪手）。
  - 交互：部件树选中四类对象（部件/面片/模块/乘员）都有高亮与详情；炮塔 yaw 滑杆（0–360）、火炮 pitch 滑杆（-25–20，随部件关节限位同步）；"Reset Pose" / "Reset View"；相机左键拖动环绕、滚轮缩放。
- **哪些字段 verified / estimated / unknown**（详情面板逐条显示依据标题、机构、日期、PDF 页码、印刷页状态、原文核验状态）：
  - verified：总尺寸（长 20ft7in / 宽 8ft9in / 高 132⅞in / 履带中心距 83in）、乘员 5 人、后置 Ford GAA 发动机（500hp 8 缸 60°V）、变速箱前置、湿式弹药架全炮塔地板、弹药清单（104×75mm / .30 23 箱 / .50 6 箱）、辅发电机位置（左舷战斗室后端）、SCR-508/528/538 电台存在、乘员岗位/相对方位（FM 17-67）。
  - estimated：全部面片顶点（按 verified 总尺寸拟合）、炮塔回转中心位置、弹药架/电台/液压机方盒中心、乘员方盒坐标（岗位 verified ≠ 坐标 verified——见 §C2）。
  - unknown：**全部装甲面片厚度**（has_thickness=false；TM 9-759 正文无厚度表，图板目视核验未完成，详见 §C3）。
- **还不能做什么**：装甲厚度数值、铸造曲面、精确内饰布局、任何命中/穿甲/伤害判定（005+ 工作单范围）。
- **如何进入**：Esc 暂停 → "Vehicle Inspector"；Back 按钮 / Esc 返回暂停菜单（游戏保持暂停，不误恢复）。

## 1. 反例先行（GPT §2 要求：先保存可重复反例再修复）

`docs/evidence/004-R1/counterexamples.json`（采集脚本 `tests/r1_counterexamples.gd`，只读不改），修复前实测：

1. **相机**：orbit pitch -18° → 相机 y = -2.781，低于地面平面 y=-0.02（地面网格遮挡车辆）；注视点是地面原点 (0,0,0) 而非模型中心。pitch 0° 时相机 y=0 贴地。
2. **控件重叠**：模式按钮行 rect (24,166,324,32) 与 yaw 滑杆 (24,192,320,24) 相交（`modes_row_intersects_yaw_slider=true`）；yaw 标签 y=170 落在按钮行区间内。
3. **车体边界**：hull 左/右侧板 4 顶点 quad 跳过前甲折点 (-1.15, 1.0, -2.95)，每侧留下约 0.25 m² 三角形缺口（check_edge_adjacency 实测边界边列表在 JSON 中）。

## 2. 组 A：查看器可用性

- **A1 相机**：`_preview_focus = (0, 1.7, 0)`（炮塔环上方视觉中心）；俯仰限幅 -10°..80°——相机永远在地面平面上方（回归断言：pitch -18° 限幅后 camera.y > 0）；滚轮缩放 3–30 m；拖动环绕。T004-07 断言回归通过。
- **A2 布局重构**：根 HBox（左列 MarginContainer→VBoxContainer 340px：标题/Back/布局选择器/模式按钮 HBox/yaw 标签+滑杆/pitch 标签+滑杆/Reset Pose+Reset View/PartsTree expand；右列：SubViewportContainer expand + DetailsScroll 150px）。**无绝对像素定位**；新增断言"左列兄弟控件两两不重叠"（双分辨率）。inspector 挂独立 CanvasLayer（layer 20）——Control 锚点在 CanvasLayer 下才可靠（挂在 Node3D 下锚点不生效是本次实测发现，也是相机/命中问题根因之一）。
- **A3 真实事件驱动**（T004-07 重写）：模式按钮真实鼠标点击（motion hover → press/release，`Input.parse_input_event`）、yaw 滑杆真实拖拽（8 段 motion）、预览区真实滚轮——断言的是事件后实时状态（pv.mode=="armor"、滑杆值变化、_orbit_dist 增大），**不是**直接 set_mode()/参数调用。
- **A4 T004-07 取样修正**：不再比对"交互前快照"——交互完成后再推进 process/physics 帧，**重读** A/B 位置与 trial_hits/shots_fired 断言不变。
- **A5 load_layout 可靠化**：所有内部操作走 `_model` 引用；切换流程 = 校验新布局 → 旧模型 remove_child + queue_free → 建新模型存 `_model` → 同步滑杆范围（读部件关节限位，不硬编码）→ 模式重放 → 详情复位。headless 下 popup 子窗口键盘/点击路由不可达（DisplayServer 限制，已在测试注释注明）——菜单项经 `item_selected`（用户确认后 OptionButton 发出的公共信号）选择，popup 打开本身是真实点击。
- **A6 切换流程测试**：历史车 → 标准板 → 历史车：旧模型实例被释放（is_instance_valid=false）、新模型建成、切回后 set_pose(120,-10) 与 select_patch("turret_front") 高亮均可用。
- **A7 四类选中高亮**：模块/乘员新增 select_module/select_crew（实例材质覆盖，不动共享定义）；部件树选择路由 kind→对应高亮。
- **A8 详情**：显示资料标题、机构+日期（版本）、PDF 页码、章节、印刷页核验状态（NEEDS_VERIFICATION/REVIEWED）、原文核验状态、估算说明（几何拟合基准、厚度来源缺失说明）；乘员显示 role_placement vs position 拆分状态。位于 ScrollContainer 可滚动。

## 3. 组 B：校验与几何

- **B1 全局 ID 登记表**：parts/armor_patches/modules/crew_stations/layout.id 共用一张登记表——空值/重复报错，重复报告第一次出现字段路径。新增测试：模块重复、乘员重复、跨类别冲突。
- **B2 check_spatial 重写**：模块/乘员方盒 = 所属部件**沿父链组合 bind 变换** × 局部方盒（零姿态）；越界粗筛用**本布局全部面片顶点 AABB 外扩 0.1m**（不是 20m 球）；包含乘员盒；AABB 相交只作提示，区分 `DECLARED_OVERLAP`（allowed_overlaps 有配对+理由）与 `SUSPICIOUS_OVERLAP`（未声明），不断言真实机械穿插。
- **B3 侧板缺口修复**：hull_left/right 改 5 顶点多边形（含折点 (±1.15,1.0,-2.95)），3 三角形，绕向与外法线一致（`_append_polygon`）。
- **B4 开口挖孔**：hull_top 挖炮塔环开口（内环方形近似 ±0.95，环径未核验已登记 OPEN_QUESTIONS）；turret_front 挖火炮安装开口（y 0.07–0.57、x ±0.35，随板斜面）；炮塔壳底缘（坐于车体顶板环上，壳自身无底板）补第三处开口声明。
- **B5 declared_openings 结构化**：每条含 `boundary_loop`（具体边界环顶点坐标）；校验器按**坐标焊合**收集各 part 边界边（面片间不共享索引，索引级统计会把接缝误判为边界——已修复），未被任何 boundary_loop 覆盖的边界边 → ERROR；research/production 启用（test 层独立浮动测试板豁免）。M4A3 实际历史布局通过校验（此前只有标准封闭盒通过——GPT 指出的"校验历史布局"缺口闭合）。

## 4. 组 C：资料核验接口

- **C1 CrewStationDefinition 新增 `role_placement_status`**：岗位/相对方位（FM 17-67 支持）与方盒坐标（手册不支持）拆分。M4A3 五岗位 role_placement=verified、position=estimated。research 布局强制 role_placement=verified；verified 坐标要求 verified 岗位。position_status 字段保留（实际坐标状态）。
- **C2 身高测量基准**：overall.height_m 的 original_value 保留 "132 7/8 in over A.A. gun pintle stand"（AA 高机座），uncertainty_note 明确"不得用于反推炮塔顶高"。
- **C3 字段依据字典接入**：`configs/evidence/us_m4a3_75w_vvss_1944.json`（与 docs FIELD_EVIDENCE 同源）由 LayoutCatalog 加载（register_field_evidence_file / get_field_evidence）；校验器新增来源一致性检查（research 层）：evidence key 必须在字典中登记、origin 不得为 test_fixture（**EV-TEST-FIXTURE 不得背书历史 verified 字段**——反例测试覆盖）、applies_to 不适用即报错。程序只查记录一致性，不宣布史料事实正确。
- **C4 印刷页码如实标注**：EV-TM9759-SPECS printed_page_status = NEEDS_VERIFICATION（公开转录提示规格段在印刷页 9 附近，与记录"5"不一致，待原页核对）；全部 key 逐条标注 NEEDS_VERIFICATION 或 REVIEWED；不凑数、不改旧日志归属。
- **C5 原页导出**：`dev_tools/export_source_pages.py`（GPT 提供代码，入库；tools/ 引擎目录不入库故放 dev_tools/）。首批导出完成：
  - 输出：`E:\AIprogram\research-sources\tm9759_review_batch01\`（工程外资料目录）
  - 页：PDF 1, 2, 14, 15, 24, 25, 26（7 页 PNG @2.5x + manifest.json）
  - Figure 3 所在页 = **PDF 页 25**（文本层检索 "Figure 3" 图注定位，非猜测；p25 含三视图规格图）
  - manifest：source_sha256 与登记一致（78CE6B3F…A818）、导出前后源文件哈希校验通过（源文件未改动）、每页 png_sha256 + text_layer_excerpt、printed_page/figure_id 留空待人工、visual_review = NOT_REVIEWED
  - **人工事项（需你操作）**：gptc 桥为纯文本通道，7 张 PNG 请手动拖入 ChatGPT 对话供 GPT 目视核验（或告知其他通道），核验后回填 manifest 的 printed_page/figure_id 与 visual_review。
- **C6 thickness 政策不变**：所有面片 has_thickness=false、thickness_status=unknown；未完成图板目视核验前不填任何数值（T004-06/09 断言继续覆盖 UNKNOWN 呈现）。

## 5. 测试与证据

| 套件 | 项数 | 结果 | 日志 |
|---|---|---|---|
| run_layout_checks.gd（T004-01..09 + 004-R1 新增） | 105 | 0 失败 PASS | logs/004-R1/<sha>/layout_checks.log |
| run_checks.gd（003 回归） | 208 | 0 失败 PASS | logs/004-R1/<sha>/run_checks.log |

- 新增/重写断言包括：真实事件四类（点击/拖拽/滚轮/popup 打开）、切换后实时隔离取样、相机限幅反例回归、左列兄弟控件不重叠（双分辨率）、全局 ID 三类冲突、坐标焊合边界环校验、EV-TEST-FIXTURE 冒充拦截、乘员状态拆分。
- 查看器截图：docs/evidence/004-R1/<sha>/{1280x720,1920x1080}/inspect_1..6.png（--inspect-demo 真实抓帧，errors=0）。
- 已知简化（如实报告）：布局选择器菜单项经 item_selected 公共信号选择（popup 子窗口输入路由 headless 不可达）；popup 打开是真实点击。其余交互均为真实输入事件。

## 6. 未做（保持边界）

- 不新增命中查询/穿透/伤害/战斗车型（005+）；
- 不回退 003 已签收行为（208 项回归 PASS）；
- 图板目视核验 NOT_REVIEWED——待 PNG 人工附给 GPT 后进入 R2（若需）；
- 未开始 005，未合并 main，未强推。