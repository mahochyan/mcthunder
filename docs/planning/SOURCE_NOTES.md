# 资料与核验边界
核验日期：2026年9月7日。除以下工具/仓库事实，具体玩法、初始数值、范围、验收门槛均为本计划的设计选择。

R1 用户仓库根目录、AGENTS.md、docs/DELIVERY_001.md；使用GitHub连接读取。
仓库：mahochyan/mcthunder；当时main引用29376e20e5675bd15747ac4bfd6b24382d6c3b15。
本轮只阅读资料；报告中的测试、显卡、运行效果未由本轮独立重跑或现场确认。

S1 Godot官方：4.7.2稳定版存在，可用于核对仓库所报版本；本地二进制仍需--version确认。
`https://godotengine.org/download/archive/4.7.2-stable/`

S2 Godot官方Resources：资源是数据容器，同一资源可能被复用，所以本计划将实例可变状态分开。
`https://docs.godotengine.org/en/stable/tutorials/scripting/resources.html`

S3 Godot官方Ray-casting：物理空间访问、射线查询、排除与掩码；固定物理阶段的安全调用需遵守实际版本。
`https://docs.godotengine.org/en/stable/tutorials/physics/ray-casting.html`

S4 Godot官方Command line：无窗口运行、检查、导出入口；命令参数以本机--help为准。
`https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html`

S5 Godot官方Exporting projects：导出需要模板/预设，资源包不等于可执行游戏，凭据配置不应提交。
`https://docs.godotengine.org/en/stable/tutorials/export/exporting_projects.html`

S6 Godot官方Saving games：user://文件存储、ConfigFile用于设置、JSON的类型限制。
`https://docs.godotengine.org/en/stable/tutorials/io/saving_games.html`

S7 Godot官方Internationalizing games：文本资源、字体覆盖、可伸缩布局。具体API按已固定4.7.2核对，不能照搬不同版本示例。
`https://docs.godotengine.org/en/stable/tutorials/i18n/internationalizing_games.html`

S8 Godot官方许可说明：发行前核对实际许可和署名要求；不代表所有第三方资源已获授权。
`https://godotengine.org/license/`

本包不附带任何字体、游戏美术、音效、引擎、源工程或可执行程序。
没有虚构FPS、玩家评价、测试日志或签收记录。TEST_MATRIX和状态表中的未执行标记是真实当前状态。
