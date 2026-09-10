# 当前接续位置

用户：继续完成主线，之后做细节优化。工作目录 E:/AIprogram/mcthunder-mainline；分支 codex/mainline-027-continuation。不要覆盖其他工作树，也不要合并 main 或公开发布。

028 教学已提交 612170e；029 设置恢复已提交 8233165。031 构建脚本初版 b4de990，全新缓存全量跑了 36 套 2759 项，发现 4 个失败套，构建正确停止，未交付正式 ZIP。

当前未提交修复：正式模板不支持外部 -s，改为隔离的 --verify-installation 入口，32 个 headless/33 个真实窗口预检通过；保留 GLB 导入器生成的必需 PNG；工业测试预加载正常主场景解决资源退出占用（5 项复测通过）；027 本地化修改了两处地图脚本，已经核对差异并更新来源哈希（美术 55 项复测通过）。

已修复并复测：山村原七 AI 到达检查。原路线横穿相邻停车位，A2 被静止玩家挡住后往返。VillageDefinition 为每个出生位新增左右两条 departure 路线，先驶出停车排 12 米再并入道路；AIPathDriver/DriveNavigator/AITankController 的诊断性修改已全部恢复为 b4de990，仅保留地图修复。当前 logs/031/village-departure-r2.log 为 21/21 通过；map-departure-r2.log 为 27/27（1786 道路包络样本零失败）；historical-departure-r2.log 为 17/17。旧尝试/失败保留，不能把失败记录改成通过。

下一步：提交 031 修复并重新运行 tests/build_release.ps1 的固定提交全量构建。脚本会在工程外中文空格路径解压，用实际 Release 模板验证内容与窗口，并写 manifest/ZIP/校验值。最终 DELIVERY_031 必须填写真实 SHA/包路径/测试出处，不复用 WIP 预检冒充最终包。

随后继续 032 平衡矩阵与交换阵营筛查、033 性能/长局、034 回归、035 许可与发行资料、036 技术交付。真人/历史来源未验项保持 PENDING，不代签。车身后坐、悬挂和火光优化延后。
