# 服务器权威状态表与协议版本（WT-024-R1）

- 依据：`03_全部42项目标工作单.md` WT-024（行 985-1023）
- 实现：既有 `scripts/network/`（真实回环 ENet：`peer.set_bind_ip("127.0.0.1")`、最多 2 客户端）+ 本轮新增 `scripts/network/network_authority_contract.gd`（把信任边界变成**可断言的数据**）
- 验证：新增 `tests/run_network_authority_checks.gd`（**62/62 PASS**）+ 既有 10 个网络套件重跑 + **三进程真实端到端**

## 1. 协议版本（全部取自实现，未自行发明）

| 维度 | 版本 | 来源 |
|---|---|---|
| 会话/快照网络协议 | **6** | `VehicleFramePose.NETWORK_VERSION`（注释：Per-tile reactive armor state） |
| 事件日志（journal） | **1** | `NetworkEventJournal.VERSION` |
| 命令契约 | **3** | `VehicleCommandCodec.VERSION` |
| 帧姿态切片 | **1** | `VehicleFramePose.VERSION` |

## 2. 服务器权威状态表

| 领域 | 归属 | 权威字段（摘要） |
|---|---|---|
| `match` | **server** | phase / elapsed / tickets / result / round_id |
| `objectives` | **server** | owner / progress / contested / owned_seconds |
| `vehicles` | **server** | position / rotation / life_id / generation / module_states / crew / fires |
| `ammunition` | **server** | chamber / racks / aux_pools / smoke_stock |
| `damage` | **server** | armor / penetrations / destruction |
| `world` | **server** | buildings / smoke_clouds / wrecks |
| `session` | **server** | owners / entity_mapping / life_mapping / round_mapping |

**结构性保证**：权威字段**不含任何显示资源**（套件扫描 `scene/mesh/visual/material/texture/tscn` 令牌，全部不出现）。

## 3. 客户端信任边界（可审计的拒绝原因）

| 客户端可发 | 说明 |
|---|---|
| `hello` / `command` / `baseline_ack` / `events_ack` / `events_request` / `final_ack` | 唯一合法的玩法输入是 **command**（`command_is_the_only_gameplay_input`） |
| 其它任何消息 | `unsupported_message` |

**客户端绝不可提交的字段**（命中即 `client_cannot_author_state`）：
`result` · `tickets` · `kills` · `deaths` · `position` · `rotation` · `ammo` · `chamber` · `cooldown` · `damage` · `module_states` · `objective_owner` · `smoke_stock` · `repair_amount` · `instant_repair` · `life_id`

既有服务端实现同时在协议层校验：包长上限 4096 B、每 tick ≤4 包、握手先行、`envelope.entity_id` 必须等于该 peer 拥有的车辆（否则 `not_owner`）、会话结束后 `session_finished`、基线未确认前 `baseline_required`、最终 `final_ack` 必须匹配结果摘要。

## 4. 跨进程身份映射与重连

| 规则 | 实现/实测 |
|---|---|
| 一 peer 一车 | `assign()`：同一实体被他人占用 → `entity_already_owned`（实测第三个 peer 无法窃取） |
| 重连复用同一车 | `resume()`：同实体 + 新 `life_id` → 成功，且**可控制车辆数不变**（不会生成第二辆） |
| 不允许顶替 | `resume()` 实体不符 → `entity_mismatch_on_resume` |
| 释放即回收 | `release()` 释放该 peer 的实体并允许重新分配 |
| 服务端断线处理 | 既有 `disconnect_owner()`：清空命令 + `set_controller(null)` + 释放控制器 |

## 5. 多进程真实端到端（本轮实测）

**编排**：`run_network_slice.gd -- server 19121 <out>` + 两个 `-- client 19121 <out>`（**三个独立 Godot 进程**）。

| 进程 | 结果 |
|---|---|
| 服务端 | `NETWORK_SLICE_SERVER_PASS` |
| 客户端 1 | `NETWORK_SLICE_CLIENT_PASS` |
| 客户端 2 | `NETWORK_SLICE_CLIENT_PASS` |

**两客户端观察同一次结果**（正是 WT-024 验收第一条）：

| 字段 | 客户端 1 | 客户端 2 | 一致 |
|---|---|---|---|
| 拥有车辆 | `B` | `A` | **不同**（各控一车，符合预期） |
| 结果摘要 digest | `e2d3b8a6…` | `e2d3b8a6…` | **相同** ✓ |
| 会话 id | `b4ddf437…` | `b4ddf437…` | **相同** ✓ |
| 事件序号 | 8 | 8 | **相同** ✓ |
| passed | true | true | ✓ |

（两份报告**哈希不同是正常的**：各自 `entity`/own_status 不同；关键证据是摘要与序号一致。）

## 6. 缺显示资源不影响权威（本单实测）

| 事实 | 证据 |
|---|---|
| 仓库内 113 个研究模型**无 `.import` 伴随文件** | `ResourceLoader.exists("res://assets/research/models/ussr_t_80b.glb") == false`，但**字节文件存在** |
| 权威数据独立可用 | `VehicleCatalog.IDS` 4 辆；`configs/vehicles/model_sources.json`、`configs/optics/m4a3_design.tres`、`assets/research/soviet_german_tree.json` 均可读/可加载 |
| 权威字段无显示依赖 | 权威字段扫描不含显示类令牌（见 §2） |

## 7. 既有网络套件重跑（本轮）

| 套件 | 结果 |
|---|---|
| `run_network_controller_checks` / `run_network_frame_checks` / `run_network_pose_checks` | 11 / 21 / 26（0 失败） |
| `run_network_event_journal_checks` / `run_network_event_recovery_checks` | 64 / 58（0 失败） |
| `run_network_fire_control_checks` / `run_era_network_checks` / `run_suspension_network_checks` | 35 / 22 / 9（0 失败） |
| **合计** | **246 项 0 失败** |
| `run_network_slice`（需角色参数） | **三进程真实运行 PASS ×3** |
| `run_network_view_checks`（需已有服务端） | **部分**：对接 19111 服务端后前 2 项 PASS（收到分配车辆 / 第二 peer 拥有不同车辆），随后套件未结束 → 记 `NOT_RUN`（未完成） |

## 8. 未完成 / 需授权（如实）

- **独立服务器/客户端导出配置**（父项交付物第二条）：当前 `export_presets.cfg` 只有 `Village Resource Check` / `Windows Team Slice` / `Windows Release`，**没有 server/client 专用预设**。新增预设属于**修改构建/发布流程**（用户红线）→ **本单不动手，明确请求授权**。
- WT-025 预测/插值/延迟一致性：属下一单（本轮未做）。
- 真实"杀掉客户端再重连"的端到端场景：既有 journal/recovery 套件覆盖基线恢复与历史淘汰，但**未做真实进程级断线重连** → `NOT_RUN`。
- 公开部署：明确不做（未授权不公开）。
- 性能 `HOLD_BY_USER`（未采集带宽/帧率）；真人 `NOT_RUN`。
