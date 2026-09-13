# 网络时间模型与补偿设计（WT-025-R1）

- 依据：`03_全部42项目标工作单.md` WT-025（行 1027-1065）
- 实现：新增 `scripts/network/network_time_model.gd`（四时钟与纠正策略）+ `scripts/network/network_fault_injector.gd`（条件注入与纠正记录）
- 验证：新增 `tests/run_network_fault_checks.gd`（**42/42 PASS**）+ 回归 `run_network_pose_checks` **26/26**、`run_network_frame_checks` **21/21**、`run_network_event_recovery_checks` **58/58**

## 1. 四个时钟（分离且各有界）

| 时钟 | 含义 | 边界 |
|---|---|---|
| `input_tick` | 本地玩家产生输入的时刻 | 历史 ≤ **32** 条 |
| `server_tick` | 权威消费该输入的 tick | **只增不减**（陈旧 ack 不能回退，实测） |
| `snapshot_tick` | 收到的快照描述的权威 tick | 同样只增不减 |
| `display_tick` | 观众实际看到的插值时刻 | 落后最新快照 **6 tick**（= 生产 `NetworkPoseBuffer.DELAY_TICKS`），渐进追帧、**永不超过目标** |

## 2. 补偿与纠正策略（明确边界，不夸大）

| 项 | 取值/策略 | 说明 |
|---|---|---|
| 插值延迟 | **6 tick** | 与生产姿态缓冲一致（套件断言两者相等，防漂移） |
| **外推** | **不支持**（上限 0） | 缺包时呈现**冻结**而非编造运动；`extrapolation_supported() == false` |
| 本地重演窗口 | **6 tick 距离** | 仅重放未确认且在窗口内的输入；**不回溯整场世界** |
| 有限弹速补偿窗口 | **6 tick** | 与插值延迟同阶，有界；**不无限回溯历史状态** |
| **结算归属** | **`server`（唯一）** | 客户端反馈为呈现；同一发弹不可能既按客户端即时命中又按服务端飞行结算 |
| 预测反馈 | `predicted_feedback()` 立即播放 | 被权威拒绝时 `reject_feedback()` 标记纠正，**`kills_credited` 恒为 0** |
| 纠正记录 | `corrections[]` | 每条含 kind / reason / corrected / 已记击杀数 |

## 3. 条件注入与纠正事件（交付物第二条）

`NetworkFaultInjector`：**延迟 / 抖动 / 乱序 / 丢包**作为**测试输入**，同种子同条件必得同一调度；每次施加的故障都写成纠正事件。

| 注入条件 | 实测结果 |
|---|---|
| `seed=7, delay=2, jitter=3, reorder=2, loss=25%` | 同一条件两次调度**完全一致**；24 包中丢包使实际投递更少；**每次丢包各记一条 loss 纠正** |
| `loss=100%` | 投递 0 包，纠正记录数 = 包数（如实全记） |
| `delay=4` | 每包 `deliver_at ≥ index+4`（延迟逐包生效） |
| `delay=1, jitter=4, reorder=4` | 投递顺序**真的乱序**（出现 index 逆序），并记录 reorder 纠正 |
| 条件标签 | `delay=2 jitter=3 reorder=2 loss=25.0%` 可写入证据日志 |

## 4. 与既有实现的对接（实测，未重复造轮子）

| 既有能力 | 证据（本轮重跑） |
|---|---|
| 有序快照入缓冲、中点插值、角度按最短弧 | `run_network_pose_checks` 26/26 |
| **缺包冻结不外推** | 同上：`missing packets freeze at latest position without extrapolation` |
| **乱序/重复快照不回卷** | 同上：`late or duplicate snapshot cannot rewind timeline` |
| **新生命直接切换、不跨旧路径插值** | 同上：`new life snaps instead of crossing old vehicle path` |
| 相对帧姿态在真实传输下保持 | `run_network_frame_checks` 21/21 |
| 基线恢复与历史淘汰 | `run_network_event_recovery_checks` 58/58 |
| 生产快照有效性门（缺字段即拒） | 本套件：`valid_snapshot({}) == false`、缺会话/时钟即拒 |

## 5. 验收对照

| 验收要求 | 证据 |
|---|---|
| 重复/过期输入不重复射击或移动 | 本套件：重复/陈旧 ack **不改变任何状态**、`accepted_sequence` 单调、重演仅限窗口内；命令侧另有 `run_command_contract_checks`（35/35，身份陈旧命令被拒） |
| **快照乱序不会把新生命拉回旧位置** | `run_network_pose_checks`（乱序不回卷 + 新生命切换）26/26 |
| **客户端先播反馈后被拒绝时能纠正且不产生假击杀** | 本套件：预测→拒绝→`corrected=true` 且 **kills_credited=0**；未预测的拒绝如实记为未纠正 |
| 声明可支持的网络条件有对应运行证据 | §3 表（延迟/抖动/乱序/丢包均有实测）；**未测条件一律标 `NOT_RUN`**（见 §6） |

## 6. 明确不做 / 未验证（如实）

- **不声称"开启 ENet 即自动具备预测/回溯"**：本设计明确**不做外推**、补偿窗口仅 6 tick。
- **未做**：真实进程级端到端注入（把注入器接进 `network_battle_client/view` 的传输路径）→ `NOT_RUN`；当前注入器为**测试输入与纠正记录**用途。
- 未声明任何带宽/负载/帧率结论（性能 `HOLD_BY_USER`，且本单不做吞吐采样）。
- 烟幕/建筑在网络变化下的专项回归：属后续（本轮 `run_era_network_checks` 22/22 覆盖反应装甲网络态；烟幕网络同步尚未实现——WT-018 的烟云目前是权威本地对象）。
- 真人 `NOT_RUN`。
