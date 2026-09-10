# 当前接续位置

用户要求继续完成主线、之后细化。工作树 E:/AIprogram/mcthunder-mainline，分支 codex/mainline-027-continuation。不要动其它工作树/main，不公开发布，不代签真人，不使用子代理。

rc.1 运行源码 9998f4483637ad5d0b73ca23060e235b46f908c2 已完成干净构建：39套2786项，独立内容34/窗口35，全包玩家流程80项。稳定包 E:/AIprogram/PixelArmor交付/1.0.0-rc.1-9998f448，身份和完整证据见 DELIVERY_031/034。此包保留，不覆盖。

rc.1 正式性能尝试 logs/033/9998f4483637ad5d0b73ca23060e235b46f908c2/20260910-180606 在首个300秒场景后出现诊断回放失败，约7分钟时主动停止，退出1，STOPPED.json及不完整报告已保留。最后一条合法记录可能是没有目标几何的未命中，不能自动假设能播放。已加入 ShotRecordStore.latest_replayable_index，真实命中+真实未命中+不完整记录的6个反例新增后，run_replay_checks共73项通过。性能诊断改选可播放记录并记录所选索引/最新帧数/失败原因，长周期仍要求实际回放。当前准备1.0.0-rc.2新提交、全新全量构建与最终程序玩家流程/30分钟长测，未完成前不能声明033通过。

032修正测试姿态：旧actor禁用不影响显式PAUSABLE子节点，矩阵跨运行有307个数值字段差异。666aea98dff5be17cc482b190661a201d1c0156b冻结所有子节点。优化前24ebb87查询文件与当前查询实现分别18项通过；完整1536发JSON逐字节一致，SHA256 3B90E05682868BDD67D0CDA8C680AD74BC1C4EC094D2BAB6EAE54A9A86A09940。logs/033/fixed-matrix-comparison与docs/evidence/032/fixed-pose为最新证据；结果仍1536接触/962毁伤/AP90与APHE140优势点。八局自然赛32项通过，原来源29fd4ae，不冒充最终RC同源。

当前文档提交 a056411，rc.1构建/矩阵/自然赛/最终流程证据已提交。ASSET_REGISTER/RELEASE_DESCRIPTION/PATCH_PROTOCOL/HUMAN_ACCEPTANCE/DELIVERY_035已准备。QA_REPORT_RC、GAP_REGISTER_RC与authoring/analyze_performance.py仍待最终结果；PROJECT_PROGRESS当前到033，最终需更新031—036和GATE_E/DELIVERY_033/036/冻结清单。

性能默认命令 tests/run_performance_checks.ps1 -Executable <最终包exe> -SourceSha <最终运行SHA>，1800实际秒/至少20场景生命周期，非20完整比赛。只单独运行，不并行其它Godot。Blender进程保持原样，记录背景CPU前后。Godot Release static_memory=0表示监视器不可用，实际内存用Windows private_bytes/working_set。rc.1部分采样平均46.6FPS、查询CPU143/423秒，仅诊断定位，不能当30分钟结论或宣称60FPS达标。

下一步：新候选全量构建完成后验证PACKAGE/文件哈希/实际图片，复制新独立目录；新包完整80项玩家流程与30分钟性能分别运行，分析完整报告后交付本地RC和035—036技术记录。所有未做真人、跨机/DPI/只读ACL/断网/公开素材权利保持PENDING/NOT_RUN。保留失败，勿降低断言或改伤害来过测。

后续细节：车体侧射冲量、阻尼悬挂未做；当前枪管视觉后坐、火光/音效。最终720p截图有P2结算字幕重叠和HUD遮车问题，已登记。99A资源 E:/AIprogram/mcthunder/authoring/ztz99a/delivery/ZTZ99A_HIGH_AND_BAKED_LODS.zip，高模和3996/1988/989烘焙LOD，炮塔以99A多视图为准，真人验收未代签。
