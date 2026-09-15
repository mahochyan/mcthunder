# WT-040-R1 河谷团队战接通：进展、**实测缺口**与下一步（工作记录）

## 1. 用户指令（2026-09-15）
> 下一阶段主交付：**苏德两辆现代工程样车，在河谷完成一次正常团队战，并交付对应源码的独立可运行包。**
> 先做：**用 AI 完成实际对局、记录数据。**

## 2. 本轮已落地的文件（**新增，不改既有定义** ✓；尚未接入玩家可见入口 ✓）
| 文件 | 作用 | 状态 |
|---|---|---|
| `scripts/maps/river_team_definition.gd` | 由河谷**自身授权数据**组装 `MapDefinition` | **已写，图形状需修正**（见 §4） |
| `scripts/maps/river_team_range.gd` | `extends VillageRange` ⇒ 继承整套团队机制（AI 名单/票数/再出击/时钟/目标点） | 已写 ✓ |
| `scenes/maps/map_river_team.tscn` | 场景入口 | 已写 ✓ |
| `scripts/maps/map_registry.gd` | 加 `river_junction_team` 到 **ENTRIES**（供记录器按路径加载 ✓）**但不入 `IDS`** ✗（不向玩家声称为已准入 ✓） | 已改 ✓ |
| `tests/record_river_ai_match.gd` | **AI 实际对局记录器**（逐 5 s 采样：票数/存活/抵达中央/逐目标点抵达/射弹槽位/再出击/击毁/停滞/结算 ✓；输出 JSON ✓） | 已写 ✓，已修语法错误 ✓ |

## 3. 河谷不能团队战的**根因（源码实测）**
1. `RiverJunctionRange` **extends `BallisticsRange`** ✗（非 `TeamRange`）⇒ 拿不到团队机制；
2. `RiverJunctionDefinition` **只提供静态布局、从不产出 `MapDefinition`** ✗；
3. 其 `layout()` 自述 **`status:"design_preview"`、`combat_admitted:false`** ✗（"未准入战斗"是作者写下的状态 ✓）；
4. 场景明确标注"**单车驾驶**"且只登记 1 个 spawn ✗。

## 4. 首次实跑暴露的**真实缺口**（错误已捕获，非推测 ✓）
```
SCRIPT ERROR: Invalid access to property or key 'position' on a base object of type 'Dictionary'.
  at: MapDefinition.minimap (map_definition.gd:44)   ← obstacles 需要 {position,size}
SCRIPT ERROR: Invalid access to property or key 'bounds' on ... Dictionary.
  at: BattleUI.setup (battle_ui.gd:43)               ← 由上一处连锁失败
[FAIL] river team match initialised with 8 AI actors on the authored river graph
```
**归因（已查清）**：
| 项 | 我原先取用 ✗ | 机器实际期望 ✓ | 正解 |
|---|---|---|---|
| 导航图 | `RiverJunctionDefinition.route_graph()` ✗（**战略设计图**，节点为 `Vector2`、边为 `[a,b]`，且自带 `scope:"strategic_design_only"` ✗） | `{"schema_version","nodes":[{"id","position":[x,y,z]}],"edges":…}` ✓ | **改用 `RiverJunctionNavigation`** ✓ —— 该文件**已把河谷转成期望形状且带地形高度** ✓（`river_junction_navigation.gd:12,75-76`） |
| 障碍物 | `hard_cover()` 的 `{"id","xz","footprint","height"}` ✗ | `{kind, position:Vector3, size:Vector3}` ✓ 且 `kind` 须为 `WorldCollisionRules` 已知类 ✓ | 按该形状转换（`kind` 取既有的掩体类 ✓），或先留空 ✓ |

## 5. 下一步（不打断既有工作的顺序）
1. **改用 `RiverJunctionNavigation` 构建图** ✓（修正 `RiverTeamDefinition.create()`）；
2. 障碍物按机器形状转换 ✓（或首轮留空并在记录中标注 ✓）；
3. **跑通第一场河谷 AI 4v4** ✓（在 16v16 **已授权布局**上，4v4 名单 —— 泊位不作容量声明 ✓）→ 产出 `logs/WT-040-R1/river_ai_match_44001.json` ✓；
4. 随后按用户四步：**样车战斗包 → 实际操作接通（含烟幕或辅助武器之一）→ 完整流程与独立包** ✓。

## 6. 诚实边界
- 河谷 **`combat_admitted=false` 未被隐藏也未翻转** ✓；本场景定位为**工程性 AI 对局测量** ✓；
- 目前**尚未接入车库/正常入口** ✓（`ENTRIES` 有、`IDS` 无 ✓），待数据出来、你确认地图准入后再决定 ✓；
- 本轮**没有**声称"河谷团队战已完成" ✓。
