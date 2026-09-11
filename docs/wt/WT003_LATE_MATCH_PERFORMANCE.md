# 后期掉帧复现与部件筛选

用户反馈游戏后期帧率很低。本轮优先处理性能，暂缓新增驾驶功能。开发基线2284dd2，村落地图、8AI、1920×1080、相同seed19001、原画质与60FPS上限、启用查询计时。

## 优化前完整局

`tests/run_wt_benchmark.ps1 -Map village -QueryMetrics`，证据`logs/wt003-benchmark/2284dd2d2f6e38ef63bfdea4b1f746365c10758c/village-20260911-141504`，自然终局、退出0。11626帧，34.739FPS，p95 96.639ms、p99 158.922ms。157249次查询累计147539.325ms。

新增`summarize_match_stages.ps1`按每60秒墙钟窗口的快照帧索引切取原始帧间隔，保留窗口实际边界而非伪造整齐分段。开局0.57–59.85秒58.70FPS，240.28–297.61秒降到18.31FPS，后段p95 142.02ms，查询累计占墙钟62.91%。后段峰值1027节点、1个活动弹丸、16条回放、5个残骸。帧率下降有实测，不能只归咎于面数；现有记录不支持弹丸/回放无界累积是主要原因。该判断不排除其他地图和更长游戏的独立问题。

## 修改与验证

ShotQueryService先按刚体部件的局部包围盒，用原生线段相交排除整段未经过的部件，再进入既有逐装甲面精查；模块/乘员查询不改变。每次使用当前部件变换，缺失/非法变换仍先按原规则报告。包围盒只缓存局部几何，最多64份，逐次按顶点值和部件ID比较，不信任未更新的revision。缓存签名和顶点键显式复制PackedVector3Array，修复元素修改可通过引用影响缓存键的问题。

首轮追加的原地几何修改/车辆移动检查出现失败；分别修正测试夹具共享变换字典和缓存签名未独立冻结的问题，失败日志保留。最终`run_query_checks,run_query_cache_checks,run_projectile_checks,run_armor_checks,run_damage_checks,run_ai_combat_checks,run_engagement_distance_checks`共482项通过，证据`logs/wt003-part-cull/2284dd2-cull-final/20260911-142237`。

固定八车128条混合查询、7批计时：关闭部件筛选150.371ms，开启65.412ms，约减少56.5%。两端425接触，完整输出指纹相同`e2abd1cdf44031878f87a57730e1dc9c225b37da9399ce14a9bdbfbe88c8c880`。证据`logs/wt003-part-cull/before.json`、`after.json`与COMPARISON.json中的源码哈希。两次都是本轮代码，只切换part_culling_enabled；不是拿不同玩法场景作微基准。命令为引擎`--headless --path . -s res://tests/run_query_profile.gd -- res://logs/wt003-part-cull/before.json --no-part-culling`及同脚本after.json（不带关闭开关），均退出0。

完整局优化后对照尚待运行，56.5%是查询微基准收益，不是整局FPS增幅。没有减少AI观察频率、删掉碰撞或降低画质。完整目标仍为后期性能改善并继续向60FPS与帧时间门槛推进，不能凭此标记WT-003完成。
