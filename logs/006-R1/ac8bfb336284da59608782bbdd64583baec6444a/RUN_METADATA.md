# RUN_METADATA — 006-R1 证据采集（tested_code_sha = ac8bfb336284da59608782bbdd64583baec6444a）

采集日期：006-R1 实施期间（分支 work/006-projectile-flight，BASE=44bb5d1，006 needs_revision 整改单）
采集方式：cmd /c 批处理（等待真实进程结束取 %ERRORLEVEL%；全部运行在超时阈值内正常退出，无超时）

## 环境

- 引擎：Godot 4.7.2.stable.official.ed1daf0bf（tools/godot 控制台版）
- 渲染器：gl_compatibility（OpenGL 3.3.0，NVIDIA GeForce RTX 4070 SUPER）
- 物理频率：固定 60 Hz（所有运行一致；未使用 --fixed-fps——006-R1 明确禁用）
- git 工作树：提交 ac8bfb336284da59608782bbdd64583baec6444a，证据采集时无未提交源码改动

## 无头检查（4 套）

| 套件 | 实际命令（工作目录=工程根） | 结果 | 退出码 |
|---|---|---|---|
| run_projectile_checks | `Godot_v4.7.2-stable_win64_console.exe --headless --path E:\AIprogram\mcthunder -s res://tests/run_projectile_checks.gd` | 122 项 0 失败，`PROJECTILE_CHECKS_PASS`（含 006-R1 新增反例与 visuals 检查） | 0 |
| run_checks | 同上（run_checks.gd） | 214 项 0 失败，`CHECKS_PASS` | 0 |
| run_query_checks | 同上 | 140 项 0 失败，`QUERY_CHECKS_PASS` | 0 |
| run_layout_checks | 同上 | 123 项 0 失败，`LAYOUT_CHECKS_PASS` | 0 |

## 窗口化弹道演示（--ballistics-demo，实际帧率分离对照）

命令（15fps）：
```
Godot_v4.7.2-stable_win64_console.exe --path <工程> --resolution 1280x720 --disable-vsync --max-fps 15 res://scenes/training/ballistics_range.tscn -- --ballistics-demo --shot-dir docs/evidence/006-R1/<sha>/1280x720/15fps
```
命令（60fps）：同上，`--max-fps 60`，shot-dir `.../60fps`。`--disable-vsync` 为引擎官方选项
（--help 在列；"Forces disabling of vertical synchronization"）；`--fixed-fps` 未使用。

| 运行 | 请求限帧 | 实际渲染帧率 | 物理帧数 | 截图 | PASS 文本 | 退出码 | 时长 |
|---|---|---|---|---|---|---|---|
| 15fps | --max-fps 15 + --disable-vsync | **15.0 fps** | 1133 | 6 张 | `BALLISTICS_DEMO_PASS` | 0 | 20.4s |
| 60fps | --max-fps 60 + --disable-vsync | **60.0 fps** | 1133 | 6 张 | `BALLISTICS_DEMO_PASS` | 0 | 20.2s |

**实际帧率明确分离（15.0 vs 60.0，vsync 关闭）**；飞行窗口逐帧间隔由演示实时记录
（`flight window: idle_frames=N avg_fps=… min/max=…`，覆盖从发射到终止的主要飞行时段；
远靶飞行窗口 30 空闲帧 / 0.497s）。

## 双帧率撞击数据对照（容差：接触点差 ≤0.005m、飞行时间差 ≤1 物理步）

| 弹 | 15fps | 60fps | 差 |
|---|---|---|---|
| shot2（近靶 26.6m） | travelled=26.600m t=0.0887s point=(0.0,1.375414,-29.8) | 同左 | 0（逐字节一致） |
| shot3（远靶 146.6m） | travelled=146.602m t=0.4887s point=(0.0,1.430354,-149.8) | 同左 | 0（逐字节一致） |
| shot1（未命中越板撞背墙） | 28.369m / 0.0946s / (0,3.561179,-31.5) | 同左 | 0 |

## 演示断言链（两跑均逐项打印）

- shot1 抬瞄越板 → WORLD 背墙 28.369m（未命中路径）
- shot2 命中 **NearBoard**（hit_count 恰 +1，FarBoard 不变——目标身份验证，非仅 WORLD）
- shot3 切远靶道 → 明显更长飞行（0.4887s vs 0.0887s）→ 命中 **FarBoard**（身份验证）
- 远靶真实炮口→接触面距离 = 146.602m（按飞弹实际路程记录，不按靶板标称值）
- 演示内暂停段已移除（暂停冻结由 headless T006-04 覆盖）
- 重开：在飞 1→0，靶板反馈/最近结果/视觉清空（hit_count=0 校验）

## 截图捕获时点（006-R1 要求）

所有 PNG 在 `RenderingServer.frame_post_draw`（渲染完成后）捕获，非物理回调直读；
每张打印捕获时点真实模拟状态（projectile_id/age/位置/在飞数）。低帧率下捕获时点
可能晚于请求 tick（15fps 下 1 空闲帧 ≈ 4 物理步），以打印的捕获时点状态为准——
例如 15fps 的 demo_1 捕获时弹已终止（active=0，如实记录）。全部 PNG 标 **NOT_REVIEWED**
（人工目视未做，不代签）。

## stderr 说明

各 `*_stderr.txt` 无 SCRIPT ERROR / Parse Error（逐文件扫描）；含既有 LayoutCatalog
布局粗 AABB 告警（004-R2-C 已知）。