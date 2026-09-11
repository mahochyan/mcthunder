# ZTZ-99A reference model and baked LODs

本资产按用户提供的 `99A多视图.png` 为主要外形参考制作。高模在用户指出炮塔不够还原后重建：长斜面前甲、较低的前立面、炮盾中部缺口、侧箱、后部上扬底边、双舱盖、观瞄和机枪安装结构均以多视图核对。

这是对所给美术参考的模型复原，不是战争雷霆原始模型，也不是基于实车测绘的工程复刻。图片之间存在差异：侧视图画出七个负重轮，图注为每侧六个；本模型采用每侧六轮。照片未显示的连接件、内部结构和局部尺寸为建模估算。

## 文件

- `ztz99a_high.blend`：可编辑高模，独立机械部件和倒角修改器，纹理打包在文件内。
- `ztz99a_4000.blend`、`ztz99a_2000.blend`、`ztz99a_1000.blend`：三个独立 UV 和烘焙材质的低模源文件，另保留隐藏的 `CAGE_*` 投射笼。
- `../../assets/vehicles/ztz99a/ztz99a_<预算>.glb`：可导入引擎的模型，纹理内嵌。
- 同目录的 `*.manifest.json`：实际整车三角面数、分件面数、贴图尺寸、烘焙说明与文件哈希。
- `renders/`：Blender 实际渲染的整车和炮塔多视图；设计参考图放在 `reference/`，两者不混用。
- `build_ztz99a.py`、`turret_multiview.py`：参数化建模、分组烘焙和导出脚本。
- `verify_assets.py`、`validation/check_assets.gd`：独立 GLB/贴图检查与 Godot 实际加载检查。

`4000/2000/1000` 是整车三角面预算，不是四边面数；包括两侧轮组、履带、炮塔、炮管和全部导出附件。实际数字见 manifest 与验证报告。摄影地面、灯光、高模与相机不计入低模，也不导入 GLB。

## 外形与材质

车体长约 7.6 m、宽约 3.5 m、炮向前全长约 11 m，以多视图标注作为比例依据。Blender 使用米制、+Z 向上、+Y 向前；glTF 导出为 +Y 向上、-Z 向前。

侧裙板、发动机/后部局部和履带基底使用用户提供的固定图集区域。车漆采用确定性的方格迷彩图案；`paint_wear.png` 是从用户图集的无文字装甲区域提取的高频磨损色彩遮罩，使用镜像拼接保留固定内容。它不是法线图。高模中的轮毂、履带链节、格栅、螺栓、边缘倒角和观瞄等具有实际几何。

## 烘焙

Cycles Selected to Active，按车体、左右侧裙、左右履带、左右轮组、炮塔、炮盾、炮管十组分别投射。只选择对应高模源组，避免把炮塔投到车体或把轮组投到履带。

- BaseColor：DIFFUSE 的 COLOR 分量，无摄影灯或场景阴影。
- Normal：高模到低模的切线空间 OpenGL +Y 法线，保留匹配的导出三角化与切线。
- ORM：R 为局部 AO，G 为粗糙度，B 为金属度；通过高模材质的 Emission 通道传递。AO 距离 0.16 m，限同组模型。
- 4,000 预算使用 2048×2048；2,000 和 1,000 预算使用 1024×1024。各 LOD 分别展开、分别烘焙，不能交换法线图。
- 每张图初始化一次，分组写入时 `use_clear=False`。贴图扩边 6 px。
- 低模硬边拆分后生成保持顶点/面索引对应的显式投射笼。轮组挤出 0.28 m、其余组通常 0.12 m；炮塔大部分区域为 0.065 m，烟幕侧区扩大到 0.24 m。最大射线距离为 0.56 m。小箱体附近缩短距离，避免误采前方格栅。投射笼以 `CAGE_*` 命名、默认隐藏，并排除于 GLB。

低面数版本以几何保留轮廓、开口和动作结构；螺栓、格栅、履带链节及轮毂层次主要由烘焙承载。1,000 三角面在近距离的轮廓棱角和细小突出物损失属于该预算的可见取舍。

## 运动轴

```text
hull
└─ turret
   └─ barrel
      └─ gun_recoil
         └─ muzzle
```

左右履带和轮组挂在 hull 下并分别保留。炮塔轴心、炮耳俯仰轴和炮口标记采用米制坐标。这里交付的是资产，未将这款车加入现有游戏，也未建立对应装甲/命中布局或车辆数值。

## 重建与检查

在工程根目录执行；需要 Blender 5.2.1 和本机已有的 Godot 4.7.2。重建会覆盖本资产目录内同名产物；编辑源文件后先另存版本。

```powershell
& 'E:\blender\blender.exe' --background --threads 8 --python-exit-code 1 --python authoring/ztz99a/build_ztz99a.py -- high
& 'E:\blender\blender.exe' --background --threads 8 --python-exit-code 1 --python authoring/ztz99a/build_ztz99a.py -- lod 4000
& 'E:\blender\blender.exe' --background --threads 8 --python-exit-code 1 --python authoring/ztz99a/build_ztz99a.py -- lod 2000
& 'E:\blender\blender.exe' --background --threads 8 --python-exit-code 1 --python authoring/ztz99a/build_ztz99a.py -- lod 1000
& 'E:\blender\blender.exe' --background --python-exit-code 1 --python authoring/ztz99a/verify_assets.py
& 'E:\AIprogram\mcthunder-development\tools\godot\Godot_v4.7.2-stable_win64_console.exe' --headless --path authoring/ztz99a/validation -s res://check_assets.gd
```

最终通过与否以 `verification.json`、`godot_verification.json` 和真实命令日志为准。验证覆盖实际导出的三角面、退化面、UV 范围、法线/切线、贴图内容/尺寸、PBR 通道、层级以及 Godot 内的转炮/俯仰/后坐轴心。它们不等同于实车尺寸认证、人工审美认可或整款游戏验收。
