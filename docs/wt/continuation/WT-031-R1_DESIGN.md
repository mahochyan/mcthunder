# WT-031-R1 设计页（113 条目分级 + 冻结两辆现代代表车）

- 对应父项：WT-030 / WT-031 / WT-033；依赖：WT-001-R1（`208648ae`）、WT-001-R2（`c5f53c31`）
- 依据：`02_首轮10张执行单.md` §03；`11_ALL_WORK_ORDERS.md` WT-030A/030B/030C/031A；`03` WT-031 行 1280-1323

## 1. 现状（实测，非推断）

| 事实 | 证据 |
|---|---|
| 已准入车型 = **4 辆历史车**（硬编码常量） | `scripts/content/vehicle_catalog.gd:3` `IDS := [M4A3, M24, M26, M36]` |
| 准入链 = 包校验 → 模型存在 → 注册 | `VehicleCatalog.load_all/register` → `VehicleContentPipeline.validate_package` → `defs` |
| 资格链 = 编成 → 模式/解锁 → 配弹 | `Lineup.validate`（13 行）→ `MatchConfig.build`（30 行） |
| **AI 与重生槽位绕过门禁** | `scripts/battle/team_range.gd:174-179`：直接从 `VehicleCatalog.IDS` 循环取车，不查模式/解锁/预览态 |
| 研发图 = 4 节点 | `scripts/garage/research_graph.gd:5-9` |
| 现代候选 = 2 辆，**仅候选** | `assets/reference_data/candidates/{ussr_t_80b,germ_leopard_2a4}.json`：`admission="candidate_only"`、`historical_verified=false`、各 `gaps[7]`；模型 `assets/vehicles/modern_bound/*.glb`（约 1 MB） |
| 现代机构适配器要求的冻结源**存在** | `modern_model_mount_adapter.gd:28` 要求 `res://assets/research/models/<id>.glb`；实测该目录存在且含 `ussr_t_80b.glb`、`germ_leopard_2a4.glb`；仍要求 source row `status=reviewed_static_model` + `geometry_status=PASS` + `visual_status=PASS`（待核） |
| 预览登记表仅 1 条 | `assets/vehicles/ussr_batch/catalog.json`（1526 B，1 条 `validated_preview`，`tracked=false`） |
| **113 个模型在仓库内** | `assets/research/models/*.glb` = **113**（germ 75 + ussr 37 + us 1），与科技树 `model` 非空行**逐 id 全匹配（113/113）** |
| 科技树权威分级数据 | `assets/research/soviet_german_tree.json`（431,582 B）：`vehicles[212]`（苏 116/德 96，`base_model` 全 true）、`variant_refs` 合计 **160** 条（59 个基础型带改型）、`model` 非空 **113**、`combat_package` 非空 **0**、`admission_status`：`static_preview_only` 113 + `awaiting_model` 99；`issues` 空、`cache_entries` 393 |
| 历史四车模型存在 | `assets/vehicles/{us_m4a3_75w_vvss_1944,us_m24_m6_t85e1_1951,us_m26_m3_1945,us_m36_m4a1_1945}.glb` 均存在（`VehicleCatalog.register` 的存在性检查可过） |

## 2. 目标

1. **五维台账**：把"能不能用"拆成 `resource / combat_config / specialized_verified / match_verified / distribution_license`，逐车给出取值 + 原因码；**无信号即 not_run/unverified，不臆造**。
2. **统一门禁**：玩家、AI、首发、再出击、旧档恢复共用一个判定入口；前端禁用只是投影。
3. **两辆现代候选点名补缺**：冻结 T-80B / 豹 2A4 的确切配置、炮口、武器/弹种、乘员/弹架、防护、火控与装填机制，并列出阻塞项。
4. **113 条目分级**：按"仓库内可验证（模型/预览登记）"与"外部口径（文档宣称）"分开计数，旧回报 113 不自动当作当前真值。

## 3. 接口与数据结构（新增）

### 3.1 `scripts/content/vehicle_readiness.gd`（`class_name VehicleReadiness`）

```
const DIMENSIONS := ["resource","combat_config","specialized_verified","match_verified","distribution_license"]
const CODES := {unknown_vehicle, not_admitted, resource_missing, config_incomplete, variant_conflict,
                reference_unadmitted, preview_only, mode_restricted, not_unlocked, loadout_invalid,
                match_evidence_missing, license_unverified}

static func reason_text(code) -> String
static func entry(id, packet, evidence, admitted_ids) -> Dictionary      # 单车五维 + codes
static func ledger(catalog, defs, evidence) -> Dictionary               # 全目录 + 分类计数
static func eligible(id, mode, profile, catalog) -> Dictionary          # {ok, code, reason}
```

五维取值口径（全部可追溯到实测信号）：

| 维度 | 取值来源 | 允许值 |
|---|---|---|
| `resource` | 数据包文件存在 + 模型（`model_binding` 或 `assets/vehicles/<id>.glb`）存在 + `ModelBindingValidator.self_contained_glb` | `ok` / `missing` / `malformed` |
| `combat_config` | `VehicleContentPipeline.validate_package` + `VariantCompatibility.check` + `ReferenceEvidenceGate.check` | `ok` / `incomplete` / `conflict` + codes |
| `specialized_verified` | `docs/wt/continuation/VEHICLE_EVIDENCE.json` 显式登记（测试入口 + 结果文件 + 项数 + 退出码） | `passed:<证据>` / `not_run` |
| `match_verified` | 同上（整局/多局证据） | `passed:<证据>` / `not_run` |
| `distribution_license` | 同上（许可/分发授权登记） | `verified:<证据>` / `unverified` |

### 3.2 证据登记表（新增）`docs/wt/continuation/VEHICLE_EVIDENCE.json`

只登记**我实际跑过或仓库中实际存在**的证据；未登记 → `not_run`。

### 3.3 门禁接线

| 位置 | 现状 | 改法 |
|---|---|---|
| `scripts/garage/lineup.gd:9-11` | 仅返回本地化文案 | 改调 `VehicleReadiness.eligible()`，返回 `code` + 文案（行为等价，可判定） |
| `scripts/battle/team_range.gd:174-179` | AI/重生直接取 IDS | 每次取车经 `eligible()`；未准入/预览态/未解锁 → 退回已准入车型；拒绝理由进 HUD/日志 |

## 4. 正反测试（`tests/run_vehicle_readiness_checks.gd`）

| 类型 | 用例 | 期望 |
|---|---|---|
| 正 | 4 辆历史车台账五维齐全、`resource=ok`、`combat_config=ok` | PASS |
| 正 | A→预览 B→切国→返回：`selected` 始终为已确认 A | PASS |
| 反 | 配置缺失（伪造 id） | `unknown_vehicle` 受控拒绝 |
| 反 | 资源缺失（复制包去掉模型） | `resource_missing` |
| 反 | 错误 variant（改 `assembly.variant`） | `variant_conflict` |
| 反 | 旧存档（未解锁 id + normal 模式） | `not_unlocked` |
| 反 | 预览态车型进正式编成 | `preview_only` |
| 反 | AI/重生槽位请求未准入车型 | 不落地该车型（有界回退） |

## 5. 明确不做

- 不扩第 114 个预览、不为 113 条量产量配置、不把候选标为战斗车。
- 不修改战斗参数、不重写伤害/火控、不改科技树布局、不改导出预设。
- 性能采样继续 `HOLD_BY_USER`；真人 `NOT_RUN`。

## 6. 回滚

新增文件删除 + `lineup.gd`/`team_range.gd` 两处接线 `git revert` 即可；不触及数据包、模型与历史台账。
