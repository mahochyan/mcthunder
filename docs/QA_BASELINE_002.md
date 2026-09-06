# QA 基线验收表 — 工作单 002（001 补验收与基线冻结）

- 被测源码：`work/002-baseline @ 96f199b8eb140bb1c2e644bd35b61f0fe3492155`（002-R2 后）
- 基线参考：`main @ 29376e20e5675bd15747ac4bfd6b24382d6c3b15`（与计划参考一致，无漂移）
- 引擎：Godot 4.7.2.stable.official.ed1daf0bf（`tools/godot/`，未升级未换栈）
- 图例：✔=本轮已实跑通过（证据在 logs/002/）｜⏳=待用户签收/人工验收｜NOT_RUN=未执行且如实标注

## 自动验收（T002）

| 编号 | 内容 | 状态 | 证据 |
|---|---|---|---|
| T002-01 | 现有检查完整重跑（修复前留档） | ✔ 52/52（修复前）| `logs/002/prefix_rerun.log` |
| T002-01 | 修复后全量回归（52 原有 + 19 新增） | ✔ **71/71，exit=0** | `logs/002/checks_002_extended.log`、`final_checks_5385122.log`（绑定被测 SHA） |
| T002-01 | 原有断言零删除 | ✔ 只增未删 | `tests/run_checks.gd` diff |
| T002-01 | 变异验证：测试调用生产代码且能正确失败 | ✔ M0 干净副本 52/52；M1 冷却=0 → 恰 3 条冷却断言变红；M2 射线掩码=0 → 恰 4 条命中/遮挡断言变红 | `mutation_M0_baseline.log`、`mutation_M1_reload0.log`、`mutation_M2_mask0.log` |
| T002-02 | 含空格路径 + 更换位置启动（带引擎） | ✔ exit=0（bat 按自身位置定位引擎） | `T002-02_path_tests.log` |
| T002-02 | 无引擎副本给出可执行缺失提示（不依赖 E:\AIprogram） | ✔ exit=1 + 中文提示 | 同上 |
| T002-02 | 复测：修复后无 docs/ 目录的副本自动建目录、真实成功输出 | ✔ 5 张截图 saved、无 Can't save PNG | `T002-02_retest_fixed.log` |
| T002-03a | 相机可见但炮管被挡（矮墙）→ 墙后靶板命中数不增 | ✔ hit=0 | `checks_002_extended.log` |
| T002-03b | 炮口进入墙体 → 开火被阻止 | ✔ blocked | 同上 |
| T002-03c | 贴墙开炮（炮口越过墙远面）→ 被阻止 | ✔ blocked | 同上 |
| T002-04 | 暂停前持火，恢复不产生额外射击 | ✔ headless shots 不变；窗口证据 shots=1→1 | 同上 + `autoshot_002_after_fix.log` |
| T002-04 | 点击“继续”按钮恢复（真实鼠标事件路径） | ✔ 002-R1 补测：InputEventMouseButton 经 Input.parse_input_event 点击按钮（无冷却场景：恢复不射、宽限后无延迟补射、再按可合法射击） | `checks_R1_postfix.log` |
| T002-04 | 失焦通知自动暂停；暂停期间驾驶停止、装填冻结 | ✔ 002-R1 升级为暂停前后数值精确对比（|Δ|<0.0001） | 同上 |
| T002-04 | 鼠标重捕获（窗口模式） | ✔ resumed mouse_mode=2 (CAPTURED) | `autoshot_002_after_fix.log`、`autoshot_R1_dualres.log` |
| T002-05 | 连续 20 次重置：3 块靶板/位置/朝向/速度/冷却复位 | ✔ 002-R1 扩展（原仅单靶板/冷却/速度） | `checks_R1_postfix.log` |
| T002-05 | 重置不改变窗口鼠标与暂停状态 | ✔ 窗口证据：3 次重置后 mouse_mode=2、paused=false | `autoshot_R1_dualres.log` |
| T002-05 | 无新增脚本错误 | ✔ logs/002 全部日志 grep：无 SCRIPT ERROR | 终端扫描记录（含于 DELIVERY） |
| 资源导入/脚本检查 | --import exit=0、0 解析错误 | ✔ | `checks_002_extended.log` |
| 有限帧启动 | autoshot 200 帧自动退出（720p/1080p） | ✔ exit=0 ×2 | `autoshot_002_dualres.log`、`autoshot_002_after_fix.log` |

## 本轮发现并修复的真实缺陷（先复现后修复）

| # | 缺陷 | 复现证据 | 修复 |
|---|---|---|---|
| D1 | autoshot 截图在目标目录缺失时 save_png 失败且代码无视返回值，打印假"saved" | `T002-02_path_tests.log`（Can't save PNG ×3） | 建目录 + 检查返回码，失败如实输出（`scripts/main.gd:_shot`） |
| D2 | 暂停菜单/遮罩/准星整组不渲染（set_anchors_preset 保持原 rect → 零尺寸），像素探针证实（暗化像素 93 → 修复后 2215） | `autoshot_002_dualres.log` 时段截图 + 像素探针记录 | 改用 set_anchors_and_offsets_preset（`scripts/hud.gd`） |

