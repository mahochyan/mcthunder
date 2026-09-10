# RC 素材登记与发布边界

这是本地候选的技术清点；不代替权利持有人决定公开发行权限。

| 运行资源 | 来源与处理 | 随包说明 | 对外状态 |
|---|---|---|---|
| Godot Windows Release 模板 | 固定官方 4.7.2-stable，MIT 及其依赖许可 | 构建从实际引擎导出 GODOT_LICENSES.txt | 保留完整许可文本 |
| NotoSansCJKsc-Regular.otf | Noto Sans CJK SC，SIL OFL 1.1 | FONT_OFL.txt；PCK 内同时保留 OFL.txt | 许可文本已保留 |
| 四车型 GLB | 项目 Blender 程序几何和车型调整，逐车 manifest 绑定原件/GLB/图集 SHA256 | 素材与许可.md；运行 manifest | 几何来源可追踪；参考图权利需持有人确认 |
| vehicle_concept_atlas_v1.png | ImageGen 根据用户提供的 M4 风格参考图生成共享图集 | 各车型 manifest 保留 texture_origin | 参考图对外权利 PENDING，不按原创标签自动批准公开使用 |
| GLB 导入器生成的车型 PNG | 从上述 GLB 内嵌图像抽取的运行依赖 | 随模型导入打包 | 同共享图集权利状态 |
| 两图建筑/地面/掩体/道具 | 项目 GDScript 程序几何与材质 | world_art.manifest.json | 原创来源登记；哈希随构建复查 |
| 履带 shader、配色表、图标 | 项目代码/资源 | 随项目说明 | 不代表已选择公开商标 |
| 13 份 WAV | 项目数学合成，无第三方录音采样 | assets/audio/manifest.json | 来源和生成器、每文件 SHA256 齐备 |
| 简体中文文本、教学、挑战说明 | 项目编写，按实际规则展示 | 随游戏 | 不宣传未实现的联网或实车级仿真 |
| 历史车型与弹种数据 | 逐字段引用史料，几何估计/游戏近似/未知分别记录 | 车库资料界面与 configs | 不把估计值或“verified”标签当作外部权利授权 |

`authoring/audit_release_source.py` 只读扫描 Git 跟踪的文本，发现候选凭据时仅打印位置和种类，不输出值；同时复算四车 GLB 哈希并检查字库许可。大文件和二进制按清单排除于文本模式扫描，扫描不宣称可发现所有秘密。运行包完整路径清点由 `--verify-installation` 执行，拒绝 authoring、tests、docs、tools 和额外二进制资源混入 PCK。

原始建模文件、用户参考图、史料 PDF、旧开发日志、引擎安装包与 99A 建模交付不在四车首版包内。公开源仓库和游戏二进制是两种分发面，原始参考素材不能因游戏候选能运行就自动获准上传。

当前允许本地构建和试玩准备；没有创建公开 Release、购买服务或提交商店。作品名称、公开介绍、参考图来源权利和真人接受均留给用户确认。
