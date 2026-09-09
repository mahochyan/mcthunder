# ART-001-R1 交付：按 REVISE_LIMITED 复审意见修正（含 finite_closeout 收尾）

- tested_git_sha: 见 `logs/ART-001-R1/`（分支 work/art-001-bake-pilot，基线 23536b5，未合并 main；
  首轮 R1=7b1b05f，收尾=closeout 提交，均登记于日志目录）
- source_blend_sha256: `FC6DAE2F4E6E6744504071E887DAF10464C6FF470720C849295D281756A7E197`（源 .blend 哈希，非源码哈希）
- 运行资产哈希以 `assets/art001/m4a3_pilot/manifest.json` 为准（glb/basecolor/normal/orm 四项）

## 收尾轮（finite_closeout）关闭项

1. **漏件修复**：`PART_MESHES["barrel"]` 的 `LOW_gun_Shell` 实为 `LOW_barrel_Shell`——首轮绑定
   766 tri 即漏此 8 tri 炮盾。名单修正 + 绑定验证改为**精确集合**（部件下实际网格集合必须与
   名单完全一致，少件/错件/多件都在动原车前拒绝）；导入集合与导出清单逐名核对（8/8）；
   候选三角数=**774 完整**。漏件反例测试：注入缺件名单 → 拒绝且节点数不变。
2. **候选炮管接后坐**：炮管候选容器接给 `turret.recoil_visual`（TurretRig 只写 Z 位移），
   kick 后实测容器 z=0.20m；还原时接回旧引用。炮盾/炮耳/炮口未改作后坐视觉。
   动态履带：绑定期间 `set_process(false)` 停专用更新，还原恢复（未实现烘焙履带滚动动画，
   **登记为静态视觉限制**）。
3. **整车审计**：`candidate_tri_count`（候选容器口径，更名）+
   `audit_no_leftover`（actor 递归检查旧外皮/外饰/履带/程序炮管/旧后坐炮身无可见残留）——
   绑定态残留=0，不存在两套外观叠加。
4. **八车摆位**：统一 i=0..7 格位（无重合），相机按车阵包围盒取景，
   `is_position_in_frustum` 校验 8/8 入镜（不通过则非零退出）；场景清点改名
   `scene_mesh_nodes=64 / scene_tris=6192`；绘制统计改用引擎监视器
   `Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME`（avg=65）。
5. **成本结论口径**：B/C 交错两轮（关 vsync）：B avg 0.60/0.59ms，C avg 0.59/0.58ms——
   **方向不稳定，未测出稳定差异**；报告为该场景整体帧时间对比，不认证具体 GPU 成本百分比；
   GPU 时间戳 NOT_CAPTURED。
6. **烘焙口径纠正**：`max_ray_distance` 是高低模经笼的投射线距离（非 AO 遮挡半径），
   0.25m 远大于笼偏移 0.02–0.03m，注释已纠正；AO 隔离有效性来自正确的烘焙对象集合
   （`set_group_visible` 现隐藏全场景其它对象，含源 .blend 遗留几何与其它 CAGE）。
   原"组均值"更名 `atlas_mean_after_group`（整图集逐步填充均值，不推断局部组）。
   贴图未无条件重烘。
7. **资源包隔离实跑**：`tests/art001_pack_load.gd` 复制到只含 `project.godot + assets/` 的
   临时目录实机运行（无主场景/无 authoring），材质显式启用 AO、粗糙/金属倍率 1.0 → PASS。

## 首轮 R1 已确认保留的修正

- A：容器归属/先验证后改动/精确导入/还原真实断言/绑定还原×10 稳定/自然装填/命令驾驶。
- B：SRC 材质隔离、DIFFUSE 仅 Color、Emission 逐遍配对安装恢复。
- C：variant 单一状态源、T/G 档位循环、frame_post_draw 截图。

## 检查与回归（closeout 版）

- `run_art001_checks.gd`：**57 项 0 失败**（新增漏件反例、精确集合、残留审计、后坐接线）。
- 游戏回归 `run_checks.gd`：**216 项 0 失败**。
- 真人审美签收 PENDING_USER；PNG 未 REVIEW。

## B/C 暂定策略

保留 B 为默认、C 作为待验证选项——**暂定策略，非已验证的成本/收益结论**；本场景整体
帧时间对比未测出稳定差异（B/C 均 ~0.59ms/8 车，引擎 draw calls 65）。

## A 组：视觉适配器真正可回退

- **节点归属**：所有新增网格挂入 `_spawned_roots` 候选容器（`BakedPilotVisual_hull/turret/barrel`），
  `mesh_instances()` 遍历全部容器，`restore()` 移除全部容器——空容器无法清理他人子节点的问题消除。
- **顺序**：先验证资源与部件覆盖，再保存旧视觉状态；重复绑定检查先于任何状态清空；
  加载失败不隐藏旧模型。
