# 006 弹道演示证据说明（tested_code_sha = 370242e4c593dd002f0c03bc8f9ffbac7418e38d）

目录：`docs/evidence/006/370242e4c593dd002f0c03bc8f9ffbac7418e38d/1280x720/{30fps,144fps}/`

来源：`--ballistics-demo`（训练场景 `scenes/training/ballistics_range.tscn`，同一训练装配 +
生产发射路径：`PlayerController`/`VehicleActor`/`Gunner.try_fire`/`ProjectileManager.try_spawn`）。
演示日志（发射/飞行中/撞击时间点、暂停冻结、重开清空）见 `logs/006/<sha>/ballistics_demo_*_stdout.txt`。

## 五个时间点（每 fps 各 5 张截图）

| 文件 | 时间点 | 程序化断言链（演示日志中逐项打印） |
|---|---|---|
| demo_1_just_fired_miss.png | 刚发射未命中（瞄点抬过靶板上缘 2.8m） | 开火成功（shot_id=1）；终止记录 `reason=impact_world travelled=28.369m point=(0,3.56,-31.5)`（越板撞背板） |
| demo_2_in_flight.png | 实际飞行中 | `active=1`；物理采样 age=0.0500s travelled=15.000m；下一 tick 采样 25.000m（推进 5m/步@60Hz） |
| demo_3_after_impact.png | 接触后 | 终止记录 `impact_world travelled=26.600m t=0.0887s point=(0,1.375,-29.8)`（HUD LAST IMPACT 同步显示） |
| demo_4_paused_frozen.png | 暂停冻结 | 暂停采样 pos/age/travelled 与 30 tick 后重采样**精确相等**（pos=(0,1.436,-18.20) trav=15.000m） |
| demo_5_reset_cleared.png | 重开已清空 | 在飞 1 发（15.000m）→ 生产 `_reset_range()`（`cancel_by_shooter("cancelled_reset")`）→ `active=1→0` |

## 双 fps 确定性对比

30fps 与 144fps 两跑：物理频率均 60 Hz、物理帧数均 950、四次撞击记录逐字节一致
（shot1 28.369m / shot2 26.600m,0.0887s / shot3 26.600m,0.0887s / shot4 cancelled_reset,15.000m）。
渲染限帧（--max-fps 30/144）不影响弹道结果。实际渲染帧率采样值见 RUN_METADATA（本机 ~24-26，
由桌面合成器/vsync 决定，低于请求上限不违反限帧语义）。

## 画面验证边界（保留项声明）

- 截图为真实抓帧（`get_viewport().get_texture().get_image()`，1280×720，70–81KB 非空画面），
  程序化检查链（上述断言）全部通过；**截图人工目视未做**（按 005/006 惯例并入 011 前人工验收，
  不代签）。
- 静态截图不能独自证明飞行过程——飞行中的时间点证据以演示日志的
  `shot2 IN FLIGHT age=0.0500s travelled=15.000m` → `advanced 15.000 → 25.000m` 两次物理采样为准。