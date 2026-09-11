# 逐帧长帧归因与采样暂停保护

开发基线836ca28。用户后期掉帧优先事项继续进行，完整游戏目标未缩减。

工业区首次运行`logs/wt003-benchmark/836ca2827d52482a53773fa8088c283f2eb2828e/industrial-20260911-144157`显示墙钟持续增加、比赛时间长期固定0.7167秒，不能作为有效对局性能。基准脚本未设置已有unattended_diagnostic，已主动结束本次自己的Godot子进程，RESULTS明确passed=false。没有把未结束进程误判成已结束，也未把其近60FPS当成功数据。

修正仅限诊断脚本：场景创建前设置unattended_diagnostic=true，保留正常游戏失焦暂停；每次绘制后检查树/场景暂停，检测到则保留部分数据并返回失败。进度现在显示两个暂停字段。`--inject-pause`是诊断反例参数，1秒后调用场景真实暂停。证据`logs/wt003-frame-attribution/pause-negative`记录57帧后退出1、termination_reason=paused_during_measurement。

开启QueryMetrics时，新增每个绘制帧的查询次数/累计查询毫秒/物理tick差分，另按原有query_id前缀记录aim_/proj_/fragment_/other来源计数。other不直接等同AI。普通游戏未开启测量时不运行这些计时/分类逻辑。新`summarize_frame_spikes.ps1`检查逐帧、来源分类与整局计数/耗时相符，再列出最慢20帧及多物理步长帧数。

`run_query_checks`140项通过；新增`run_query_metrics_checks`5项验证关闭计时不累积、开启计时不改变查询返回、四类计数与总耗时相等。分别留证`logs/wt003-frame-attribution/836ca28-attribution-wip/20260911-144523`与`836ca28-attribution-final/20260911-144623`。

15秒工业区probe `industrial-20260911-144630`生成逐帧记录并通过计数对账，但期间查询数为0，runner按原规则判passed=false；它只证明短时间采样结构可读，不是完整局性能或查询归因成功。随后应执行带新计时的完整局；该诊断开销与旧仅累计计时版本分开记录，不能不加说明混成完全相同采样条件。
