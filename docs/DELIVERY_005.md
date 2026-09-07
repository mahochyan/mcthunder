# DELIVERY 005 — 统一命中查询与多层交点排序

状态：待复核（提交后由 GPT 裁决签收）
基准：84c8b8d9d6e3add45840499442087ce9284af8c4c（004 accepted_sha）
分支：work/005-shot-query（追加提交，未合并 main，无 force-push）
本单 tested sha：见 git log（本单提交；证据目录 docs/evidence/005/<sha>/ 与日志 logs/005/<sha>/ 与之对应）

---

## 0. 反例先行（先用当前实现跑反例，再修复）

反例全部进 `tests/run_query_checks.gd`（58 项，`QUERY_CHECKS_PASS`），修复前/后对照：

1. **开口边按 part 隔离（005-a）**：两个部件用完全相同的局部坐标（同一面片形状），只给 part a 声明开口——修复前 part b 的边界边被 part a 的开口豁免（errors=0，漏检）；修复后报错（未声明边不再跨部件豁免）。两部件都声明 → 通过。
2. **严格身份匹配（005-a）**：research 布局 + evidence key 只有自由文本描述（"M4A3 (75mm wet stowage)"）没有任何机器身份列表——修复前文本回退放行；修复后拒绝（无文本回退）。
3. **字段路径精确优先（005-a）**：同字段同时存在通配 `armor_patches.*.thickness_mm` 与精确 `armor_patches.hull_front_upper.thickness_mm` → 精确优先、无冲突；两条同程度通配记录（verified vs estimated）→ 冲突报错。
4. **R1-B 前提时序竞态（003 回归加固）**：`Input.action_press("fire")` 后用 2× `await process_frame` 等待消费——headless 下 process 帧率高于 60Hz 物理步，2 帧窗口内可能恰好没有物理 tick（R1-B 前提 shots 不 +1，实测偶发失败）；005 的 try_fire 在物理步内新增几何查询改变了物理步耗时/相位，使该潜伏竞态暴露。修复：等待窗口改为与 R2-B 前提一致的 2× `await physics_frame`（同一文件内既有确定性模式；断言不变）。修复后 run_checks 连续 3 次全 208 项通过。
5. **射手自身几何（005-d 语义）**：面板 ALL 过滤时探针从 A 自己前板出发 → 服务如实报告 A 的 at_start 交点（distance=0）；**排除射手是开火路径（gunner excluded_instances）的责任，服务本身只做几何汇总**——面板显示原样候选，由展示层标记。

## 1. 005-a：布局校验身份隔离与严格匹配

- **`layout_validator.gd`**：
  - `check_declared_openings` 拆分为 `declared_edges_by_part[part_id][edge_key]`（生成与读取都按 part_id，边界匹配也按 part）；
  - `check_evidence_consistency` 传具体字段路径（`armor_patches.<id>.thickness_mm`、`crew_stations.<id>.role_placement` 等），不再把整段路径当自由文本；
  - `validate_field_claim` 收集全部 `_field_path_matches` 记录：按通配符数量分层，精确 > 通配；同程度冲突 → 错误；`_identity_applies` 在无任何机器 id 列表时返回 false（自由文本不回退）。
- **fixture**：`configs/layouts/test_query_vehicle.tres`（content_tier=test；hull/turret/barrel 三部件 + 6 车体板 + turret_front + engine/barrel_box 模块；手算基准确认）。

## 2. 005-b：纯几何查询内核与服务（手算案例全过）

- **`scripts/query/query_geometry.gd`**（class_name QueryGeometry，纯函数 RefCounted，不访问场景树）：`segment_triangle`（退化/平行/共面未决显式处理 + at_start/at_end/on_edge/front_face）、`segment_box_local`（进入/退出边界、t=0/1 覆盖、starts_inside、grazing 触边退化）。
- **`scripts/query/query_snapshot_builder.gd`**：`build_from_vehicle`（只读 global_transform，不持 Node 引用，部件变换只乘一次）+ `build_identity_snapshot`（纯数据）。
- **`scripts/query/shot_query_service.gd`**：汇总（面片按 AABB 粗筛 + 逐三角形；模块/乘员盒 → volume_intervals + enter/exit/touch 事件）、去重（仅同 face 重复三角形交点；不同车辆/不同 surface_id/模块进出点不合并）、排序（真实距离 → 稳定身份键）、诊断（coplanar_unresolved/degenerate/too_many_entities）、≤8 实体硬上限、零长/非有限输入明确失败。**不调用 register_hit/accept_hit/冷却/弹药/任务**。
- **手算基准（GPT 7.x，逐项断言）**：from=(0,1,-5)→(0,1,5) → hull_front 5m / engine enter 6m / engine exit 7m / hull_rear 8m（法线 +z）；旁板 y=2 不命中；墙 world_stop=2m 时墙后候选保留；无墙前板仍 5m；yaw90 前板 5m 法线 +x；turret 90°/barrel pitch 10° 姿态跟随；起点盒内无假 enter + interval t=0；整段盒内无边界事件；起/终点恰在表面边界上报；同面片共享对角线去重为 1；不同面片分开；共面诊断；A 排除 B 命中；快照变换固定；9 实体明确失败。

