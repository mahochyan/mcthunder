# 交付记录 — 002-R1 整改（GPT 审核签发）

## 0. 现场
- 分支：`work/002-baseline`（追加提交，未重写、未强推；main 未动）
- 本轮代码提交：`f87de0e9a9f060e3903083f4b52b2eebee9f162f`（R1-A/B/C 代码与测试）
- 证据提交：本文件随证据日志入库（SHA 见最终回复与 git log）
- 引擎：Godot 4.7.2.stable.official.ed1daf0bf（未换栈）
- 审核边界：GPT 未实机运行 Godot、未目视 PNG；本单为源码+证据整改，实机/目视仍待用户

## 1. R1-A 第三人称相机与炮管俯仰不一致 —— 生产代码已修复
- 复现（先于修复）：新增断言“相机前向与炮管指向俯仰一致”，修复前恰 1 条失败
  （diff=6.7°，exit=1），日志含来源 SHA：`logs/002-R1/repro_R1A_prefix.log`
- 根因：camera_rig.gd 第三人称分支只按 aim_yaw 构造机位与视线，aim_pitch 只进炮管
- 最小修复：相机位置与防穿墙查询不变；视线改为从相机位置沿 dir3d（含 aim_pitch）看，
  相机前向 ≡ 瞄准方向。保留：炮塔有限转速、俯仰限位、相机防穿墙、炮口遮挡检查
- 修复后：diff=0.0°，78 项 0 失败；像素取证：第三人称画面中心即青色期望瞄点标记
  （相机中心射线与瞄准方向重合的直接视觉证据）
- 未用“从相机判命中”掩盖偏差；未建设 003 多车框架

## 2. R1-B 测试覆盖缺口 —— 原实现正确，测试与证据补足
- 点击“继续”按钮：不再直接调用 _resume()；构造 InputEventMouseButton（按下+释放），
  经 Input.parse_input_event 走真实 GUI 输入路径触发按钮 pressed → resume_requested。
  场景为无冷却遮掩：装填完成持火 → 暂停 → 点击继续 → 恢复瞬间无误射 →
  宽限结束后无延迟补射 → 释放后重新按下可合法射击（4 条断言全过）
- 连续 20 次重置：扩展为 3 块靶板命中数、位置、朝向、速度、冷却全部复位断言；
  窗口侧新增证据：3 次重置后 mouse_mode=2 (CAPTURED)、paused=false
- 装填冻结：改为暂停前后数值精确对比（|Δ|<0.0001，暂停 0.6s 实测）
- QA_BASELINE_002.md 中“点击继续”“鼠标状态复位”等夸大项已按实际覆盖修正
- 真实 Alt+Tab 与手感仍标待人工（未把应用内模拟包装成 OS 实测）

## 3. R1-C 变异证据与截图失败退出码 —— 生产代码已修复 + 证据补足
- 变异全量复跑（隔离副本，运行后删除）：`logs/002-R1/mutation_R1_rerun.log`
  含来源 SHA、引擎标识、副本路径、基础命令、导入步骤、每轮补丁原文、完整输出、退出码：
  M0 基线 78/78 exit=0；M1（RELOAD_TIME 2.0→0.0）恰 3 条冷却断言变红 exit=1；
  M2（命中/遮挡射线掩码→0）恰 6 条遮挡/命中断言变红 exit=1（含新增 T002-03b/c）。
  旧摘要日志保留未动，新记录明确标注“本轮复跑”；失败数量随新增测试自然变化
- _shot() 错误汇总：捕获失败/保存失败均计数；autoshot 结束时 shots_saved<5 或
  errors>0 → 退出码 1。实测双分辨率 exit=0、shots_saved=5、errors=0：
  `logs/002-R1/autoshot_R1_dualres.log`

## 4. R1-D 规划包装配 —— 未完成（等待包文件）
- 更正：GPT 已校验原始完整规划 ZIP（55 文件、35 工作单，SHA256 全匹配）——
  原包实际完整；此前“原包缺失协议/模板”的推断不成立，本地只是未装配全。
  缺口记录保留于 `docs/planning/README_先看这里.txt` 并追加更正说明
- 待办：取得 002-R1 包（含原始完整规划 ZIP）→ 解压到临时目录逐项比较 →
  补齐 docs/planning（EXECUTION_PROTOCOL/规则/架构约定/模板等）→
  任务状态文件按当前进度如实更新，不机械覆盖、不解锁 003
- 已向 GPT 请求包直链；若需人工下载，包应放入工程外临时目录后由执行端装配

## 5. 自动验收（002-R1 后）
- 全量回归：`godot --headless --path E:\AIprogram\mcthunder -s res://tests/run_checks.gd`
  → exit=0，**78 项 0 失败**（logs/002-R1/checks_R1_postfix.log）
- 有限帧启动：720p/1080p autoshot → exit=0，5 张/分辨率，含暂停菜单与重置证据
- 全日志扫描：无 SCRIPT ERROR

## 6. 用户验收（仍待用户，未代签）
- U002-01 试玩链：启动 → WASD → 上下及左右瞄准 → 炮镜 → 射击 → Esc →
  鼠标点击继续 → Alt+Tab → R 重置
- U002-02 三类画面目视：第三人称/炮镜/暂停菜单（docs/autoshot_*.png 与 _1080p 套）
- 截图存在与像素统计不等于画面已被接受

## 7. 交付物
- `docs/DELIVERY_002_R1.md`（本文件）、`docs/QA_BASELINE_002.md`（R1 修订节）
- `logs/002-R1/`：repro_R1A_prefix / checks_R1_postfix / mutation_R1_rerun /
  autoshot_R1_dualres（真实命令+退出码+完整输出）
- 代码：camera_rig.gd（R1-A）、hud.gd（resume_btn）、main.gd（_shot 错误汇总+退出码）、
  tests/run_checks.gd（R1-A/B 断言 + T002-04/05 升级）

## 8. 运行入口与回退位置
- 运行：`START_GAME.bat` 或 Godot 导入 `project.godot` 后 F5
- 回退：`work/002-baseline`（f87de0e 及后续证据提交）；main 未动
- 状态：**实现完成待签收**；按 GPT 指示停在当前分支等待审核，不开始 003