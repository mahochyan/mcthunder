# WT-002 比赛事件身份与提交边界

基于7207acd。TeamMatchState的生产record入口给既有spawn/death事件补schema_version=1、match_id、单局连续sequence和Engine物理tick，保留kind/time及原负载字段。元数据在负载复制后写入，调用者不能覆盖身份。128条历史上限保持不变，淘汰旧记录不回退序号；事件身份由match_id与sequence共同确定。

倒计时真正结束后提交match_started，再发round_started信号。finish_once在构建结果和发match_finished信号之前提交终局事件，其负载保存最终票池、结果与原因。结果及物理阶段400的内部快照同时带event_sequence，因此可识别状态已经包含到哪条比赛事件。重复击毁不重复扣票、重复finish不重发原本已有保护；本批验证并保留这些行为，没有把既有保护冒称新修复。

这是内部比赛事件契约的首批字段，尚非完整网络协议：没有断线补发、消费者确认、历史缺口恢复或观察权限过滤。128条环形记录不是完整对局回放；ShotRecord规则版本不变。占点变更等更多事件类型及按类型负载校验仍待扩展。全车分阶段调度及整局性能验收也未完成。

## 验证

游戏生产改动相同，首轮runner `logs/wt002-events/7207acd-events-wip/20260911-120752` 中阶段8项与团队67项通过；新增测试首次因局部变量缺Dictionary声明解析失败，完整失败输出保留。

新增事件专项r2完成11项，其中同物理步取样失败：测试跨process_frame读取最新快照，低帧率下可能跨过多个物理步。固定帧率60的诊断运行11项通过，随后将正式断言改为在快照之后的物理节点捕获包含该事件的第一份状态，仍要求事件tick与该快照tick完全相等，没有放宽容差。

最终命令：`tests/run_suite_checks.ps1 -Suites run_match_event_checks -Order wt002-events -SourceSha 7207acd-events-r3 -TimeoutSeconds 300`。退出0，11项通过，无SCRIPT ERROR或非预期ERROR；完整日志和RESULTS.json在 `logs/wt002-events/7207acd-events-r3/20260911-120958`。覆盖真实八车生成/倒计时、击毁提交与重复通知、终局事件和快照边界、重复结算、结果拷贝隔离、新比赛身份，以及生产record入口的负载隔离和128条淘汰。击毁及时间结束使用明确边界夹具，不宣称自然完整比赛。既有布局粗AABB警告及出现的ObjectDB退出警告保留，未当成性能或泄漏验收。
