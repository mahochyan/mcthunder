# 交付报告 — 002-R2（瞄准收尾 / 输入测试收尾 / 截图与证据收尾 / 规划文件）

- 分支：`work/002-baseline`（追加提交，未强推、未合并 main）
- 源码 SHA：`96f199b8eb140bb1c2e644bd35b61f0fe3492155`（本报告全部代码证据绑定此 SHA）
- 证据 SHA：与源码 SHA 相同（`96f199b…`）——本轮的截图/日志/清单与代码同一次提交，无分离
- 引擎：Godot 4.7.2-stable 普通版 + GDScript + gl_compatibility（未换栈）
- 授权：GPT 指挥 002-R2（仅限 R2，完成后停止，不进入 003）

## 代码 SHA 与证据 SHA 的区别（GPT 要求说明）

- **代码 SHA**：`96f199b8eb140bb1c2e644bd35b61f0fe3492155` —— 本轮生产代码与测试代码的提交
  （`scripts/camera_rig.gd`、`scripts/turret_rig.gd`、`scripts/main.gd`、`tests/run_checks.gd`）。
- **证据 SHA**：与代码 SHA 相同。证据（截图/日志/manifest）在代码提交后、以该 SHA 为
  `--shot-dir` 路径的一部分生成并随下一提交入库，因此证据目录名即源码 SHA，可逐文件核对。
- 若证据与代码分离提交，证据 SHA 会不同；本轮刻意保持同源，避免"证据对不上代码"的歧义。

## R2-A 瞄准收尾（PASS）

GPT 核心指正：**相机与炮管方向平行（0°）≠ 命中同一点**——两者位置不同，对有限距离目标
必须方向不同才能汇聚。已按"输入意图射线 → 期望世界瞄点 P → 炮塔目标角 → 有限速追随 →
真实炮口结算"重构：

| 项 | 实现 | 证据 |
|---|---|---|
| 意图射线 → 世界瞄点 P | `camera_rig.intent_point()`：第三人称 = 相机中心射线；炮镜 = 沿意图方向从炮根发出（**独立输入意图，不以实际炮管方向反向锁死**） | `scripts/camera_rig.gd` |
| 炮塔目标角 | `turret_rig._process/snap_to_aim`：由 P 与炮根位置反推 yaw/pitch（`atan2(dx,-dz)` 与 `atan2(dy,√(dx²+dz²))`），俯仰限位 [-8°,+20°]，保留有限转速（35°/s、30°/s） | `scripts/turret_rig.gd` |
| 真实炮口结算 | 不变：命中查询只依据炮口实际方向（`gunner.gd`），炮根→炮口遮挡检查保留 | `scripts/gunner.gd` |
| 相机俯仰修复保留 | 相机前向 ≡ dir3d（R1-A 修复未回退） | `scripts/camera_rig.gd` |
| 两距离靶板收敛+实射 | 近靶 B1 (0,0,-12) 12m / 远靶 B2 (6.53,0,-24) 24m（中/右标准靶板间隙，**未放大靶板**）：意图射线选中（身份验证 dist<2.0）→ 炮塔摆偏 57° 后**自然追赶**（不用 snap）→ 收敛 <0.5° → 实射命中且不误中另一靶 | `tests/run_checks.gd` R2-A 段 |
| 真实鼠标事件（下压/水平/上抬） | 窗口 autoshot 注入 InputEventMouseMotion：下压 -12.03° / 水平 0.00° / 上抬 +12.03°，意图俯仰与相机前向俯仰逐对匹配（帧末 call_deferred 打印） | `logs/002-R2/autoshot_R2_720p.log`、`autoshot_R2_1080p.log` |
| R1-A 断言替换 | 原"相机前向 == 炮管方向"通用断言已删除（GPT 判定为错误标准），替换为：意图响应（3 项）、意图选中（2 项）、自然追赶（2 项）、实射命中（2 项） | `tests/run_checks.gd` |
| T002-03a 重设计 | 原"矮墙"场景前提（z<-10 即算看见）不验证目标身份；改为：近置高墙（炮管仰角不足）+ 间隙后临时靶板，**身份验证**（相机视线越过墙并选中墙后靶板 dist<2.0）→ 开火成功但墙后靶板未被命中 | 同上 |

## R2-B 输入测试收尾（PASS）