## 用户/真实图形验收（U002）

| 编号 | 内容 | 状态 |
|---|---|---|
| U002-01 | 用户亲自启动并完成前后行驶、原地转向、瞄准、开炮、暂停恢复、重置各一次 | ⏳ 待用户（最少试玩步骤见 `开始试玩.txt`） |
| U002-02 | 提交至少第三人称、炮镜、暂停菜单三个真实画面 | ⏳ 已生成：`docs/evidence/002-R2/96f199b8eb140bb1c2e644bd35b61f0fe3492155/1280x720/`（autoshot_1_thirdperson / 2_sight / 4_paused，另有 3_moved/5_resumed 与全套 1920x1080 版本，逐文件宽高+SHA256 见 `logs/002-R2/evidence_manifest.txt`）；**像素取证不能代替目视**，画面观感待用户逐张确认 |
| — | 真实 alt-tab 失焦行为（headless 只验证通知路径） | ⏳ 待用户 |
| — | 驾驶手感/鼠标灵敏度/炮镜体验 | ⏳ 待用户（本执行端无图形输入能力，不做目视结论） |

## 002-R1 修订（GPT 审核签发，2026-09）

| 项 | 结论 | 证据 |
|---|---|---|
| R1-A 相机俯仰与炮管不一致 | 生产代码已修复：第三人称相机前向 ≡ 瞄准方向（从相机位置沿 dir3d 看）；修复前复现 diff=6.7°（恰 1 条失败，exit=1），修复后 diff=0.0° | `logs/002-R1/repro_R1A_prefix.log`、`checks_R1_postfix.log` |
| R1-B 测试覆盖缺口 | 原实现正确、测试与证据补足：真实鼠标事件点击“继续”按钮（无冷却场景全链）；20 次重置补全 3 靶板/位置/朝向；装填冻结改前后数值精确对比；QA 表夸大项已修正 | `checks_R1_postfix.log`、`autoshot_R1_dualres.log` |
| R1-C 变异证据与截图失败退出码 | 生产代码已修复（_shot 错误汇总 → 必需截图失败自检返回非零）+ 变异全量复跑（来源 SHA/补丁/完整输出/退出码；M0 78/78，M1 恰 3 条冷却断言变红，M2 恰 6 条遮挡/命中断言变红） | `logs/002-R1/mutation_R1_rerun.log`、`autoshot_R1_dualres.log` |
| R1-D 规划包装配 | 未完成：等待 002-R1 包（含原始完整规划 ZIP）直链/文件；原缺口记录保留并追加更正（原包实际完整，本地未装配全） | `docs/planning/README_先看这里.txt`、`docs/DELIVERY_002_R1.md` |

## 002-R2 修订（GPT 审核签发，2026-09）

| 项 | 结论 | 证据 |
|---|---|---|
| R2-A 瞄准模型 | 生产代码重构：输入意图射线 → 世界瞄点 P → 炮塔目标角（有限速/俯仰限位）→ 真实炮口结算；炮镜保留独立输入意图；相机俯仰修复未回退。原"相机前向==炮管方向"断言按 GPT 判定替换为：意图响应（3）、意图选中（2）、自然追赶（2）、实射命中（2）。两距离靶板（12m/24m，未放大）意图选中→自然追赶→实射命中且不误中；T002-03a 重设计为身份验证（相机视线越过近墙选中墙后靶板） | `logs/002-R2/checks_R2_postfix_v5.log`（103/103）、`autoshot_R2_720p.log`、`autoshot_R2_1080p.log`（真实鼠标下压/水平/上抬逐对匹配） |
| R2-B 输入测试 | 真实 Esc/R/F3 事件（parse_input_event 全链）各验证；持续持火跨暂停/恢复关键点断言 fire 仍按住、跨装填+宽限无补射、释放重按可射；运行中/暂停中真实 R 重置；恢复后装填计时继续推进（1.64→0.93）；点击继续显式无冷却前提 | 同上 |
| R2-C 截图与证据 | 必需截图失败负例（隔离副本 docs 变文件 → 5 张 FAILED、errors=5、exit=1）；双分辨率独立目录 `docs/evidence/002-R2/<SHA>/1280x720|1920x1080`（旧同 blob 截图已删）；manifest 逐文件实际宽高+SHA256+场景+命令+源码 SHA | `logs/002-R2/shot_failure_negative.log`、`evidence_manifest.txt` |
| R2-D 规划文件 | README_先看这里.txt 更正已提交（保留原缺口记录+追加"本地未装配全"）；规划包转存 BLOCKED_TRANSFER（需人工从 ChatGPT 页面下载 ZIP 提供本地路径，不阻塞 A/B/C） | `docs/planning/README_先看这里.txt`、`docs/DELIVERY_002_R2.md` |

## 签收状态

- 自动检查：✔ 全部通过（证据齐；002-R2 后 103 项，exit=0）
- 人工验收：⏳ 未签收 —— **本基线状态=“实现完成待签收”，不等于 accepted**