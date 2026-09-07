# QA 基线验收表 — 工作单 002（001 补验收与基线冻结）

- 被测源码：`work/002-baseline @ a4124949f097b0be2c35cb021ed4261087b41b02`（002-R3 收尾后；与 002-R3 被审代码一致，收尾仅改测试）
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

## 002-R3 修订（GPT 审核签发，2026-09）

| 项 | 结论 | 证据 |
|---|---|---|
| R3-A 水平目标角符号 | 生产代码修复：炮管 -Z 前向右手系下世界 yaw = atan2(-d.x, -d.z)（旧 atan2(d.x,-d.z) 符号相反）；抽取共用 `_target_angles()`，正常追赶与 snap_to_aim 两路径一致；未反转鼠标/镜像模型/挪靶/相机判伤 | `scripts/turret_rig.gd` |
| R3-A 测试能抓住旧错误 | 修复前源码实跑：B2/B3 稳定收敛失败（78 帧过线后转离 0.60°/0.58°），exit=1——正是"首次掠过即通过"漏检 | `logs/002-R3/checks_R3_prefix.log` |
| R3-A 稳定收敛验收 | 首次进入 0.5° 后不结束测试，连续保持 1 秒（60 帧）全程 ≤0.5°，中途转离即失败；左右目标（B2 +X / B3 -X）+ 车体非零 yaw（0.5 rad）；稳定后生产 try_fire 实射命中，等真实装填结束第二炮仍命中；真值 = P - 炮根（每帧当前炮根），不复制生产 atan2；未放大靶板 | `logs/002-R3/checks_R3_postfix.log`（115/115，exit=0） |
| R3-A 身份验证 | 意图射线选中改用 collider 身份验证（独立查询，与生产同 mask/exclude），distance<2 仅辅助；T002-03a 与 001 遮挡前提均升级为 collider 验证 | 同上 |
| R3-C 证据 | 新源码 SHA 双分辨率独立目录 `docs/evidence/002-R3/5232261…/{1280x720,1920x1080}` + manifest（实际宽高+SHA256+场景+命令+源码 SHA）；旧变异/旧失败负例未重跑未改标 | `logs/002-R3/evidence_manifest.txt`、`autoshot_R3_720p.log`、`autoshot_R3_1080p.log` |
| R3-D 文档勘误 | DELIVERY_002_R2.md 追加勘误：证据目录名=源码 SHA，存储证据的提交号不同（源码 96f199b / 证据 b6eec1c / 最终回归 db24e43） | `docs/DELIVERY_002_R2.md` |
| R2-D 规划包 | 继续 BLOCKED_TRANSFER（需人工下载 ZIP 提供本地路径，不阻塞本单） | `docs/DELIVERY_002_R3.md` |

## 002 收尾（GPT 关闭瞄准阻断后签发，2026-09）

| 项 | 结论 | 证据 |
|---|---|---|
| 稳定收敛计时/统计对齐 | 首次达标保持时间从零起按模拟时间累计 ≥1.0 秒（非"60 采样点"），首样本误差纳入最大误差；全程生产更新，超 0.5° 即失败；输出保持时长/最大误差/结束误差 | `logs/002-R3/checks_R3_closeout.log`（116/116，exit=0） |
| 自然装填第二炮 | 删除手动清零 cooldown/grace，先断言开火条件自然满足（cooldown=0.00 grace=0.00）再生产开火命中 | 同上 |
| 真人验收准备 | `docs/USER_ACCEPTANCE_002.md`：试玩 7 项 + 三类画面 + 待真人事项；真人未做标 NOT_RUN 不代签；试玩候选 = work/002-baseline @ a412494 | `docs/USER_ACCEPTANCE_002.md` |
| 规划包 | 继续 BLOCKED_TRANSFER（需真人下载对话附件 ZIP 提供本地路径） | `docs/DELIVERY_002_R3.md` |

## 签收状态

- 自动检查：✔ 全部通过（证据齐；002-R3 收尾后 116 项，exit=0）
- 人工验收：⏳ 未签收 —— **本基线状态=“实现完成待签收”，不等于 accepted**；真人验收表见 `docs/USER_ACCEPTANCE_002.md`