- **按清单导入**：`PART_MESHES` 白名单逐叶网格导入，不再深复制炮塔子树（消除重复装配路径）。
- **完整替换**：隐藏/替换对象 = `Skin_*` + `Cosmetic*` + `M4TrackMotion`（动态履带）+
  `RecoilVisual`（后坐炮身）+ 程序 `barrel_mesh`；炮口闪光等游戏节点不动。
- **真实还原检查**（替换原无条件 PASS）：还原后容器数=0、烘焙网格清空、旧 Skin_ 恢复显示、
  节点数回到基准；**绑定/还原 ×10 节点数稳定**；绑定态重复绑定被拒绝且不影响还原清单。
- **姿态下对齐**：`audit_alignment` 按部件限定补丁并施加真实姿态（转炮 90° + 俯仰 10°），
  世界系比较烘焙壳面顶点与布局角点：**worst = 0.084mm**（checked=184，容差 10mm）。
- **完整实例统计**：绑定后整车可见三角 **766 ≤ 1000**（逐面统计，非推断）。
- 自然装填流程（不清冷却）：首射 → 冷却自然生效 → 物理帧等待自然装填 → 再次开火成功
  （真实 reload=6.5s 档）；真实驾驶经 `submit_command` 命令入口（与控制者同路径），
  绑定视觉下加速至 5.5 m/s。

## B 组：烘焙源/目标隔离与运动部件 AO

- **源/目标材质隔离**：高模统一改用私有材质副本（`ART001_SRC_*`），目标图像节点不再可能
  进入源着色读取路径。
- **通道配对**：临时 Emission 输出（R=rough/G=metal）只在 orm_mask 遍安装、立即恢复
  （`install_emis`/`restore_emis` 成对，调用侧 try/finally）；albedo 遍改用
  `DIFFUSE + pass_filter={COLOR}`（只烘颜色，不依赖跨通道临时输出）；normal/AO 遍为几何量，
  不装着色器旁路。
- **运动部件 AO 隔离**：每遍 AO 只保留目标组的源（其它组=零姿态炮塔/火炮不参与遮挡），
  `max_ray_distance=0.25m` 限局部遮挡；组均值 hull 0.889 / turret 0.863 / gun 0.850 /
  wheels 0.831 / tracks 0.685（履带自遮挡最重，符合预期）。
- **256 小样先行验证**：法线切线分量双向分布（+347/−200 px）、AO 接触压暗存在
  （min 0.000 / max 1.000）→ 通过后才整车重烘。
- **已知颜色验证**：1024 albedo 按 sRGB 缓冲比较（图像色彩空间实验确认：sRGB 标签下
  缓冲为编码值），橄榄 162111 px / 钢 871 px / 橡胶 38849 px 全部命中（容差 0.045）。
- 失败路径：缺 UV/缺源组/烘焙失败/保存失败均抛错退出非零。

## C 组：可操作的对照与受控成本采样

- **变体单一状态源**：`variant` 变量被命令行与按键共用；切灯/转炮/改距离不再重设材质
  （修复 `--variant B` 被覆盖回 C 的问题）；T/G 改为档位循环（0°→90°→180°、0°→+10°→−5°），
  从 0° 起每按一次前进一档。
- **截图**：等待 `RenderingServer.frame_post_draw` 后抓帧；保存失败退出码非零；
  日志记录 variant/相机距离/FOV。
- **性能（首轮记录，已被收尾轮取代）**：当时 9 实例重合摆位、节点清点口径——数据保留于
  `r1_perf.txt` 作版本归属，不作为成本结论。

## 口径修正（首轮 → 收尾轮）

1. 对齐 worst = **0.084mm**（前稿 0.0084mm 少一位小数）。
2. UV 排岛：只说"提高有效利用率，之后评估降低分辨率"，不承诺显存节省比例。
3. `FC6DAE2F…` 是源 .blend 哈希（manifest 记为 `source_blend_sha256`）；按 tested_git_sha
   分目录登记日志（`logs/ART-001-R1/7b1b05f/` 与 closeout 目录）。
4. 资源包独立加载：首轮为脚本存在性证明；收尾轮在**隔离临时目录实机运行**（见上）。
5. `max_ray_distance` 语义、`atlas_mean_after_group` 口径、引擎绘制统计——见收尾轮 5/6/7 条。

## 检查与回归（历史版本，收尾轮见顶部）

- 首轮 `run_art001_checks.gd`：53 项 0 失败；游戏回归 216 项 0 失败。
- 真人审美签收仍 PENDING_USER；PNG 未 REVIEW。

## B/C 取舍（与复审口径一致）

现有条件下**未测出稳定差异**（收尾轮整体帧时间对比）；结论为：
**管线可用；当前观看距离下默认采用 B；C 暂无足够收益**——是否保留 C 由近景镜头
（车库/击杀检视）需求决定。