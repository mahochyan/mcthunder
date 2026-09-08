# RUN_METADATA — 006-d 证据采集（tested_code_sha = 370242e4c593dd002f0c03bc8f9ffbac7418e38d）

采集日期：006-d 实施期间（分支 work/006-projectile-flight）
采集方式：cmd /c 批处理（等待真实进程结束取 %ERRORLEVEL%；超时不计通过）
超时记录：全部运行均在超时阈值内正常退出，无超时。

## 环境

- 引擎：Godot 4.7.2.stable.official.ed1daf0bf（`tools/godot/Godot_v4.7.2-stable_win64_console.exe`）
- 渲染器：gl_compatibility（OpenGL 3.3.0，NVIDIA GeForce RTX 4070 SUPER）
- 物理频率：固定 60 Hz（`Engine.physics_ticks_per_second=60`，所有运行一致；未用 --fixed-fps）
- 随机种子：演示 seed=20250606（固定测试状态）；命中判定不含随机散布（006 授权范围）
- git 工作树：提交 370242e4c593dd002f0c03bc8f9ffbac7418e38d，证据采集时无未提交源码改动

## 无头检查（4 套）

| 套件 | 实际命令（工作目录=工程根） | PASS 文本 | 退出码 | 脚本错误 |
|---|---|---|---|---|
| run_projectile_checks | `Godot_v4.7.2-stable_win64_console.exe --headless --path E:\AIprogram\mcthunder -s res://tests/run_projectile_checks.gd` | `PROJECTILE_CHECKS_PASS`（81 项检查，0 失败） | 0 | 0 |
| run_checks | `... --headless --path <工程> -s res://tests/run_checks.gd` | `CHECKS_PASS`（214 项检查，0 失败） | 0 | 0 |
| run_query_checks | `... -s res://tests/run_query_checks.gd` | `QUERY_CHECKS_PASS`（140 项检查，0 失败） | 0 | 0 |
| run_layout_checks | `... -s res://tests/run_layout_checks.gd` | `LAYOUT_CHECKS_PASS`（123 项检查，0 失败） | 0 | 0 |

完整 stdout/stderr 见本目录同名 `.txt`（UTF-8）。

## 窗口化弹道演示（--ballistics-demo，训练场景同一装配 + 生产发射路径）

命令（30fps）：
```
Godot_v4.7.2-stable_win64_console.exe --path <工程> --resolution 1280x720 --max-fps 30 res://scenes/training/ballistics_range.tscn -- --ballistics-demo --shot-dir docs/evidence/006/<sha>/1280x720/30fps
```
命令（144fps）：同上，`--max-fps 144`，shot-dir `.../144fps`。

| 运行 | 请求限帧 | 实际渲染帧率（采样均值） | 物理帧数 | 截图 | PASS 文本 | 退出码 | 时长 |
|---|---|---|---|---|---|---|---|
| 30fps | --max-fps 30 | 26.0 fps | 950 | 5 张 | `BALLISTICS_DEMO_PASS` | 0 | 17.3s |
| 144fps | --max-fps 144 | 23.9 | 950 | 5 张 | `BALLISTICS_DEMO_PASS` | 0 | 17.2s |

说明：
- `--max-fps` 是渲染限帧上限；实际帧率由桌面合成器/vsync 与窗口遮挡决定（本机实测 ~24-26），
  低于请求值不违反限帧语义。物理频率两跑均为 60 Hz、物理帧数同为 950。
- 两跑撞击数据逐字节一致（shot2/shot3 `travelled=26.600m t=0.0887s point=(0.0,1.375414,-29.8)`，
  shot1 `travelled=28.369m`；shot4 `cancelled_reset`）——渲染限帧不影响弹道确定性。
- 演示步进机跑在物理回调（自增 tick 等待），与渲染限帧无关；暂停段 ALWAYS 节点继续走、
  飞弹 PAUSABLE 冻结（精确相等断言）。

## stderr 说明

各 `*_stderr.txt` 为 Godot 引擎常规告警（含既有 LayoutCatalog 布局粗 AABB 告警，004-R2-C 已知），
无 SCRIPT ERROR / Parse Error（已逐文件扫描，计数见上）。