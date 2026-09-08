# Blender 车辆源文件

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
& E:/blender/blender.exe --background --threads 4 --python-exit-code 1 --python authoring/vehicles/build_models.py
```

`seeds/*.json` 为真实布局导出的部件局部顶点和三角形。`assets/vehicles/*.manifest.json` 记录 Blender 版本、源种子、`.blend` 和 `.glb` 的 SHA256。Godot 默认导入会压缩顶点，验证允许最多 0.1 毫米误差，并按三角形几何检查拓扑。游戏内查询与装甲外皮没有这次导入误差。

没有下载或再分发第三方车型模型、纹理、插件。履带使用共享的动态履带代码，轮数、中心距和履带宽度由车辆配置提供；履带动画与小外饰均不写车辆移动或伤害状态。
