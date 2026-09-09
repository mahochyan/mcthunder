# Blender 车辆源文件

2026-09-09 最新正式路径：`build_textured_lowpoly.py` 从现有装甲种子生成约 1000 三角面四车，替代下面历史高细节建模流程。共享图集位于 `assets/vehicles/textures/vehicle_concept_atlas_v1.png`，内置 ImageGen 依据用户 M4 概念图生成，实际 1254×1254；提示词见 `authoring/poly_budget/ATLAS_PROMPT.txt`。`.blend` 与 GLB 均嵌入纹理；运行时装甲 UV 保存在车型 manifest，并直接应用于查询布局的原始顶点。游戏资源同时依赖该图集和 manifest。

完整车型三角面：M4 1016、M24 908、M26 1018、M36 970；上限 1100，含两条连续履带。表面机械细节用贴图，轮组/连接悬挂/炮管/机枪/天线/外置行李保留几何。运行时纹理滚动替代逐链节几何运动，暂停/重置由实际车辆状态控制。

025 调色维护：共用 `assets/art_palette.json`，`style_metadata.py` 将 sRGB 色板转换为 Blender 线性色，写入来源、分发许可、源/运行文件相对路径、哈希与 LOD 预算。`build_models.py` 和 `export_current.py` 都应用同一材质规则。仅调色且保留现有手工几何时执行：

```powershell
& E:/blender/blender.exe --background --threads 4 --python-exit-code 1 --python authoring/vehicles/apply_style.py
```

可在末尾加 `-- us_m4a3_75w_vvss_1944` 先检查样件。脚本保存前逐顶点、逐对象矩阵比较，变化时失败；原始装甲源仍保留作调试参照。编辑或调色会更新对应 `.blend` / GLB / manifest，须一起提交。运行时只读取 GLB；源工程和生成工具由 `.gdignore` 排除。

使用本机已安装的 `E:/blender/blender.exe`，实际版本为 **5.2.1 LTS**。Godot 仍为固定的 4.7.2 普通版。四个 `.blend` 文件包含完整原创建模：命名装甲面、独立 hull/turret/barrel 轴系、可后坐炮身、轮组与悬挂、舱盖、光学件、格栅和机械细节。Blender 源文件受上级 `.gdignore` 排除，不进入游戏资源或导出包。

坐标：1 米 = 1 单位；Blender Z 向上，Godot Y 向上、-Z 向前。导出器进行 `(x,y,z)→(x,-z,y)` 建模坐标转换及 glTF Y-up 导出。轴心已在实际 Godot 导入测试中核对。

直接打开需要的 `.blend` 即可编辑。`Cosmetic_*` 为外饰，不参与装甲和损伤计算；`Armor_*` 带 `gameplay_patch_id` 与 `armor_zone` 属性，与实际查询面对应。运行时从 GLB 载入外饰，装甲皮肤与查询仍使用同一个布局资源。它们的几何、舱盖和机械细节尺寸仍是估算，不能将使用 Blender 等同于已达到测绘精度。

保存编辑后，从项目根导出当前文件，例如：

```powershell
& E:/blender/blender.exe --background authoring/vehicles/us_m26_m3_1945.blend --python-exit-code 1 --python authoring/vehicles/export_current.py
& ./tools/godot/Godot_v4.7.2-stable_win64_console.exe --headless --path . --editor --import
& ./tools/godot/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tests/run_blender_asset_checks.gd
```

这条导出路径保留 `.blend` 中的编辑。装甲形状若修改，必须同时更新内容包中的估算几何与共用布局生成逻辑；一致性检查会拒绝未同步的几何。不可用外饰遮掩错误装甲面。M26 制退器的存在来自军械目录 M26 页（印刷 p.25 / PDF p.34，15 May 1945）；其详细尺寸与端口形状为估算，仍不赋予单独装甲效果。

需要从代码重新生成全部模型时，执行下列命令。此流程会重建四个 `.blend`，因此应先将手工编辑提交到 Git：

```powershell
python tests/build_historical_packets.py --sources E:/AIprogram/research-sources/020
& ./tools/godot/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tests/export_historical_model_seed.gd
& E:/blender/blender.exe --background --threads 4 --python-exit-code 1 --python authoring/vehicles/build_textured_lowpoly.py
```

`seeds/*.json` 为真实布局导出的部件局部顶点和三角形。`assets/vehicles/*.manifest.json` 记录 Blender 版本、源种子、`.blend` 和 `.glb` 的 SHA256。Godot 默认导入会压缩顶点，验证允许最多 0.1 毫米误差，并按三角形几何检查拓扑。游戏内查询与装甲外皮没有这次导入误差。

未下载第三方车型模型或游戏插件。纹理由内置 ImageGen 派生，原图及生成提示词登记在工程。履带轮数、中心距和宽度由车辆配置提供；履带动画与小外饰均不写车辆移动或伤害状态。
