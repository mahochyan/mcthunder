# WT-030D-R1 设计页（车池注册与资产事实审计 + 早前结论更正）

- 对应父项：WT-030（前置 WT-001）；衔接 WT-030-R1 的内容契约与 WT-031-R1 的车池台账
- 触发原因：WT-030-R1 的"注册表为空"结论需要更细的事实；而在核实过程中**发现本批早前两处结论有误**，必须先行更正

## 1. 本轮实测事实（`assets/vehicles/`）

| 目录 | 事实 |
|---|---|
| `m1a1/` | `m1a1.glb`（3,869,232 B）+ `m1a1_1k.glb`（1,619,284 B），**均带 `.import`**；目录合计 **18,071,366 B** |
| `ztz99a/` | `ztz99a_1000.glb`（**2,913,008 B**）+ `.import` + **`ztz99a_1000.manifest.json`**；目录合计 **41,272,302 B** |
| `modern_bound/` | `ussr_t_80b.glb`（968,964 B）、`germ_leopard_2a4.glb`（1,017,136 B），**目录带 `.gdignore`**（对资源加载器隐藏） |
| `leopard2a7v/` | `leopard2a7v.glb`（17,902,436 B）+ `.import` |
| **注册表** | `configs/vehicles/model_sources.json` = `{"schema_version":1,"models":{}}` → **仍为空（0 条）** |

## 2. 早前结论更正（**本批自身的错误**，逐条留证）

| # | 早前结论 | 证据 | 更正后 | 来源单 |
|---|---|---|---|---|
| 1 | "cn_ztz_99a 仓库内无模型" | `assets/vehicles/ztz99a/ztz99a_1000.glb`（2,913,008 B）+ `.import` + manifest | **ZTZ-99A 有标准 GLB**；缺的是内容树参考条目与 packet `model_binding` | WT-029-R1 |
| 2 | "M1A1 是未纳入游戏资源库的 LOD 研究" | `m1a1.glb` 与 `m1a1_1k.glb` **均带 `.import`** | **M1A1 在工程内有可导入资产**；计划文档所指"LOD 研究"是另一件产物 | WT-029-R1 |
| 3 | "两样车只有研究模型" | `assets/vehicles/modern_bound/{ussr_t_80b,germ_leopard_2a4}.glb` 存在，目录带 `.gdignore` | 标准副本**存在但被 `.gdignore` 有意隐藏**；研究副本仍为字节文件 | WT-030-R1 |

**根因**：早前用的是**内容 grep**（按文件内容匹配），它**看不到文件名**，因此把"没有内容命中"错当成"没有资产"。本单改以**目录枚举 + 逐文件字节数/SHA-256**取证。

**已同步修正**：`scripts/content/tech_segment.gd` 的 `DEFERRED_BLOCKERS` 与 `FACTS.note`（移除"unintegrated_lod_study"/"no_model_in_repository"，改为 `packet_has_no_model_binding`）；`tests/run_tech_segment_checks.gd` 的对应断言同步更新为**更正后的硬断言**（并断言旧的错误阻断项**不再存在**）。

## 3. 注册为何**仍不填写**（有据的推迟，而非遗忘）

消费方 `BoundVehicleModel.check()` 的硬要求（读源码实测）：

1. packet 必须带 `model_binding` 字典，且 `model.path` 必须以 `res://assets/vehicles/` 开头；
2. 绑定节点必须覆盖 `ModelBindingValidator.ROLES`（hull/turret/gun/muzzle/running_left/running_right）；
3. 注册行必须提供 `delivery_status="delivered"`、`provenance="authored_asset"`、非空 `resource_version`。

**当前**：仓库内**没有任何 packet 带 `model_binding`**（`configs/` 与 `assets/vehicles/` 均无命中）→ 历史四车走的是 `legacy_model_path` 分支。**若贸然填注册表**，会让带 `model_binding` 的车切到更严格的绑定路径，风险不可控。

因此 `registration_plan()` 对四辆已知现代车给出的裁决是 **`deferred_pending_model_binding_and_source_fields`**，并逐车列出阻断项（`packet_has_no_model_binding`、`registry_entry_absent`、必要时 `directory_ignored_by_gdignore`）。审计模块**无任何写入路径**（套件对源码扫描 `FileAccess.WRITE`/`store_string`，均不存在；并断言磁盘上的注册表仍为空）。

## 4. 另一个被澄清的点

`VehicleReadiness.resource_state()` **不依赖注册表**解析模型：它用 `_model_paths()` + `FileAccess.file_exists()` 查找（注释明确"frozen research GLBs are read as bytes…not all visible to the importer"）。所以"未注册"**不等于不可用**——这修正了 WT-030-R1 文档中"必须注册才能接入"的过强表述（注册只对 `model_binding` 路径必要）。

## 5. 本轮验证

| 套件 | 结果 |
|---|---|
| `run_asset_registry_checks`（新，44 项） | **44/44 PASS** |
| `run_tech_segment_checks`（更正后） | **50/50 PASS** |
| `run_content_record_checks` | **65/65 PASS** |
| `run_garage_checks` / `run_vehicle_readiness_checks`（注册表未改，必须仍绿） | **PASS / PASS** |

## 6. 剩余工作（如实）

- 为选定车提供 `model_binding`（挂点/单位/节点路径）与三个 source 字段后**再**登记注册表；本单不代做。
- M1A1/ZTZ-99A 的内容树参考条目仍缺（阻断项保留）。
- 六个脏文件继续隔离保全；不做全库 LOD/纹理专项；窗口与真人 `NOT_RUN`。

## 7. 回滚

删除审计模块与套件、回退文档；`tech_segment.gd` 的更正为**文本与常量修正**（无行为新增）。若需回到错误版本可直接 revert 本提交——但**不建议**：那会恢复已被证据否定的结论。
