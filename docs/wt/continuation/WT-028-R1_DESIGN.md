# WT-028-R1 设计页（现代光电、供电、告警及专用装备）

- 对应父项：WT-028（前置 WT-027、WT-017）
- 依据：`03_全部42项目标工作单.md` 行 1153-1192

## 1. 现状核查（实测）

| 要求 | 现状 | 处置 |
|---|---|---|
| 首发必须能力清单 | **缺失**（无冻结清单） | 冻结四项：测距 / 瞄准镜 / 供电 / 火控依赖 |
| 光电/热像配置 | **仅历史两车有** `configs/optics/{m4a3,m24}_design.tres`；现代车**无光电配置** | 交付装备矩阵与传感器通道规则（配置接入列为剩余） |
| 供电系统 | **不存在**（仅 WT-027 的 `power` 通道） | 把供电做成**依赖项**并与通道模型对齐 |
| 告警 / 雷达 / 主动防护 / 制导弹药 | **完全不存在** | 明确登记为 `unimplemented` + **抽象可标定规则** + 需独立功能单 |
| 热像/NV 的可见性规则 | **缺失**（无现代传感器） | 复用 WT-017 `ObservationPolicy` 通道规则并断言一致 |
| 关闭特效不得关闭玩法限制 | WT-017 已对观测策略保证 | 本模块同样**零显示设置引用** + 三段画质等值断言 |
| "不虚报角色完整就绪" | **缺失判据** | `fully_ready()` 要求 supported 级装备；当前一律 false |

## 2. 改动清单

| 文件 | 改动 |
|---|---|
| `scripts/content/modern_equipment.gd`（新，~185 行） | 装备表（分级/模块/供电/通道）+ 逐车显式装备 + 角色需求 + `availability`/`role_readiness`/`fully_ready` + 传感器可见性 + 供电报告 + 未实现清单 + 快照 |
| `tests/run_modern_equipment_checks.gd`（新，55 项） | 上述全部（含画质三段等值与源码扫描） |
| `docs/wt/continuation/MODERN_EQUIPMENT.md`（新） | **能力与模块依赖矩阵 + 已支持/实验/未实现列表 + 传感器受损与权限回归** |
| 本页 | 设计页与剩余工作 |

**未改动**：`optics_profile.gd`、`configs/optics/*`、`vehicle_readiness.gd`、`loading_mechanism.gd`、任何战斗参数与准入状态。

## 3. 关键设计决定

1. **逐车 opt-in**：装备列表写死在车型条目里，未知车型一律 `not_equipped` → 杜绝"因为叫现代车就自动启用"。
2. **分级诚实**：`supported` 为空；六项为 `experimental`；五个高阶系统 `unimplemented` 且**各自带抽象规则**（不假装已实现）。
3. **供电即依赖**：`requires_power` 的装备在断电时 `power_lost`，非供电装备不受影响；`power_report()` 给出 lost/kept，`role_readiness().missing` 指名缺口 → **提示与实际能力同步**。
4. **传感器走统一规则**：热像/夜视的可见性**直接调用** WT-017 的通道规则（烟：光学阻挡/热像 0.6；建筑：两者皆阻挡）→ 热像不穿墙。
5. **完整就绪判据**：要求所需能力由 `supported` 级装备满足；当前任何现代角色都不得自称完整就绪。
6. **显示无关**：模块零显示设置引用 + 三段画质下传感器限制恒等。

## 4. 本轮验证

| 套件 | 结果 |
|---|---|
| `run_modern_equipment_checks`（新） | **55/55 PASS**（一次通过） |
| `run_observation_policy_checks` / `run_vehicle_readiness_checks` / `run_optics_checks` | **PASS / PASS / PASS** |

**本轮零自纠**：套件一次通过（前几轮的 GDScript 陷阱已在新代码中规避：显式类型、无 Variant 推断、无空断言）。

## 5. 剩余工作（如实）

- **接入生产**：为现代车新增光电配置 `.tres` 并把装备矩阵接进 `VehicleActor` 光电路径（当前为零侵入新增模块）。
- 五个高阶系统（告警/雷达/APS/制导/可编程弹药）→ 各自独立功能单。
- 两车**仍 `candidate_only`**（本单不改准入）；WT-029 的"现代对抗样片与首发技术段冻结"仍待做。
- 窗口 UI 提示、真人 `NOT_RUN`；性能 `HOLD_BY_USER`。

## 6. 回滚

删除 `modern_equipment.gd` 与套件、回退文档；**零既有代码改动**。