## 3. 005-c：生产路径接线（不是只在测试里用）

- **`scripts/query/world_query_adapter.gd`**：`query_world_stop`（LAYER_WORLD 专用，物理阶段；绝不把车辆粗碰撞当装甲）。
- **`scripts/gunner.gd` try_fire 重写**：炮根→炮口遮挡保留（_ray）→ 冻结发射身份 → world_stop（世界遮挡）→ `ShotQueryService.query`（excluded=[自我]，include_modules=true, include_crew=false）→ 首个 armor/module/crew 事件在墙前 → `_find_vehicle`（递归整树按 entity+life）→ `register_hit`；墙前无车辆事件 → world_collider 有 register_hit 则打靶板反馈（{})；查询失败保守 miss。`last_query_events` 只读曝光。
- **`scripts/main.gd`**：`query_snapshots()`（遍历全部 VehicleActor，有 layout_id 的建当前姿态快照）+ `snapshot_provider` 注入（A/B 及 spawn_vehicle 新实体）；`player_tank_vehicle.tres` 加 `layout_id`。
- **回归**：run_checks 208 全过（含 T003-03/06/09 真实命中、T002 炮口遮挡、R1-B 暂停宽限、R2-B 暂停/恢复、003-R2 自然装填闭环）。

## 4. 005-d：QueryDebugPanel——GEOMETRY ONLY 调试面板

- **`scripts/inspection/query_debug_panel.gd`**（F6 开关，main 接线 `open_query_debug/close_query_debug`；打开时 `controller.commands_enabled=false` 防误触开火/驾驶/瞄准，关闭恢复；不暂停）：
  - 车辆过滤（ALL/A/B/…新生实体）、探针预设（炮管轴线/相机视线/A→B 中心/自定义 from-to）、模块/乘员开关；
  - **测试墙 = 显式几何方盒**（pos/size/yaw 手填；同时挂 LAYER_WORLD 物理体对齐真射路径；面板墙交点由 QueryGeometry 计算，不访问物理射线）——先于 B 的交点演示"墙前/墙后"遮挡标记（`<wall` / `WALL` / `>wall`）；
  - 结果列表（序号/距离/事件类型/实体/部件/物件/厚度）+ 选中行详情（点/法线/at_start/at_end/on_edge/thickness_status/material）+ 世界编号标记（点击高亮）+ 探针线段绘制；
  - 姿态变化（如炮塔收敛/外部移动）→ 旧结果标 STALE 变灰（不伪造"当前姿态"）；旧运行标记保留变灰；Clear 全清；
  - 明确 "GEOMETRY ONLY" 文案：不结算穿透/伤害、不消耗弹药/任务、不触碰 Gunner；
  - **演示实测（-- --query-demo，真实 F6 + 真实鼠标点击按钮）**：自然收敛 212 帧 → F6 开面板 → Run Query（炮管探针：2 事件，首交点 6.49m 为 B hull_left）→ 加墙（墙入 5.09m < 装甲首点 6.56m）→ Clear → 移墙 → Esc 关面板；shots=0 trial=0 全程未变；6 张 1280×720 真帧截图（docs/evidence/005/<sha>/1280x720/）。

## 5. 测试证据（全部真实运行，无虚构）

| 套件 | 命令 | 结果 |
|---|---|---|
| run_checks（003/002 回归 208 项） | `godot --headless --path <root> -s res://tests/run_checks.gd` | 208 通过 ×3 连跑（R1-B 时序加固后） |
| run_layout_checks（004 回归 123 项） | `godot --headless --path <root> -s res://tests/run_layout_checks.gd` | 123 通过 |
| run_query_checks（005：58 项） | `godot --headless --path <root> -s res://tests/run_query_checks.gd` | 58 通过 |
| --query-demo 截图 | `godot --path <root> --resolution 1280x720 -- --query-demo --shot-dir docs/evidence/005/<sha>/1280x720` | 6 张 + 0 错误 |
| 日志 | logs/005/<sha>/（run_checks / run_layout_checks / run_query_checks / query_demo 全量输出 + 命令） | — |
| 截图 | docs/evidence/005/<sha>/1280x720/query_debug_1..6.png | 像素抽样非空、尺寸 1280×720 |

## 6. 未做 / 保留（如实声明）

- 历史装甲厚度仍 UNKNOWN（图板目视核验未完成，保持 004 保留项）；史料原页 7 张 PNG 转送仍 BLOCKED_TRANSFER（待人工上传）；真人体验验收最迟 011 前。
- 面板不实现穿透/伤害/任务结算（工作单 006 起的功能不做）；调试面板为纯几何工具。
- 未运行：任何人工试玩（NOT_RUN，属人工验收项）。
