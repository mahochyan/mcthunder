# DELIVERY 004-R2 — 相机边界与校验规则收尾（修订循环 R2）

状态：needs_revision → 已整改待复核
基准：db307227ddc0f7583a6476d59cd265273b4bad63（004-R1 交付 HEAD）
分支：work/004-armor-inspector（同分支追加提交，未合并 main）
本单 tested sha：见 git log（R2 整改提交；证据目录 docs/evidence/004-R2/<sha>/ 与之对应）

---

## 0. 反例先行（GPT §345：先用当前实现运行对应反例，再修复）

`docs/evidence/004-R2/counterexamples.json`（采集脚本 `tests/r2_counterexamples.gd`，只读不改），修复前实测：

1. **相机钻地（组A）**：当前固定 -10° 俯仰下限只在近距离安全——相机高度 = 1.7 + dist·sin(pitch)：
   - 3m/-10° → y=1.179 ✓；9m/-10° → y=0.137 贴地；**30m/-10° → y=-3.509 低于地面**（min_camera_y=0.13）。
2. **开口对角线豁免（组B）**：边界边 BD（环 A→B→C→D→A 的对角线）因 B、D 都在环顶点集合而被豁免（修复前 errors=0）；重复同向三角形（边计数 f+r=3）同样被豁免（errors=0）。
3. **空间包含（组B）**：模块盒 (-0.05..0.45) 与车辆 bbox (0..10) 相交但大部分在外——当前 `_inside_bounds` 判"在界内"（true）。
4. **来源绑定（组C）**：错误车型来源（applies_to 属于 M4A2）挂到 M4A3 不被拒绝（errors=0）；岗位依据（FM 17-67 crew）被拿去证明装甲厚度不被拒绝（errors=0）。

修复后同脚本重跑（记录在 JSON 的修复后字段）：diag_errors=3（BD/BE/DE 三条边界边报错）、dup_errors=3（三条非流形边报错）、bounds=False、wrong_vehicle_errors=1、crew_for_thickness_errors=1。

## 1. 组 A：相机俯仰/距离联合约束与模型观察中心

- **PreviewCameraMath**（`scripts/inspection/preview_camera_math.gd`，class_name，纯计算 RefCounted）：`solve_orbit(focus, yaw_deg, requested_pitch_deg, requested_distance, min_camera_y)`——距离 clamp 3..30m；俯仰上限 80°；**俯仰下限动态计算**：`floor_pitch = asin((min_camera_y - focus.y)/distance)`，与绝对下限 -75° 取大；即使抬到 80° 仍低于安全高度时返回 `{ok:false, error:"no feasible above-ground orbit"}`；非有限输入逐项拒绝。三角函数入口统一转弧度，asin 输入 clamp 到 [-1,1]。
- **接入生产路径**（不是只在新测试里用）：`_update_camera()` 唯一入口调用 solve_orbit，min_camera_y = -0.02 + 0.15 = 0.13；成功后**同步实际使用的 _orbit_pitch/_orbit_dist/相机位置**，沿用 look_at/未入树手动朝向处理。拖动、滚轮缩放、恢复视图、切换模型全部经 `_update_camera()`——滚轮回调里没有另写高度修正。
- **_preview_focus 动态化**：不再固定 (0,1.7,0)。`VehiclePreviewModel.get_visual_center()` 遍历当前预览几何（面片+模块+乘员 MeshInstance3D 的 AABB 角点经 global_transform 变换）求包围盒中心；地面/灯光不是模型子节点，天然排除。`load_layout` 建好新模型后更新 `_preview_focus`——切到标准板不再盯着谢尔曼炮塔环上方。
- **通过条件实测**：
  - solve_orbit 纯函数：距离 3/9/30 × 俯仰 -30/0/18 共 9 组，相机 y 全部 ≥ 0.13（断言 T004-R2）；
  - 30m/-10° → 实际俯仰被抬到 -3.0°（y=0.13）✓；
  - focus 过低（y=-5, dist=3）→ ok=false 明确报告不可行 ✓；
  - **真实滚轮缩远 6 次**（InputEventMouseButton WHEEL_DOWN 到预览容器中心）→ 相机 y=5.04 ≥ 0.13（T004-R2 断言 + inspect_7_zoomed_out.png 截图证据）；
  - 恢复视图（Reset View）后 y ≥ 0.13 ✓；切换布局（历史→标准板）后 y ≥ 0.13 且 `_preview_focus` 跟随新模型（断言）✓。

## 2. 组 B：开口相邻边、边计数分类与空间包含语义

- **check_declared_openings 重写**（`layout_validator.gd`）：
  1. **入口短路**：面片索引越界/非 3 倍数/几何校验失败（ArmorPatchMesh.validate_geometry）→ 记录字段错误并 return，不进入依赖有效索引的边界遍历（反例：tris [0,1,9] → 字段错误不崩溃）。
  2. **边分类**（坐标焊合，每 part）：f==1 and r==1 → 正常内部边；**f+r != 1 → 重复面/绕向/非流形 ERROR，不可由开口声明豁免**；f+r == 1 → 真边界边，必须匹配 declared_edges。
  3. **declared_edges 只由 boundary_loop 相邻顶点对生成**（loop[i]-loop[i+1]、loop[last]-loop[0]），不生成环内两两组合——对角线 AC/BD 不再被豁免。
  4. **声明有效性**：part 必须存在、≥3 有效顶点、连续边非零（零长边报错）、声明边必须确实对应模型边界（该 part 边界边集合中至少一条匹配，否则 warning）。
