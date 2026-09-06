# QA 基线验收表 — 工作单 002（001 补验收与基线冻结）

- 被测源码：`work/002-baseline @ 53851229727ecd363c19a189de9d51f08a0ea44c`
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
| T002-04 | 暂停前持火，恢复/点击继续不产生额外射击 | ✔ headless shots 不变；窗口证据 shots=1→1 | 同上 + `autoshot_002_after_fix.log` |
| T002-04 | 失焦通知自动暂停；暂停期间驾驶停止、装填冻结 | ✔ cd≈1.9 冻结、位移 0 | 同上 |
| T002-04 | 鼠标重捕获（窗口模式） | ✔ resumed mouse_mode=2 (CAPTURED) | `autoshot_002_after_fix.log` |
| T002-05 | 连续 20 次重置：靶板/速度/冷却/鼠标状态复位 | ✔ 20/20 通过 | `checks_002_extended.log` |
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
| U002-02 | 提交至少第三人称、炮镜、暂停菜单三个真实画面 | ⏳ 已生成：`docs/autoshot_1_thirdperson.png`、`autoshot_2_sight.png`、`autoshot_4_paused.png`（另有 3_moved/5_resumed 与全套 _1080p 版本）；**像素取证不能代替目视**，画面观感待用户逐张确认 |
| — | 真实 alt-tab 失焦行为（headless 只验证通知路径） | ⏳ 待用户 |
| — | 驾驶手感/鼠标灵敏度/炮镜体验 | ⏳ 待用户（本执行端无图形输入能力，不做目视结论） |

## 签收状态

- 自动检查：✔ 全部通过（证据齐）
- 人工验收：⏳ 未签收 —— **本基线状态=“实现完成待签收”，不等于 accepted**