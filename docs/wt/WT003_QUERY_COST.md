# WT-003 查询耗时归因与首轮优化

## 实际完整局归因

源码01337a2，`tests/run_wt_benchmark.ps1 -Map village -QueryMetrics`。证据`logs/wt003-benchmark/01337a220bdb2d4a75ba1423b79dc57942b375b0/village-20260911-131315`，自然终局、退出0，13110帧，31.587FPS，p95 107.985ms、p99 169.646ms。计时版与未计时版独立留证，不混成一次运行。

175908次ShotQueryService调用累计198829.454ms，相当于47.905%的整局墙钟时间。按相邻30绘制帧快照差分，最重区间墙钟311.213—316.202秒，2852次查询累计3695.768ms，占区间74.077%，区间p95 220.001ms。查询已经是有实测依据的主要热点之一；这不证明所有卡顿只有一个原因，也未证明某一帧中AI观察是唯一来源。

`summarize_wt_benchmark.ps1`新增可选查询窗口分析，验证帧索引与累积计数单调性，输出最重十个区间。窗口跨度30个绘制帧，不能当作逐帧CPU采样；计时不包含快照构建、其他模拟或渲染。

## 生产修改

`ShotQueryService._bounds`将按顶点值缓存的两次字典查找合成一次，减少每个装甲面片重复计算键哈希。`_collect_patches`在一次查询内为每个刚体部件复用局部线段、线段包围盒及单次缓存读取；只在实际接触时取回用于法线与事件的部件变换。未引入跨物理步姿态缓存，保留现有几何筛选、相交、遮挡、失效与去重语义。

## 验证与限制

`tests/run_query_profile.gd`实例化8辆历史车型，128条混合外部/内部射线、425个接触事件，重复7批；比较完整查询输出的SHA256指纹，而非只比命中数量。修改前后指纹均为`e2abd1cdf44031878f87a57730e1dc9c225b37da9399ce14a9bdbfbe88c8c880`。

同一机器、顺序执行、暖缓存下，每128查询平均157.959→147.872ms，降低6.386%。证据`logs/wt003-query/before.json`、`after.json`、`COMPARISON.json`及对应stdout日志；COMPARISON记录被测生产文件和诊断脚本哈希。这是固定几何查询微基准，不是完整局帧率提升百分比。

`tests/run_suite_checks.ps1 -Suites run_query_checks,run_query_cache_checks,run_projectile_checks,run_armor_checks,run_damage_checks,run_ai_combat_checks,run_engagement_distance_checks -Order wt003-query -SourceSha 5591da7-query-wip`：480项、退出0，无脚本错误。证据`logs/wt003-query/5591da7-query-wip/20260911-132135`，覆盖缓存冷/热、几何编辑与淘汰、几何边界/身份/遮挡、实际射击、毁伤和远距瞄准。

尚需修改后完整局帧时间与查询计时。6.4%的局部下降不足以证明已达到60FPS；后续仍需更深入的查询候选筛选/数据复用，且必须保留移动、重生、几何变化和未知结果语义。AI观察是否同tick集中也尚未单独量化，不以猜测修改难度或观察频率。16/32车容量和真人体验未验收。
