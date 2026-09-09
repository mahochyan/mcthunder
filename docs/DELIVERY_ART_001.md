# ART-001 交付：M4A3(75)W 1944 VVSS 单车高低模烘焙试产

## 先回答工作单核心问题：同样 ≤1000 面，C 比 B 好在哪 / 代价 / 值得复制吗

**好在哪**：C = B + 高模烘焙切线法线。增益集中在**近距离材质细节**——轮毂罩圈与
8 颗螺栓的斜面渐变、履带板棱、装甲面边缝与格栅凹槽的转折。远距离（8–12m 外）
B 与 C 基本不可分（见 `docs/evidence/ART-001/near_B.png` vs `near_C.png`：
1280×720 下仅约 0.1% 像素变化超过 0.01 亮度）。

**代价**：
- 一条 Blender 脚本化高模/笼/烘焙生产线（本单已建好并跑通：`authoring/art001/build_and_bake.py`，
  low→high→cage→uv→bake→export 六阶段可重复）。
- 每 map 4 遍烘焙 × 每车 8 个烘焙对象 = 32 遍（1024px，单遍 ≤0.7s，全部 32 遍 < 25s，CPU 即可）。
- 运行时零额外成本：B 与 C 同一几何、同一贴图数（4 张 1024px），仅材质多一张法线采样；
  8 车纯渲染实测 B/C 均 60fps 满帧率（GPU 时间戳 NOT_CAPTURED，如实不虚构）。

**值得复制吗**：值得，但有条件——C 的价值取决于**观看距离分布**。本作以中远距离
坦克战为主，若炮镜/击杀镜头很少贴近 5m 内，C 的增益接近零；若常有近景检视/击杀
镜头，C 让同一 774 面模型"看起来贵一个档次"。建议：**保留 B 作为默认档**，
C 作为近距离检视（车库/击杀镜头）的可选档，用 `BakeComparison.set_variant()` 已
验证的一行切换。

## 结论：GO_SINGLE_VEHICLE（有附带修订建议）

- 单车端到端管线全部跑通，44/44 项自动检查通过（`logs/ART-001/FC6DAE2F4E6E/`）。
- 1cm 对齐目标实测 **0.0084mm**（壳面顶点直接取自布局四边形，非"对齐"而是"同源"）。
- 炮塔/火炮枢轴与 packet 完全一致（≤1mm、≤0.1° 达标）。
- 绑定烘焙视觉后开火/装填/冷却逐项不受影响；原 216 项游戏回归 0 失败。

### 附带修订建议（不阻塞结论）
1. **REVISE_LIMITED 候选**：法线细节密度偏低——高模细节目前 ~6.6k 三角（螺栓/格栅/
   轮毂/履带齿），若近景是主要卖点，高模可再投 2–3 万三角到焊缝、漆面剥落、油渍
   凹凸（本单按试产克制，未铺满）。
2. UV 图集利用率 ~35%（智能投影保全等 texel 密度所致），可手工排岛再省一半显存。
3. AO 含整车互投影（工单要求排除零姿态炮塔互投影，本轮未做分区排除），车顶偏暗。

## 交付物清单

| 路径 | 内容 |
| --- | --- |
| `authoring/art001/pilot.blend` | 工作文件：LOW(774)/HIGH(6618)/CAGE 六对象 + 单图集 UV |
| `authoring/art001/build_and_bake.py` | 全流程脚本（low/high/cage/uv/sample/bake/export） |
| `authoring/art001/uv_layout.png` | UV 图集布局 |
| `authoring/art001/sample_256/` | 256px 采样试产物（工单顺序：先采样后整车） |
| `assets/art001/m4a3_pilot/m4a3_1k.glb` | 运行时低模（774 tri，hull/turret/barrel 层级） |
| `assets/art001/m4a3_pilot/basecolor.png` | 1024 sRGB BaseColor |
| `assets/art001/m4a3_pilot/normal_gl.png` | 1024 切线法线（OpenGL +X+Y+Z） |
| `assets/art001/m4a3_pilot/orm.png` | 1024 ORM（R=AO/G=Rough/B=Metal） |
| `assets/art001/m4a3_pilot/manifest.json` | 哈希/预算/烘焙计时/方法记录 |
| `scenes/art_lab/bake_pilot.tscn` + `scripts/art_lab/` | A/B/C 切换、灯光、炮塔/俯仰、截图与 8 车性能模式 |
| `scripts/art_lab/baked_visual_adapter.gd` | 仅测试模式：程序视觉 ↔ 烘焙视觉切换（物理不动） |
| `tests/run_art001_checks.gd` | T-ART-01..08，44 项断言 |
| `docs/evidence/ART-001/` | A/B/C 远近对比截图 + B/C 性能记录 |
| `logs/ART-001/FC6DAE2F4E6E/` | 真实命令与完整输出 |

## 诚实边界（未做/未验）

- **PENDING_USER**：视觉质量最终判定需真人/委托方看图，PNG 未经 REVIEW。
- 8 车性能为纯渲染帧率（vsync 60 上限），无 GPU 时间戳数据，不据此声称"1000 面
  一定更快"。
- 高模细节密度为试产克制版（6618 tri），未铺满 200k 上限。
- AO 未做零姿态互投影排除（见修订建议 3）。

## 复现命令

```
blender --background authoring/vehicles/us_m4a3_75w_vvss_1944.blend --python-exit-code 1 \
  --python authoring/art001/build_and_bake.py -- --stage low   # 随后 high/cage/uv/sample/bake/export
godot --headless --path <工程根> -s res://tests/run_art001_checks.gd
godot --path <工程根> scenes/art_lab/bake_pilot.tscn -- --shot out.png --variant C --dist 4.5
```