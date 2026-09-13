# WT-031-R1 两辆样车选型（PILOT_SELECTION）

- 依据：`02_首轮10张执行单.md` §03「优先核对 T-80B/豹2A4，冻结确切配置…两车未就绪先补缺，不拿默认训练数值冒名」；`11_ALL_WORK_ORDERS.md` WT-031A 第 3 节；`06_直接发给执行模型.txt` 第 25 段
- 前提：本仓库已有两辆现代候选的**冻结源模型**与**候选数据包**，且机构适配器已为这两型预置规格。选型不是新增内容，而是把这两型确认为本轮唯一现代样车对象。

## 1. 选中结果

| 阵营 | vehicle_id | 显示名 | 依据 |
|---|---|---|---|
| 苏联 | `ussr_t_80b` | T-80B | 用户报告与本包点名的苏系现代样车；候选包 `assets/reference_data/candidates/ussr_t_80b.json`（217,400 B）与冻结模型 `assets/research/models/ussr_t_80b.glb` 均在仓库；机构规格见 `modern_model_mount_adapter.gd:5` |
| 德国 | `germ_leopard_2a4` | 豹 2A4 | 同上德系对应项；候选包 `germ_leopard_2a4.json`（209,976 B）与 `assets/research/models/germ_leopard_2a4.glb` 在仓库；机构规格 `modern_model_mount_adapter.gd:6` |

**选型理由（可核对）**
1. **同一可对抗技术段**：两者同为战后三代主战坦克基础型（T-80B 与豹 2A4 在设计上是直接对手），符合 WT-031A「同一可对抗技术段」要求。
2. **资料与机制最可用**：两型是本仓库唯一具备"候选数据包 + 冻结 GLB + 机构挂点规格"三件套的现代车。
3. **依赖已存在**：`ModernModelMountAdapter.SPECS` 只为这两型定义了 `root / gun_mesh / wheel_prefix / running_mesh_count`，接入路径最短，不需要新建平行系统。
4. **未选 M1A1/ZTZ-99A/豹 2A7V**：它们目前只有展厅资产或脏二进制（M1A1 按 02/06 要求保持隔离），没有候选数据包与机构规格，不符合「不凭空指定未导入车型」。

## 2. 两车当前状态（实测，非推断）

| 维度 | `ussr_t_80b` | `germ_leopard_2a4` |
|---|---|---|
| 候选包准入字段 | `admission = candidate_only` | `admission = candidate_only` |
| 史料核验 | `historical_verified = false` | `historical_verified = false` |
| 树内 `combat_package` | 空（全树 0 辆有战斗配置） | 空 |
| 冻结模型（仓库内） | `res://assets/research/models/ussr_t_80b.glb`（存在、git 跟踪、**无 .import**） | `res://assets/research/models/germ_leopard_2a4.glb`（同上） |
| 外部制作声明 | `built_awaiting_visual_review`，12,972 三角面，`published=false`，sha256 已记录 | `built_pending_visual_and_roundtrip`，13,540 三角面，`published=false`，sha256 已记录 |
| 乘员名单 | 3 人 | 4 人 |
| 装甲分组 | 6 组 | 9 组 |
| 弹架 | 2 | 2 |
| 损伤模块引用 | 182 | 182 |
| 武器引用 | 4 | 4 |
| `combat_definition` | 空 | 空 |
| 作者缺口 | **7 条** | **7 条**（同一组缺口 id） |
| 五维台账 | `resource=ok`、`combat_config=not_applicable`、其余 `not_run/unverified`；codes `preview_only / config_incomplete / match_evidence_missing / license_unverified` | 同 |

## 3. 结论与阻塞（点名补缺，不冒充）

**结论**：两车**可以作为 WT-031-R1 的现代样车对象被冻结**（数据包、模型、机构规格齐备且可追踪），但**均未达到战斗准入**：`combat_definition` 为空、树内 `combat_package` 全为空、`historical_verified=false`、模型不可被导入器加载（字节级来源）。

**必须补齐的 7 项（两车同一清单，取自候选包 `gaps`）**
| gap id | 含义 | 影响的 WT 项 |
|---|---|---|
| `lossy_summary` | 默认值/模式/改装应用未完全解析 | WT-030 / WT-031 |
| `active_geometry` | 通用模块清单不是生效乘员/装备；位置、尺寸、朝向与装甲层序需作者几何图 | WT-014 / WT-015 / WT-030B |
| `ballistics_and_materials` | 无完整穿深曲线/等效装甲/预设；现有引擎缺这些现代效果；**不得用 hitPower 当穿深** | WT-012 / WT-013 |
| `fire_control` | 装填时间、俯仰限位、稳定器、镜位 FOV/偏移/测距行为缺失；**补弹不等于装填** | WT-007 / WT-008 / WT-027 |
| `equipment_resolution` | 红外/热像、已装升级、自动装填是否存在需显式解析；`dummy_weapon` 不能开火 | WT-028 |
| `historical_evidence` | 全部来源仍为 `warthunder_reference`；**游戏发行年份不是历史改型年份** | WT-012 / WT-030 |
| `truncated_sections` | 部分模块条目被源导出器省略 | WT-030B |

**另有实测阻塞（不在 gaps 清单内，本单新发现）**
1. 冻结模型 `assets/research/models/*.glb` **无 `.import` 伴生**（113/113），因此 `ResourceLoader.exists()` 为假、`load()` 不可用；机构适配器按字节读取（`GLTFDocument.append_from_buffer`）不受影响，但任何走场景加载的现代车路径都会失败。
2. `assets/vehicles/modern_bound/{ussr_t_80b,germ_leopard_2a4}.glb` 同样无 `.import`（modern_bound 2 个 GLB / 0 个 import）。

## 4. 本单不做

- 不为两车补写战斗参数（缺口需按各自 WT 项实现并验证，不能在本单"凑齐"）。
- 不把候选标为正式出战；不新增第 114 个预览；不改 `MODERN_ASSETS.json` 与 M1A1 隔离资产。
