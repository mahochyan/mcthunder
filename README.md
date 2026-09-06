# PixelArmor（mcthunder hub）

可驾驶、可瞄准、可射击的 3D 坦克靶场 —— Godot 4.x · GDScript · 工作单 001 · v0.0.1

## 运行
- 引擎随工作流放在 `tools/godot`（不入库，见 .gitignore）；双击 **`START_GAME.bat`** 即玩
- 备用：用 Godot 4.x 打开 `project.godot`，F5 运行

## 操作
| 键 | 功能 |
|---|---|
| W / S | 前进 / 后退（8 / 3 m/s 上限） |
| A / D | 车体转向（可原地转向，无平移） |
| 鼠标 | 瞄准（炮塔 35°/s 追随） |
| 右键(按住) | 炮镜 |
| 左键 | 开炮（2s 装填） |
| R | 重置 |
| Esc | 暂停 / 恢复 |

## 自检
- 无窗口自动检查 **71 项全部通过**（001 的 52 项全保留 + 002 新增回归：空格路径启动 /
  三遮挡场景 / 暂停持火与失焦 / 连续 20 次重置 / 相机贴墙 / 变异验证），原始记录：`logs/002/`
- 真实窗口截图（720p + 1080p，含暂停菜单）：`docs/autoshot_*.png`
- 交付记录：`docs/DELIVERY_001.md`、`docs/DELIVERY_002.md`、`docs/QA_BASELINE_002.md`