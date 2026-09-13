# WT-031-R1 两辆候选配置完整性与来源报告

- 对象：`ussr_t_80b`（T-80B）、`germ_leopard_2a4`（豹 2A4）
- 方法：只读候选数据包 + 冻结模型 + 现有校验器实际调用（`VehicleReadiness` / `ModelBindingValidator` / `ModernModelMountAdapter`），不使用设计文档推断
- 机器可读台账：`docs/wt/continuation/VEHICLE_READINESS.json`（本单导出，10,956 B）

## 1. 十项要求逐条核对

| # | 要求（01 的 P0-2 / 02 §03 口径） | `ussr_t_80b` | `germ_leopard_2a4` | 依据 / 缺口 |
|---|---|---|---|---|
| 1 | 尺寸轴心 | 候选包有 `fields[33]` / `raw_fields[60]`，未见作者几何图 | 候选包有 `fields[33]` / `raw_fields[63]`，同上 | gap `active_geometry`（位置/尺寸/朝向需作者几何图） |
| 2 | 运动碰撞 | 未定义（无 `combat_definition`） | 未定义 | `combat_definition = null`（实测） |
| 3 | 履带/悬挂 | 机构规格有 `running_mesh_count=14`、`wheel_prefix="Wheel_"` | `running_mesh_count=14`、`wheel_prefix="wheel_"` | `modern_model_mount_adapter.gd:5-6`；但源模型**无 `.import`**，场景加载路径不可用 |
| 4 | 武器瞄具 | `weapon_references[4]` | `weapon_references[4]` | gap `fire_control`（镜位 FOV/偏移/测距行为缺失） |
| 5 | 弹药和弹架 | `ammo_racks[2]` | `ammo_racks[2]` | gap `ballistics_and_materials`（无完整穿深曲线/等效装甲；禁用 hitPower 当穿深） |
| 6 | 装甲 | `armor_groups[6]` | `armor_groups[9]` | gap `active_geometry`（层序需作者几何图）+ gap `ballistics_and_materials` |
| 7 | 模块和乘员 | `damage_module_references[182]`、`crew_roster[3]` | `damage_module_references[182]`、`crew_roster[4]` | gap `truncated_sections`（部分模块被源导出器省略）、`active_geometry` |
| 8 | 能力/恢复/死亡 | 未定义 | 未定义 | gap `fire_control`/`equipment_resolution`；无战斗包 |
| 9 | 车库编成 | 不可出战（`preview_only`） | 不可出战（`preview_only`） | 五维台账 codes；`Lineup.validate` 受控拒绝 |
| 10 | 来源与当前规则验证 | `source.sha256` 存在；`historical_verified=false`；来源为 `warthunder_reference` | 同 | gap `historical_evidence`（发行年份≠历史改型年份）；分发许可 `unverified` |

## 2. 冻结源（可追溯身份）

| 项 | `ussr_t_80b` | `germ_leopard_2a4` |
|---|---|---|
| 候选包 | `assets/reference_data/candidates/ussr_t_80b.json`（217,400 B） | `assets/reference_data/candidates/germ_leopard_2a4.json`（209,976 B） |
| 仓库内冻结模型 | `res://assets/research/models/ussr_t_80b.glb`（存在、git 跟踪、无 `.import`） | 同（`germ_leopard_2a4.glb`） |
| 外部制作声明路径 | `E:/AIprogram/aimodel/苏联/中型坦克/ussr_t_80b/制作中/vehicle.glb` | `E:/AIprogram/aimodel/_制作记录/德国/candidates/germ_leopard_2a4/vehicle.glb` |
| 外部声明状态 | `built_awaiting_visual_review` | `built_pending_visual_and_roundtrip` |
| 外部 sha256 | `8f47a0a2…ae5af` | `4e7a3515…8bd88` |
| 三角面（声明） | 12,972 | 13,540 |
| `published` | `false` | `false` |
| 机构挂点规格 | `root=ussr_t_80b`、`gun_mesh=MainGun` | `root=VehicleRoot`、`gun_mesh=MainGunAndMuzzleBrake` |

## 3. 五维台账取值（本单实测）

| 维度 | 历史四车 | 两辆现代候选 |
|---|---|---|
| `resource` | `ok`（模型存在且 GLB 自包含） | `ok`（仓库内冻结模型字节可用；`import_visible=false`） |
| `combat_config` | `ok`（内容管线 + 改型兼容均通过） | `not_applicable`（候选包，非生产战斗配置） |
| `specialized_verified` | `passed:tests/run_garage_checks.gd (151 checks, exit 0)` | `not_run` |
| `match_verified` | `not_run` | `not_run` |
| `distribution_license` | `unverified` | `unverified` |
| 阻塞码 | `match_evidence_missing`、`license_unverified` | `preview_only`、`config_incomplete`、`match_evidence_missing`、`license_unverified` |

> 参考准入是**独立轨道**：`ReferenceEvidenceGate.check()` 对四个历史数据包返回 `evidence_profile: expected game_reference` 与 `reference package requires facts/sources/source_binding`。本单据此把参考准入从 `combat_config` 中拆出，单独在 `config_detail.reference_admitted` 报告（实测 `false`），不据此判定历史车"配置不完整"。

## 4. 结论

- 两车**可冻结为现代样车对象**（身份、来源、模型、机构规格齐备且可哈希追溯）。
- 两车**均未达战斗准入**：`combat_definition` 空、树内 `combat_package` 全为 0、7 条作者缺口未闭合、模型不可 import。
- 按 `02` §03 停止条件：**只暂停现代验收**，现有多车/离线训练不受影响；缺口已点名（见 §1 与 `PILOT_SELECTION.md` §3）。
- 不代签：真人 `NOT_RUN`；分发许可 `unverified`；性能 `HOLD_BY_USER`。
