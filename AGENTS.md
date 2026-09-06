# PixelArmor — AGENTS.md

## 项目目标
工作单 001（v0.0.1）：可驾驶、可瞄准、可射击的 3D 坦克靶场。
只实现本单内容，不自行扩展成完整游戏（无敌人 / 穿甲 / 血条 / 存档 / 网络 / 更多车型）。

## 技术栈
- Godot 4.7.2-stable（官方普通版，非 .NET）+ GDScript
- 渲染器 gl_compatibility；窗口 1280×720、可调整大小
- 引擎随工程放在 `tools/godot`（含 `.gdignore`；不入库、不打包）

## 运行
- 推荐：双击 `START_GAME.bat`（按脚本位置定位引擎与工程，正确处理空格路径；
  缺引擎时输出明确提示，不静默失败）
- 备用：Godot 项目管理器导入 `project.godot` 后 F5

## 测试方式
- 无窗口自动检查：
  `godot --headless --path <工程根> -s res://tests/run_checks.gd`
  覆盖：主场景与必要节点加载、8 个输入动作存在、连续射击受 2s 冷却限制且
  按住不绕过、遮挡墙后的靶板不被实际射击代码命中、炮管穿墙时阻止开火、
  驾驶（加速/限速/滑行停车/倒车限速/原地转向/无平移）、重置、暂停与恢复宽限。
  测试全部调用游戏实际逻辑（实例化真实主场景 + 真实输入动作 + 真实射击代码）。
  失败时退出码非 0，并打印全部 [PASS]/[FAIL] 明细。
- 窗口截图自检：`godot --path <工程根> -- --autoshot`（有限帧，真实抓帧后自动退出）
- 记录位置：`docs/SELF_CHECK_001.log`（真实命令、退出码、完整输出）

## 约定
- 1 单位 ≈ 1 米；Y 轴向上；车辆前方为 -Z
- 碰撞层 / 视觉层 / 射线自身排除集中在 `scripts/game_config.gd` 头部说明：
  LAYER_WORLD=1（地面/围墙/箱子/靶板）、LAYER_VEHICLE=2（本车）、
  VIS_LAYER_VEHICLE=2（本车网格视觉层，炮镜相机 cull_mask 剔除该位）
- 所有速度 / 加速度 / 转速 / 冷却参数集中在 GameConfig

## 本单边界
- 不安装第三方游戏插件，不接入外部 API，不导出 exe（本机 Godot 运行验收）
- `tools/` 引擎、`.godot/` 缓存、`backups/` 不进 Git 与游戏资源
- HUD 中文依赖引擎默认字体 CJK 能力（当前检测=false）→ 游戏内英文 UI，
  中文说明由 `开始试玩.txt` 与本文件承担