- **反例断言**（T004-R2）：合法开口环通过（0 errors）；对角线边界边报错；重复三角形报错；非法索引字段错误不崩溃。
- **_inside_bounds 改包含语义**：方盒必须整体在车辆范围 AABB 内（mn≥bmin and mx≤bmax，外扩 0.1m 由 _vehicle_bounds 统一加）才算"在界内"；相交只用于可疑重叠提示；不包含 → 越界 WARNING。反例：大部分在外盒 → false ✓。
- **allowed_overlaps 声明有效性**：缺 a/b、空 reason、引用不存在的对象 id → WARNING（不进入已声明集合）。

## 3. 组 C：来源身份/字段/状态绑定与加载失败保留旧模型

- **JSON 依据条目**（`configs/evidence/us_m4a3_75w_vvss_1944.json`）：每条 evidence key 新增机器可检查的 `applies_to_identity_ids` / `excluded_identity_ids`（applies_to 文本保留用于显示）；EV-TEST-FIXTURE 显式 excluded 全部历史身份。
- **字段路径统一**：`crew_stations.*.role_placement`（岗位/相对方位）、`crew_stations.*.local_box_transform`（坐标）、`crew_stations.*.size_m`（体积）、`armor_patches.*.thickness_mm`（厚度）——旧路径（position/box）已迁移。
- **validate_field_claim(identity_id, field_path, declared_status, field_record, referenced_sources)** 固定顺序：字段记录存在并覆盖（`*` 只匹配一个路径段）→ 状态一致 → source_refs 可解析（登记存在）→ 身份适用（包含+排除）→ **历史 verified 不能由 game_rule/test_fixture/warthunder_reference 背书**。
- **接入**：check_evidence_consistency 对每个 patch（thickness_status≠unknown → thickness_mm 字段）、每个 crew（role_placement/position/volume 三字段）调 validate_field_claim；对象自身 evidence_keys 也逐条查身份适用。
- **登记缺失**：research/production 布局无字段依据文件 → validate 报 "field evidence registry missing" 数据错误 → LayoutCatalog.load_layout 返回 null（不加载）；test 布局允许无来源文件（断言覆盖）。load_layout 对不存在的 evidence 文件不再 push_error（test 布局静默）。
- **load_layout 接实"先校验失败保留旧模型"**：inspector.load_layout 移除占位 pass——在移除旧模型前调用 LayoutValidator.validate（统一走 LayoutCatalog 已验证加载结果；直接传入的布局也过同一校验入口），校验失败返回 false 且 `_model` 不变（断言：坏布局被拒 + 旧模型保留）。

## 4. 测试与证据

| 套件 | 项数 | 结果 | 日志 |
|---|---|---|---|
| run_layout_checks.gd（T004-01..09 + R1 + R2 新增 18 项） | 123 | 0 失败 PASS | logs/004-R2/<sha>/layout_checks.log |
| run_checks.gd（003 回归） | 208 | 0 失败 PASS | logs/004-R2/<sha>/run_checks.log |

- R2 新增断言（18 项）：solve_orbit 9 组纯函数、30m 俯仰抬升、不可行轨道、真实滚轮缩远后相机高度、恢复视图后高度、切换布局后 focus 跟随+高度、load_layout 拒绝坏布局保留旧模型、开口合法/对角线/重复三角形/非法索引、_inside_bounds 包含、错误车型拒绝、岗位冒充厚度拒绝、登记缺失数据错误、test 布局豁免。
- 截图：docs/evidence/004-R2/<sha>/{1280x720,1920x1080}/inspect_1..7.png（--inspect-demo 真实抓帧；**inspect_7_zoomed_out.png 为 R2 新增**——真实滚轮缩远 6 次后相机 y=5.04，errors=0）。
- 反例：docs/evidence/004-R2/counterexamples.json（修复前/后同脚本记录）。

## 5. 史料转存/目视状态

- **BLOCKED_TRANSFER**：7 张 TM 9-759 原页 PNG（E:\AIprogram\research-sources\tm9759_review_batch01\，PDF 页 1,2,14,15,24,25,26 含 Figure 3 页）已导出并带 manifest（source_sha256 与登记一致、png_sha256、text_layer_excerpt、visual_review=NOT_REVIEWED），但 gptc 桥为纯文本通道无法送达——需人工拖入 ChatGPT 对话供目视核验。**不阻塞本单工程放行**（GPT 明确：不因缺少史料图片拒绝工程放行）。
- 未核验厚度保持 UNKNOWN；不编造来源、页码、图号或人工意见。

## 6. 未做（保持边界）

- 不新增命中查询/穿透/伤害/战斗车型（005+）；不回退 003（208 项回归 PASS）；未开始 005；未合并 main；不强推。
- 保留 004-R1 有效改动：容器布局、真实输入测试、_model 切换、全局 ID 登记、完整父链变换、岗位与坐标状态拆分。