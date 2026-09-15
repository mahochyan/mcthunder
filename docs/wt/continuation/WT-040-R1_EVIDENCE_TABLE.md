# 第 4 阶段素材：**验证证据表**（每条数字 → 可复现出处 ✓）

> 用途 ✓：任何结论都能被**独立复核** ✓；本表在**对账中发现并更正**了我先前两处表述失准 ✗（已标注 ✓）。

## 1. 缺口轨迹（**出处**：`logs/WT-040-R1/package-gap-audit*.log` ✓）
| 阶段 | 日志 | T-80B | 豹2A4 |
|---|---|---|---|
| 初始（shape 门） | `package-gap-audit2.log` | **24** ✓ | **25** ✓ |
| 加事实键 | `audit3` | 23 | 24 |
| 修类别错误（runtime 进组件 ✓） | `audit4` | 20 | 21 |
| 武器/弹药（事实+组件 ✓） | `audit5` | 17 | 18 |
| 修 assembly 接线 ✓ | `audit6` | 14 | 15 |
| `crew.roles` ✓ | `audit7` | 13 | 14 |
| `variant` + `acceleration` ✓ | `audit8/9` | 11 | 12 |
| `crew` 组件 ✓ | `audit10` | 10 | 11 |
| `modules`（弹架配平 ✓） | `audit11` | **9** ✓ | **10** ✓ |
| 内容层（探针 ✓） | `audit14` | BEYOND=**4** ✓ | — |
| 修证据记录后 ✓ | `audit15` | BEYOND=**1** ✓ | — |

**更正** ✗：先前我把 9/10 与 1/1 的出处写成 `layer-probe10.log` ✗ —— 实为上述 `package-gap-audit*.log` ✓。

## 2. 各层校验（**出处**：`logs/WT-040-R1/layer-probe10.log` ✓）
| 层 | T-80B | 豹2A4 |
|---|---|---|
| `geometry.build` | ok ✓ parts=6 ✓ patches=56 ✓ | ok ✓ parts=6 ✓ patches=49 ✓ |
| `LayoutValidator.errors` | **4** ✓ | **7** ✓ |
| `VehicleShellCatalog` | `no admitted shell set` ✗（设计/资料 ✓） | 同类 ✓ |
| **`definitions`（车/炮/弹）** | **0 / 0 / 0** ✓✓ | **0 / 0 / 0** ✓✓ |

## 3. 其它证据 ✓
| 结论 | 出处 |
|---|---|
| `geometry` 自校验 **29/29** ✓ | `pipeline-geometry_check.log` ✓ |
| `run_modern_model_mount_checks` **41/0** ✓（回归已关闭 ✓） | `mount-recheck2.log` ✓ |
| `run_track_damage_checks` **单独 3s 通过** ✓ ⇒ 门禁停滞＝**并发** ✗ | `track-alone.log` ✓ |
| 流水线 **9 步全绿** ✓ | `pipeline-*.log` ✓ |

## 4. 改动范围对账（**更正后的精确版** ✓）
| 项 | 真实增删 | 判定 |
|---|---|---|
| `scripts/content/modern_model_mount_adapter.gd` | **0** ✓ | **逐字节等于基线** ✓ |
| `scripts/maps/river_junction_navigation.gd` | **0** ✓ | **逐字节等于基线** ✓ |
| `scripts/content/role_mapping_audit.gd` | **8** ✓ | **唯一**产品代码改动 ✓＝有意的 `GUN_MESH_HINTS` 修正 ✓（已回归 ✓） |
| `assets/vehicles/adapters/*`（8 个二进制 ✓） | — | **按设计** ✓：T-80B 新建 ✓ · 5 辆无炮车移除虚假原点标记 ✓ |

**更正** ✗：先前笼统称"产品代码处于基线" ✗ —— 精确表述见上表 ✓（1 处 8 行修正 + 产物按设计更新 ✓）。

---

## 5. **数据完整性验证**：armor 映射**逐条回查档案原文** ✓（独立核对 ✓）
方法 ✓：读 `modern_armor_draft.json` 的 17 个 zone ✓，按其 `location` 中的**行号与节点名** ✓，
回到 `assets/reference_data/candidates/<id>.json` 的 `armor_groups[].nodes[]` ✓ **重新取出**该行的
`armorThickness` ✓ 与 `id` ✓，与草案值逐条比对 ✓（**不信任我自己的转录** ✗）。

| 车 | 一致 | 不一致 |
|---|---|---|
| `ussr_t_80b` | **17** ✓ | **0** ✓ |
| `germ_leopard_2a4` | **17** ✓ | **0** ✓ |

⇒ 我**手写**的两份 17-zone 映射表**无转录错误** ✓✓：来源节点 ✓ · 行号 ✓ · 厚度值 ✓ **均与档案原文吻合** ✓。
（该检查正是为捕捉"**看似合理但实则错**"的数字而设 ✓ —— 本次结果为零错误 ✓。）
