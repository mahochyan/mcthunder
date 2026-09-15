# 第 ③ 步 B 类评估：**带出处的资料映射**（不是机械搬运 ✗）

## 1. 校验器的硬要求（源码 ✓ `vehicle_content_pipeline.gd:12-41`）
| # | 要求 | 现状/后果 |
|---|---|---|
| 1 | 必需组件：`id, display_name, geometry, runtime, armor, modules, crew, license` ✓ | 草案缺后 5 项 ✗ ⇒ B/C 类待补 ✓ |
| 2 | **`geometry` 15 个具名字段** ✓（L17 ✓；`muzzle_brake`/`separate_rotor_shield` 可选 ✓） | **T-80B 缺 `mantlet_half_width/height`** ✗（该车无独立炮盾 ✓）⇒ 必须**派生或显式声明** ✓，否则校验失败 ✗ |
| 3 | **`runtime` 10 个具名字段** ✓（L19 ✓） | 全部属**设计项** ✗（C 类 ✓） |
| 4 | **`armor` 17 个 zone** ✓，每 zone `fact` 必须在 `facts` 中 ✓ | 待 B 类 ✓ |
| 5 | `local_mm` 若存在 ⇒ **正数 + 非空 `estimate_reason`** ✓ | 引用参考厚度**必须**附理由 ✓ |
| 6 | `hull_rings` 恰好 3 ✓；`turret_outline` **8–32 顶点** ✓ | T-80B ✓；豹2 待作者 ✓ |
| 7 | **包络互校**：重建宽/长 vs 参考尺寸 **≤16%** ✓（L34-41 ✓，参考取自 `facts` ✓） | ⇒ **参考尺寸必须做成 facts** ✓ |

## 2. 候选档案的决定性信号 ✓
| 信号 | 含义 |
|---|---|
| `armor_groups` 每节点带 **`"runtime_admitted": false`** ✗ | 参考数据在**项目层面被明确标记为未准入运行时** ✓ ⇒ 用它造战斗包**需要一次显式的准入判断** ✓ |
| 节点名为 **WT 风格**（`body_front_dm` / `turret_09_side_dm` / `gun_trunnion_dm` … ✓） | 到项目 17 zone 的映射是**判断** ✓ ⇒ 必须**逐 zone 记录依据** ✓（不得静默 ✗） |
| `source`: `origin=warthunder_reference` · **`historical_verified: false`** ✓ · `sha256=97947ab4…` ✓ | 出处**可引** ✓；`evidence_profile` **只能** `game_reference` ✓（不冒称 `historical_verified` ✗） |
| `damage_module_references` **182 项** · `crew_roster` **3 项** | 内构/乘员**有素材** ✓（`resolution_state=explicit_roster_candidate` ✓） |
| `gaps` / `fields` | 档案**自述**已知项与缺口 ✓ ⇒ 用作 `estimate_reason` / 待补清单的依据 ✓ |

## 3. B 类落地方式（**先映射后落盘** ✓）
1. 产出 **17 zone ↔ 档案节点映射提案** ✓（每行：zone · 来源节点名 · 行号 `line` · 原始值 · 置信/理由 ✓）；
2. 由映射生成 `facts["armor.<zone>"] = {value, status:"reference", origin:"warthunder_reference", source_refs:["wt2.57.1.137#L<line>"], location:"dossier line N …"}` ✓；
3. `armor.<zone> = {fact:"armor.<zone>", material:<由 armorClass 映射 ✓>}` ✓；
4. `local_mm` 仅在**同一 zone 有多来源**时使用 ✓，且**必带 `estimate_reason`** ✓；
5. **参考尺寸**（`dimensions.width_m` / `reference_length_m`）也做成 facts ✓（否则 ≤16% 互校无法进行 ✗）；
6. `evidence_profile = "game_reference"` ✓；
7. **准入判断单独提出** ✓（因 `runtime_admitted:false` ✓）——我**不**替项目做这个决定 ✗。

## 4. 本轮不改产品代码 ✓
B 类目前**未落盘** ✗：先提交**映射提案**供评审 ✓（符合"先设计、后实现" ✓，也符合"不静默改准入" ✗）。
