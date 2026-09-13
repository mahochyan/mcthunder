# 模型绑定探查报告（WT-031B-D-R1）

- 依据：`03_全部42项目标工作单.md` WT-030/031 家族（模型入口与可复用资产契约）；承接 WT-030D-R1 的资产审计
- 实现：新增 `scripts/content/model_binding_probe.gd`（**只读**探查：GLTFDocument 解析 → 遍历真实节点树 → 外形/单位/角色解析 → 草稿绑定，**从不安装**）
- 验证：新增 `tests/run_model_binding_probe_checks.gd`（**60/60 PASS**）

## 1. 实测结果（四个真实 GLB）

| 资产 | 字节 | 节点 | 网格 | 最长外形 | 单位判定 | 角色解析 | 未解析角色 |
|---|---|---|---|---|---|---|---|
| `assets/vehicles/m1a1/m1a1.glb` | 3,869,232 | 7 | 3 | **9.786 m** | m | **1/6** | turret · gun · muzzle · running_left · running_right |
| `assets/vehicles/ztz99a/ztz99a_1000.glb` | 2,913,008 | 16 | 10 | **10.882 m** | m | **3/6** | hull · turret · gun |
| `assets/research/models/ussr_t_80b.glb` | 892,092 | 46 | 42 | **9.424 m** | m | **2/6** | turret · muzzle · running_left · running_right |
| `assets/research/models/germ_leopard_2a4.glb` | 889,668 | 49 | 45 | **9.642 m** | m | **2/6** | turret · muzzle · running_left · running_right |
| **合计** | — | — | — | — | — | **8/24 槽位** | — |

## 2. 两个重要结论

### 2.1 无 `.import` 的 GLB **可以被解析**（不只是"按字节读取"）
四个资产**全部**经 `GLTFDocument.append_from_file()` + `generate_scene()` 成功解析。此前"研究模型只能按字节读取"的说法只在**资源加载器**（`ResourceLoader`）意义上成立；**GLTF 解析器可以打开它们**。→ 车池量产的可行路径是"用 GLTFDocument 探查 + 作者化角色映射"，而不是等 `.import`。

### 2.2 缺的不是模型，是**角色名映射**
外形 9.4–10.9 m、单位=米 → 资产本身是**真实尺度**的成品；但六个绑定角色（`hull/turret/gun/muzzle/running_left/running_right`）**只有 8/24 解析**，说明这些 GLB 的节点命名与绑定词表不一致：
- `m1a1.glb` 仅 7 节点/3 网格（合并后的 LOD），几乎没有可分辨的子部件；
- `ztz99a_1000.glb` 有 16 节点/10 网格，但缺 `hull/turret/gun` 语义名；
- 两样车研究模型有 **46/49 节点、42/45 网格**（结构最丰富），但仍缺 `turret/muzzle/running_*`。

**可行动结论**：注册前需要一层**显式角色映射**（作者化节点名 → 绑定角色）。两样车的 `modern_model_mount_adapter.gd` 已声明 `root`/`gun_mesh`/`wheel_prefix` 三项——**把它扩展到六个绑定角色即可产出完整绑定**；M1A1 的合并 LOD 需要重新导出带角色的版本（属作者的资产工作，本单不代做）。

## 3. 草稿绑定与"从不安装"

`draft_binding()` 输出消费方期望的形状（`model.path/sha256`、`units.meters_per_unit`、`nodes{role→path}`），并显式带 `applied=false`、`complete`、`missing_roles`。套件断言：
- 每辆车 `applied == false`；
- `complete == (unresolved_roles.is_empty())`；
- 草稿携带**实测哈希**；
- 资产缺失时**不产出草稿也不产出角色报告**（`asset_missing`）。

**只读性**：探查器源码**无任何写入路径**（套件扫描 `FileAccess.WRITE`/`store_string`），且磁盘上的 `model_sources.json` 仍是**未改动的空注册表**。

## 4. 对注册决策的影响（与 WT-030D-R1 衔接）

WT-030D-R1 判定"登记推迟"的阻断项现可细化：

| 车 | 原阻断 | 现在细化 |
|---|---|---|
| M1A1 / ZTZ-99A | `packet_has_no_model_binding` | 需**作者化角色映射**（ZTZ 结构足够、M1A1 为合并 LOD 需重导出） |
| 两样车 | 同上 | 把 `modern_model_mount_adapter.gd` 从 3 项扩到 6 项即可产出完整绑定 |

## 5. 未完成（如实）

- **不安装任何绑定**、**不修改任何 packet / 注册表 / 脏文件**；M1A1 合并 LOD 的重导出属作者资产工作。
- 角色映射的作者化（适配器扩展）与随后注册：下一单。
- 窗口模型展厅与真人 `NOT_RUN`；不做全库 LOD/纹理专项。
