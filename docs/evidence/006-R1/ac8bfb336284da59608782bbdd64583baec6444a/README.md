# 006-R1 弹道演示证据说明（tested_code_sha = ac8bfb336284da59608782bbdd64583baec6444a）

目录：`docs/evidence/006-R1/ac8bfb336284da59608782bbdd64583baec6444a/1280x720/{15fps,60fps}/`
（每 fps 各 6 张，共 12 张；运行元数据见 `logs/006-R1/<sha>/RUN_METADATA.md`）

来源：`--ballistics-demo`（训练场景同一装配 + 生产发射路径）。006-R1 演示在 006-d
基础上按整改单重写：近靶命中验证目标身份、远靶道真实启用（近靶/近背墙切换禁用）、
远靶更长飞行 + 身份验证 + 真实距离、截图渲染完成后捕获并记录捕获时点状态。

## 六个时间点（每 fps 各 6 张）

| 文件 | 时间点 | 程序化断言链 |
|---|---|---|
| demo_1_just_fired_miss.png | 刚发射未命中 | shot1 抬瞄越板 → `impact_world 28.369m`（背墙） |
| demo_2_in_flight.png | 近靶飞行中 | active=1；物理采样 15→20m（15fps 捕获时点）/ 15m（60fps） |
| demo_3_after_impact.png | 近靶接触后 | `impact_world 26.600m t=0.0887s`；**NearBoard hit_count 恰 +1、FarBoard 不变**（身份验证） |
| demo_4_far_in_flight.png | 远靶飞行中 | 切远靶道后真实发射；采样 45m@age0.15s；飞行窗口 30 空闲帧/0.497s |
| demo_5_far_after_impact.png | 远靶接触后 | `impact_world 146.602m t=0.4887s`；**FarBoard hit_count 恰 +1、NearBoard 不变**；真实炮口→接触面 146.602m |
| demo_6_reset_cleared.png | 重开已清空 | 在飞 1→0；靶板反馈/最近结果/视觉清空（hit_count=0 校验） |

## 双帧率对照（实际帧率明确分离）

| | 15fps | 60fps |
|---|---|---|
| 请求/实际 | --max-fps 15 + --disable-vsync / **15.0 fps** | --max-fps 60 + --disable-vsync / **60.0 fps** |
| 物理帧数 | 1133 | 1133 |
| 撞击数据 | 四条记录与右列**逐字节一致** | shot2 26.600m/0.0887s；shot3 146.602m/0.4887s |

`--fixed-fps` 未使用（006-R1 明确禁用）；`--disable-vsync` 为引擎官方选项。
飞行窗口实际帧间隔由演示实时打印（15fps 跑：avg 15.0；60fps 跑：远靶窗口 avg 60.4）。

## 006-d 旧证据归属

006-d 的 30/144 双限帧证据（docs/evidence/006/370242e4…/）保留原归属不重写；
其两跑实际帧率相近（~24-26），按 006-R1 复核意见准确表述为"两次运行结果一致"，
低/高渲染帧率分离对照由本目录 15/60fps 两跑承担。

## 画面验证边界（保留项声明）

- 截图为渲染完成后真实抓帧（71–85KB 非空），断言链全过；**PNG 全部标 NOT_REVIEWED，
  人工目视未做**（并入 011 前人工验收，不代签）。
- 每张 PNG 的捕获时点真实模拟状态（projectile_id/age/位置/在飞数）见演示日志
  `capture … (NOT_REVIEWED): active=N state=[…]` 行——低帧率下捕获时点可能晚于请求
  tick（15fps 一空闲帧 ≈ 4 物理步），以打印的捕获时点状态为准，不以请求时点冒充。