# WT-002 物理阶段与内部快照

基于a906572的开发批次。生产优先级集中到SimulationPhases：车辆0 → 弹丸100 → 补给/交通200 → 比赛规则300 → 内部状态快照400。原本弹丸与director已有100/300；本批保留既有顺序，不把它们误称为新增。普通TeamRange此前默认0，只有训练演示才设200，因此普通补给可能先于车辆当步命令。

玩家变化：刚开始驾驶时，正在计时的停车补给立即按当步操作中断，不能在同一物理步先补一发再读取移动。实例化真实团队场景、仅提供位于原点的补给区，设置剩余补给计时接近两秒并提交真实油门命令：当前顺序通过；测试参数--old-supply-order恢复旧优先级后，该项明确失败。不是通过改补给间隔或放宽断言修复。

SimulationSnapshot v1由比赛规则之后的独立节点发布，含sequence、physics_tick、match_id、phase、elapsed、tickets、据点状态、结果，以及各车生命周期/控制纪元、姿态、速度、炮塔/炮管角、发射计数、装填、弹药、毁伤能力。按entity_id排序，仅保留最新一个，读取深拷贝；暂停不递增，结束保留一个最终快照，避免每帧反复复制结算事件。

这是内部权威观察快照，不是JSON网络协议；Vector3/Basis仍为原生值，不包含完整模块/乘员细节，也没有权限裁剪，禁止直接作为向所有客户端广播的全知消息。ShotRecordBuilder原有schema和armor/damage/recovery规则版本保留，不为统一名称改坏旧回放。MatchEvent版本与跨系统消费确认仍待补齐。

## 证据

实际脚本：tests/run_simulation_phase_checks.gd。命令：`godot --headless --path . --fixed-fps 60 -s res://tests/run_simulation_phase_checks.gd`。8项通过（logs/wt002-phases.log），包括当步补给、当步姿态/武器/票池、深拷贝隔离、暂停、同一步时间结束与最终快照稳定。时间结束使用边界夹具，绝非自然完整比赛。旧顺序反例见logs/wt002-phases-counterexample.log，一项失败。

团队67项、弹药185项通过，tests/run_suite_checks.ps1的完整结果见logs/wt002-phases/wip/20260911-115456。村庄测试超过本次120秒墙钟上限，随后runner读取stdout遇到文件占用，未生成完整村庄结果行；输出仅到约50秒仿真观察，不能算该套通过。事后Get-CimInstance核对无存活Godot进程，可在下一轮提高合理运行上限后重测，并修复runner的超时日志读取。均是开发树验证，非新独立包验证。ObjectDB退出警告仍保留。快照的整局性能开销尚未测量，不宣称达到WT-003性能门槛。

## 后续

2026-09-11 接续复测：游戏源码0ff23f3，测试runner仅修复日志读取；`run_suite_checks.ps1 -Suites run_village_battle_checks -Order wt002-village -SourceSha 0ff23f3-runner-wip -TimeoutSeconds 600` 已退出0，21项全部通过。完整输出及RESULTS.json位于 `logs/wt002-village/0ff23f3-runner-wip/20260911-120122`。七辆AI均到达中央接近区域，120秒自然仿真、真实弹丸地图遮挡及重开/回车库通过。600秒是墙钟上限，不是完整自然比赛时长；不覆盖整局性能门槛。

runner以共享读取方式读取仍有重定向写入句柄的日志；无法读取时记录log_read_errors并令该项失败，继续落盘结果。`tests/run_suite_log_checks.ps1`两项通过；零秒超时反例 `logs/wt002-timeout-probe/runner-wip/20260911-120201/RESULTS.json` 正确记录timed_out=true、passed=false并退出1。这是预期超时夹具，不是游戏回归失败。上面的首次超时及异常记录保留。

同优先级车辆仍按节点顺序更新，玩家意图快照查询可能看到其它车的不同更新阶段。本批没有解决所有车辆先统一输入/再统一运动的全局两阶段模型。继续补输入与观察采样契约、MatchEvent版本、同步/重连所需快照字段、移动目标与长帧验证；WT-002仍在进行。
