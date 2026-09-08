# REVIEW_005_ACCEPTANCE — 005 阶段签收记录

- 复审人：GPT（源码与执行端证据复审；未在本环境运行 Godot/PowerShell，未目视 PNG）
- 签收时间：本轮（GPT 正文决定，直接作为签收依据，不依赖附件）
- 结论：**status = accepted**
- acceptance_scope = unified_query_engineering_baseline_with_carryover（统一查询工程基线、带明确保留项）
- accepted_sha = `3aa26da0e87d6d7c1e12dce3bc6d311c2bd6b4e1`
- tested_code_sha = `fde3924aaaba30ed4ef5a3c6498854c8b6fde4be`
- evidence_commit = `b7d6d56c0c80f775d3bc687b0cb50c8064b80d5e`
- review_method = source_and_submitted_execution_evidence
- user_acceptance = **NOT_RUN**（不代签，人工项延期，最迟 011 核心体验里程碑前完成对应检查）

## 签收范围

统一几何查询、世界遮挡、查询时点与排序等工程能力（005 统一命中查询与多层交点排序，
含 005-R1 修订循环与 005-R1 有限收尾 A/B/C：世界接触边界处理、查询快照采样时点、统一排序）。
不是历史装甲数据、最终 UI 品质或真人试玩签收；人工未做的项目继续保留，不改成 PASS。
005-R1 技术收尾关闭，不新增修订轮；不重开 002/003/004；main 不合并，006 不自动开始。

## GPT 复审确认的关闭项（005-R1 收尾 A/B/C）

1. **A 世界接触边界与错误传播**：WorldQueryAdapter 启用 hit_from_inside、归一化方向、按实际距离
   计算 t、零法线标 normal_known=false；Gunner 炮根—炮口遮挡查询同启用。face_index=-1 合法透传
   （仅 ConcavePolygonShape3D 保证有效面索引，其他形状 -1 合法，不因负数拒绝命中）。
   旧距离字段有效输入重建为有限接触坐标；部件变换用 LayoutMath.is_rigid() 检查，失败经不完整
   结果向上传递；不可逆变换、无效模块尺寸等反例已入测试。
2. **B 查询快照采样时点**：提交只保存线段/筛选/开关；车辆快照与世界接触在同一次物理执行中采集；
   完成时用实际参与查询的快照签名，不重新采样姿态。测试覆盖"提交后、执行前移动 B"、
   "提交后切换筛选框不改已提交请求"、"炮塔单独旋转后标记 STALE"。
3. **C 统一严格排序**：服务生成权威 ordered_contacts（真实距离 + 确定性身份排序）；
   面板 _merged_from_result() 直接读取，展示路径不再保留原容差比较器。测试含近距离事件六种排列、
   完全同距确定性、世界接触插入、选择器墙优先规则；原始距离顺序与接触选择政策分开。

## 原始证据与报告的对应结果（GPT 读取仓库原始日志确认）

| 套件 | 原始日志结果 |
|---|---|
| run_query_checks | 140 项，0 失败，QUERY_CHECKS_PASS |
| run_checks | 213 项，0 失败，CHECKS_PASS |
| run_layout_checks | 123 项，0 失败，LAYOUT_CHECKS_PASS |

两分辨率 query-demo 日志：各 6 张截图保存、errors=0；世界接触约 5.09m 先于装甲候选约 6.57m；
调试期间 shots=0、trial=0；关闭面板后 commands_enabled=true。

## 证据边界（如实保留，不阻塞签收）

- **退出码未留存**：本轮运行器未取得进程 ExitCode（异步退出框架特征），记录为"日志结果通过"，
  不写成已核实 exit=0；后续运行器保存真实退出码即可，不补造旧值。
- **不是零警告**：查询 stderr 仍有 barrel_box 超出装甲包围盒的粗筛 WARNING；保留该记录，
  本阶段不因此引入车外模块损伤系统。
- **截图已归档、未代签目视**：两分辨率目录各 6 个 PNG 文件对象确认存在；图片解码渲染与目视检查
  未完成，不判"面板文字清楚/世界行无遮挡/两分辨率布局可读"通过；并入后续实际版本人工验收，
  最迟 011 核心体验验收前完成。

## 签收版本对照（GPT 比较过 Git 树，对象一致）

| 用途 | SHA |
|---|---|
| 被测源码 | `fde3924aaaba30ed4ef5a3c6498854c8b6fde4be` |
| 证据提交 | `b7d6d56c0c80f775d3bc687b0cb50c8064b80d5e` |
| 签收交付 HEAD | `3aa26da0e87d6d7c1e12dce3bc6d311c2bd6b4e1` |

远程 work/005-shot-query 指向交付；交付位于源码提交之后，之间为证据与文档提交；
scripts/、tests/、configs/、scenes/、project.godot 树对象一致（运行内容未变）。
main 仍在 29376e2…；本轮只读取仓库，未修改分支或文件。

## 保留项（carryover，不代签）

| 项目 | 状态与处理 |
|---|---|
| 历史装甲厚度 | UNKNOWN_RESEARCH_INCOMPLETE（继续 UNKNOWN，不升级为已核实） |
| 七张史料原页人工转送 | BLOCKED_TRANSFER（不能以路径或清单代替原页） |
| 真人体验验收 | NOT_RUN，维持"最迟 011"安排，本次不代签 |
| 面板 B 筛选下模块行仍显示 | 按调试候选语义保留，不擅自判为缺陷 |
| 截图目视（面板可读性/世界行/两分辨率布局） | NOT_REVIEWED，并入 011 前人工验收 |

## 下一步

- recommended_next_order = **006**（仅登记；006_IMPLEMENTATION_AUTHORIZED = false，不自动执行旧 WO006）
- 不合并 main、不强推、不重写历史；005 工程目标已签收，可作为后续炮弹飞行系统的查询基础。
