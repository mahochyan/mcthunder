# 当前接续位置

用户授权：继续完成主线，之后细节优化。工作目录 E:/AIprogram/mcthunder-mainline，分支 codex/mainline-027-continuation；不合并 main、不公开发行，真人验收 PENDING。

028/029 已完成。031 固定源码 e3b3755 的全新构建已通过全部 36 套 2759 项、资源导出和工程外 headless 检查；窗口第二图因失焦暂停而失败，失败与原包保留于 logs/031/e3b3755c0146756aabd059081b6ec970ba836f71/build-20260910-161957-409。未标记它为已交付包。安装验证器现通过正常 Esc 输入恢复暂停并等待真实倒计时，两图驾驶/射击窗口预检 35/35 通过（logs/031/installation-resume.*）。

032 工具提交 29fd4ae。四车两弹种1536发真实几何/伤害矩阵14项通过，数据及汇总在 docs/evidence/032/matrix、logs/032/29fd4ae144dbb656fcc4361ecbb4450931c90389/matrix。八局正常难度、固定种子、交换两队随机误差序列的自然比赛仍运行（会话37055，logs/031/balance-matches-probe.log，数据logs/032-wip/matches）；源为29fd4ae提交前的相同比赛工具，后续0033文件变更并非这批运行源码，不能冒充最终RC同SHA测试。

033 测量工具24ebb87，查询缓存优化36abe97。真实Release三分钟计时预检在C:/Users/lapyin/AppData/Roaming/Godot/app_userdata/PixelArmor/tests/performance033_1789030014/performance.json；与其他测试同时运行，只用于定位。Godot Release的静态内存计数不可用，正式测量用tests/run_performance_checks.ps1记录Windows进程PrivateMemorySize64/WorkingSet64。正式30分钟/20生命周期测量尚未运行。查询缓存9项几何变更/淘汰检查通过；优化后1536发原始JSON与优化前逐字节相同（SHA256 AC6FABD294E72B45E998677EB7F96BB731012F78D0C306389CCC082532592FCA），记录在logs/033/36abe97/golden-matrix。查询旧套存在基线ObjectDB退出警告，未虚称完全无警告。

当前准备1.0.0-rc.1源码候选，全新完整构建包含新增矩阵/缓存/日志预算检查，预期39套2786项，必须以真实结果为准。下一步提交安装验证与RC版本，运行tests/build_release.ps1；成功后填写DELIVERY_031，结束032比赛报告并冻结规则，再单独跑Release性能长测（勿同时运行其它Godot压测）。完成033后使用该固定RC的证据落实034回归、035许可资料和036技术交付。035源码/素材预检工具已准备，参考图对外权利仍PENDING，不代签。

车体后坐、悬挂、火光细化、更多车型及99A集成均在主线后。原99A资源：E:/AIprogram/mcthunder/authoring/ztz99a/delivery/ZTZ99A_HIGH_AND_BAKED_LODS.zip。
