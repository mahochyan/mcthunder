# 角色映射表（WT-031C-D-R1）

- 依据：WT-030/031 家族（模型入口与可复用资产契约）；承接 WT-031B-D-R1 的 GLB 探查与 WT-030D-R1 的资产审计
- 实现：新增 `scripts/content/role_mapping.gd`（**据实author**的角色映射表 + 校验 + 草稿绑定，**从不安装**）
- 验证：新增 `tests/run_role_mapping_checks.gd`（**72/72 PASS**），其中**每一条 `node` 映射都被重新对实时 GLB 探查复核**（而非只对转录清单）

## 1. 映射结果（六角色 × 四资产）

| 资产 | 直接节点 | 作者帧 | 缺失 | 解析 | 结论 |
|---|---|---|---|---|---|
| `cn_ztz_99a` | **6** | 0 | 0 | **6/6** | **全部来自资产自身的节点名** |
| `ussr_t_80b` | 5 | 1（muzzle） | 0 | **6/6** | 炮口需在装配时创建一帧 |
| `germ_leopard_2a4` | 5 | 1（muzzle） | 0 | **6/6** | 同上 |
| `us_m1a1_abrams` | 3 | 1（muzzle） | **2** | **4/6** | 合并 LOD **无履带节点** → 需重导出 |

## 2. 映射表（逐角色，含真实节点名）

### `cn_ztz_99a`（`assets/vehicles/ztz99a/ztz99a_1000.glb`）
| 角色 | 类型 | 目标 |
|---|---|---|
| hull | node | `hull` |
| turret | node | `turret` |
| gun | node | `barrel` |
| muzzle | node | `muzzle` |
| running_left | node | `LOD1000_track_L` |
| running_right | node | `LOD1000_track_R` |

### `ussr_t_80b`（`assets/research/models/ussr_t_80b.glb`）
| 角色 | 类型 | 目标 |
|---|---|---|
| hull | node | `HullArmour` |
| turret | node | `TurretArmour` |
| gun | node | `MainGun`（与既有适配器 `gun_mesh` 声明一致） |
| muzzle | **derived** | `MainGun` + 作者偏移（0,0,−2.4 m） |
| running_left / right | node | `track_l` / `track_r` |

### `germ_leopard_2a4`（`assets/research/models/germ_leopard_2a4.glb`）
| 角色 | 类型 | 目标 |
|---|---|---|
| hull | node | `HullArmour` |
| turret | node | `TurretArmour` |
| gun | node | `MainGunAndMuzzleBrake`（与适配器一致） |
| muzzle | **derived** | `MainGunAndMuzzleBrake` + 作者偏移（0,0,−2.6 m） |
| running_left / right | node | `track_l` / `track_r` |

### `us_m1a1_abrams`（`assets/vehicles/m1a1/m1a1.glb`）
| 角色 | 类型 | 目标 |
|---|---|---|
| hull | node | `Body` |
| turret | node | `Turret` |
| gun | node | `Gun` |
| muzzle | **derived** | `Gun` + 作者偏移（0,0,−2.2 m） |
| running_left / right | **missing** | 原因 `merged_lod_has_no_track_nodes`（该 GLB 仅 7 节点/3 网格） |

## 3. 关键性质

1. **映射与实时资产一致**：套件对每条 `node` 映射**重新探查真实 GLB**并断言节点存在；派生角色的父节点也必须真实存在 → 打错名字会**报错而非猜**（`validate()` 输出具名错误）。
2. **作者帧有来源标注**：派生帧显式带 `provenance="author"`，在文档与数据中都与"实测节点"区分开（炮口位置是**设计偏移**，不是测量值）。
3. **草稿从不安装**：`draft_binding()` 带 `applied=false`；`snapshot()` 声明 `installed=false`、`registry_untouched=true`；模块**无写入路径**，磁盘注册表仍为空（套件逐项断言）。
4. **缺失角色具名**：M1A1 的两个履带角色以 `merged_lod_has_no_track_nodes` 报出，`registration_ready=false` 且 `blocker=asset_needs_re_export_for_missing_roles`。

## 4. 对车池注册的影响（更新 WT-030D/WT-029 的阻断项）

| 车 | 现状态 | 还差什么 |
|---|---|---|
| `cn_ztz_99a` | **映射完整** | packet `model_binding` + 三个 source 字段（`delivery_status/provenance/resource_version`） |
| `ussr_t_80b` / `germ_leopard_2a4` | **映射完整**（各 1 个作者帧） | 同上 |
| `us_m1a1_abrams` | **4/6** | **重导出带履带角色的 GLB**（作者资产工作） + 上述字段 |

→ 四辆现代资产中**三辆已具备完整角色映射**，"缺绑定"不再是拦路石；M1A1 的唯一硬缺口是**资产本身**（合并 LOD），这是作者的资产工作，本单不代做。

## 5. 未完成（如实）

- **不安装任何绑定**、不改 packet/注册表/GLB/脏文件、不改构建流程。
- 作者帧的实际创建（装配期）与注册：下一单；M1A1 重导出属作者工作。
- 窗口模型展厅与真人 `NOT_RUN`；不做全库 LOD/纹理专项。