| 项 | 实现 | 证据 |
|---|---|---|
| 真实 Esc 事件暂停/恢复 | InputEventKey(KEY_ESCAPE) 经 parse_input_event 走完整输入管线；暂停/恢复各断言一次 | `tests/run_checks.gd` R2-B 段 |
| 持续持火跨暂停 | 关键点断言 `Input.is_action_pressed("fire")`：暂停前/暂停中/暂停 0.5s 后/恢复后均按住；跨装填+宽限后无额外射击；释放后重按可合法射击 | 同上 |
| 真实 R 事件 | 运行中重置：不暂停、位置复位；暂停中重置：保持暂停、位置复位 | 同上 |
| 真实 F3 事件 | 开/关调试显示各一次 | 同上 |
| 恢复后装填推进 | 冻结对比后恢复，0.5s 后冷却从 1.64 推进到 0.93（< 冻结值-0.3） | 同上 |
| 点击继续前提 | 显式断言"装填完成、无冷却遮掩"（cd=0.00） | 同上 |
| 窗口证据 | 暂停 mouse_mode=0、恢复 mouse_mode=2、3 次重置后 mouse_mode=2 且 paused=false | `autoshot_R2_720p.log`、`autoshot_R2_1080p.log` |
| 待人工 | OS 级 Alt+Tab 失焦、驾驶手感/灵敏度/炮镜体验 | ⏳ U002 |

## R2-C 截图与证据收尾（PASS）

| 项 | 实现 | 证据 |
|---|---|---|
| 必需截图失败负例 | 隔离副本（含 .godot/）中把 docs/ 替换为同名文件 → 5 张必需截图全部 FAILED(err=7)、errors=5、**exit=1**（不污染生产 docs/） | `logs/002-R2/shot_failure_negative.log` |
| 分分辨率独立目录 | `docs/evidence/002-R2/<源码SHA>/1280x720/` 与 `.../1920x1080/`（`--shot-dir` 参数） | 10 张 PNG |
| 同 blob 问题消除 | 旧 `docs/autoshot_2_sight.png` 与 `_1080p` 同 blob（4a61dfa4…）已删除；新 10 张 SHA256 各不相同 | `logs/002-R2/evidence_manifest.txt` |
| 逐文件记录 | 实际宽高（1280x720 / 1920x1080）+ SHA256 + 场景 + 命令 + 源码 SHA | 同上 |
| 全量回归 | 103/103 通过、exit=0（含 R2 全部新测试） | `logs/002-R2/checks_R2_postfix_v5.log` |
| 旧变异日志 | 保持原归属（logs/002/、logs/002-R1/），未改标新 SHA | — |

## R2-D 规划文件（BLOCKED_TRANSFER）

- **README 更正已提交**：`docs/planning/README_先看这里.txt` 追加更正段（保留原缺口记录，
  注明"本地未装配全"、002-R2 已请求转存）——修复 GPT 指出的"更正未提交"问题。
- **规划包转存**：BLOCKED_TRANSFER。GPT 无法推送分支（403），附件非公开 curl 直链；
  需**人工**从 ChatGPT 页面下载 002-R2+规划 ZIP 并提供本地路径，方可解包核对装配。
  不阻塞 R2-A/B/C；未执行旧 NEXT_CODEX_MESSAGE。

## 分类汇总

| 项 | 状态 |
|---|---|
| R2-A 瞄准收尾（点瞄准模型/两靶板收敛/真实鼠标/断言替换/T002-03a 重设计） | ✔ PASS |
| R2-B 输入测试收尾（真实 Esc/R/F3、持续持火、暂停中重置、装填推进） | ✔ PASS |
| R2-C 截图与证据收尾（失败负例、双分辨率独立目录、manifest、回归） | ✔ PASS |
| R2-D 规划文件（README 更正） | ✔ PASS |
| R2-D 规划包转存 | ⛔ BLOCKED_TRANSFER（需人工下载 ZIP 提供本地路径） |
| OS Alt+Tab 失焦 / 驾驶手感 / 画面观感 | ⏳ NOT_RUN（待人工，U002） |

## 交付前检查

- 未提交文件：提交前 `git status` 仅含本轮 4 个代码文件 + logs/002-R2/（新目录）；
  证据与文档随本提交入库。
- 无 SCRIPT ERROR：本轮全部日志 grep 无脚本错误（v1–v5 回归日志、双分辨率 autoshot、负例日志）。
- 无强推、无合并 main、无引擎换栈、无外部 API、无虚构测试/截图。

## 停止点

002-R2 完成。按授权停止，等待 GPT 审核与人工签收（U002-01/02 仍待用户），不进入 003。
