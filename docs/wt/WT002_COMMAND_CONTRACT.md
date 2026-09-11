# WT-002 命令契约 v1

目的：让真实玩家与AI的轮询操作，在进入原有唯一命令邮箱前拥有明确身份、顺序和时刻。未来网络控制器复用此入口，但本批没有网络传输、认证、客户端预测或服务器构建。

## 数据与执行

VehicleCommandCodec v1只接受八个顶层字段：version、entity_id、life_id、generation、control_epoch、sequence、input_tick、command。command包含现有油门/转向/瞄点/炮镜/开火/换弹/恢复意图，不接受命中、击毁、奖励或补充弹药的声明。布尔字段必须是布尔；数值必须有限且符合范围；JSON整数经整数性与安全范围检查后再规范化。未知字段与版本拒绝。

VehicleActor.submit_command_envelope先验证数据，然后验证本车身份、生命与控制纪元、递增序号及输入时刻。未来tick和超过12物理步的输入拒绝，12来自GameConfig，是当前本地契约参数，不是未来网络延迟补偿承诺。只有原submit_command成功复制进邮箱后才更新接受序号；坏包不能用大序号阻断后续合法输入。返回accepted_tick指接受时刻，不是声称已经消费或命中。

暂停阻塞、清命令、重置与设置控制者会更新控制纪元。旧纪元中的尚未送达操作拒绝，原邮箱清理仍生效。玩家和AI在Actor物理回调poll后编码并经相同入口；本地代码直接submit_command仍作为受信任脚本/测试接口保留，不能暴露为远程RPC。当前input_tick为Actor轮询的物理时刻，不是操作系统事件采样时间戳。

## 验证

开发基线ee49542；专项 `tests/run_command_contract_checks.gd`，命令 `godot --headless --path . --fixed-fps 60 -s res://tests/run_command_contract_checks.gd`，21项通过（logs/wt002-command-contract-r2.log）。涵盖真实JSON往返、真实邮箱驾驶与一次发射、调用者随后修改原字典不影响消费、重复序号、错误版本/生命/纪元、未来/过期tick、越界油门、假布尔、NaN、非法结果字段、暂停/重置/解绑/清空后的旧包。初次失败日志保留：JSON浮点形式的-1原先被整数数组成员检查拒绝，已修正合法整数规范化；另一个测试把重置回出生点误算成传送，断言现放在实际命令消费后、重置前。

实际玩家/AI接入后的回归证据：logs/wt002-command/wip/ 下保存引擎命令、退出码与结果。该批为开发工作树验证，不是独立服务器或联网可信性验收。

## 剩余要求

输入来源认证/每发送者速率预算、网络时间轴及允许延迟政策属于WT-009/025/026；ShotRecord/MatchEvent/SimulationSnapshot版本统一、消费确认和世界级调度仍待WT-002接续。当前安全检查不能代替网络拥有者验证，也不能宣称已完成多人游戏。
