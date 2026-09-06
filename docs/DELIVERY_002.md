# 交付记录 — 工作单 002（001 补验收、缺陷修整与基线冻结）

## 0. 现场（§2.1，执行时实测）
- 分支：`work/002-baseline`（自 `main` 切出；main 未被本单修改，未强推）
- 被测 SHA：`53851229727ecd363c19a189de9d51f08a0ea44c`（与 QA_BASELINE_002 绑定）
- 基线参考：计划引用 `main@29376e20e5675bd15747ac4bfd6b24382d6c3b15`，实测与之一致，无差异
- 未提交改动（执行前）：用户已把根目录 001 工作单移入 `order/`（删除+新增未跟踪）→
  本轮**保留该整理**并连同 `order/` 一并入库，未回滚用户改动
- Godot：4.7.2.stable.official.ed1daf0bf @ `tools/godot/`
- 规划文件：`docs/planning/` 由本轮从 `order/` 装配（MASTER_PLAN / WO002 / README_先看这里）；
  **原包缺失** EXECUTION_PROTOCOL / GAME_RULES / ARCHITECTURE_CONTRACTS / VEHICLE_SEEDS /
  TEST_MATRIX / RELEASE_CHECKLIST / TASK_STATUS / templates —— 缺失期间以 MASTER_PLAN §六
  与工作单正文为协议依据；官方版本到位后以官方为准（见 `docs/planning/README_先看这里.txt`）

## 1. 实际实现（§2）
1. 现场记录 + 修复前日志（§2.1–2）：`logs/002/prefix_rerun.log`（52/52 全绿留档）
2. 测试有效性变异验证（§2.2）：隔离临时副本中 M1（RELOAD=0）/M2（射线掩码=0）
   均使对应断言精确变红、退出码 1；M0 干净副本 52/52 复现。测试后临时副本已删除。
3. 核查与修复（§2.3）：发现并修复 **D1 截图假成功**、**D2 暂停菜单/准星锚点不渲染**
   两个真实缺陷（均先有像素级/日志级复现，最小修复，详见 QA_BASELINE_002 §缺陷表）
4. HUD 布局（§2.4）：提示条底部锚定、调试面板右上锚定 → 720p/1080p/拉伸适配；
   双分辨率真实截图；屏幕后方瞄点、贴墙相机、炮镜切换、鼠标重捕获均有证据或标待人工
5. 调参与调试（§2.5）：GameConfig 仍为唯一调参入口；新增 F3 调试显示
   （FPS/车速/炮塔角/炮管俯仰/装填剩余），无复杂设置系统
6. AGENTS.md（§2.6）："仅限 001" → "按当前获批工作单执行" + 002→036 分阶段解禁清单 +
   永久约束（隐私/不换栈/不虚构/不强推等）完整保留
7. 基线验收表（§2.7）：`docs/QA_BASELINE_002.md`（自动项全✔，人工项全部 ⏳ 未代签）

## 2. 自动验收执行（§3，真实运行）
- 命令与退出码、完整输出：`logs/002/`（8 个日志文件，含修复前/后、变异、路径、双分辨率）
- 最终回归（绑定被测 SHA）：`logs/002/final_checks_5385122.log`
  `godot --headless --path E:\AIprogram\mcthunder -s res://tests/run_checks.gd`
  → exit=0，**71 项 0 失败**（52 原有断言全部保留 + 19 条 002 回归）
- 有限帧启动：`godot --path E:\AIprogram\mcthunder --resolution 1280x720|1920x1080 -- --autoshot`
  → exit=0，200 帧自动退出，真实抓帧 5 张/分辨率
- 全日志扫描：无任何 SCRIPT ERROR 行

## 3. 用户/真实图形验收（§4）
- U002-01 / U002-02：**NOT_RUN by Codex** —— 已提供最少试玩步骤（`开始试玩.txt`）与
  三类真实画面文件（第三人称/炮镜/暂停菜单，720p+1080p）；
  无窗口检查与像素取证**不能代替**用户实际目视与手感意见，全部如实标 ⏳

## 4. 交付物清单（§5）
- `docs/QA_BASELINE_002.md`（基线验收表）
- `docs/DELIVERY_002.md`（本文件）
- `logs/002/`：prefix_rerun / checks_002_extended / final_checks_5385122 /
  mutation_M0-M2 / T002-02_path_tests / T002-02_retest_fixed / autoshot_002_dualres /
  autoshot_002_after_fix（真实命令+退出码+完整输出）
- `docs/autoshot_*.png`（5 场景 × 2 分辨率 + .import 元数据）
- 更新后的 `AGENTS.md`、`开始试玩.txt`、`README.md`
- 新增自动回归：`tests/run_checks.gd`（19 条新断言）+ autoshot 暂停/恢复/重捕获证据流
- 交付提交：本文件随后续提交入库（SHA 见最终回复与 `git log`）；被测 SHA 见上

## 5. 未验证 / 待人工（如实）
- 试玩手感（启动/驾驶/瞄准/开炮/暂停恢复/重置）：待用户 U002-01
- 截图画面目视核验：待用户 U002-02（像素取证仅证明非黑屏/天空色/靶板红/遮罩暗化，非审美结论）
- 真实 alt-tab 失焦：通知路径已验证，OS 级行为待用户
- 窗口实时拉伸（拖拽边缘）：锚点数学与双分辨率截图支持，交互过程待用户
- 音频（本单无音效需求，未实现）

## 6. 已知问题
- HUD 为英文（引擎默认字体缺 CJK，font_cjk_support=false；按单不下载字体）
- 弹道线为 1px GPU 线；炮镜切换瞬时（无平滑）——初始取舍，未在本单范围内改
- 边滑行边转向有 ~0.3m 位置横移（转向与剩余滑行速度矢量合成）
- 规划包协议/模板文件缺失（见 §0），正式协议到位前按 MASTER_PLAN §六 执行

## 7. 运行入口与回退位置
- 运行：双击 `START_GAME.bat`；或 Godot 项目管理器导入 `project.godot` 后 F5
- 回退：`work/002-baseline` 分支（`5385122` 及后续证据提交）；其父 `29376e2`（001 基线）；
  main 分支未动
- 状态：**实现完成待签收** —— 本单完成仅意味着待签收，不开始 003