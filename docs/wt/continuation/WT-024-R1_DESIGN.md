# WT-024-R1 设计页（正式服务器权威团队战斗）

- 对应父项：WT-024（前置 WT-009、WT-022）
- 依据：`03_全部42项目标工作单.md` 行 985-1023

## 1. 现状核查（实测，先核实再补）

| 要求 | 现状 | 处置 |
|---|---|---|
| 服务器拥有比赛/车辆/弹药/毁伤/占点/建筑/烟幕/残骸 | **已实现**：`network_battle_server.gd` + `network_battle_world.gd`（真实回环 ENet、`world.snapshot()`） | 只验证，不改 |
| 客户端不得提交最终战果 | **已实现**：`receive()` 只接受 `hello/command/*_ack/events_request`；`command` 必须匹配自有实体；`final_ack` 必须匹配摘要 | 新增契约模块把边界数据化 + 断言 |
| 玩家与 AI 都产生命令而非直接写 actor | **已实现**（`NetworkController.receive(envelope)`；服务端 `owners[peer]` 控制器） | 验证 |
| 跨进程实体/生命/轮次映射稳定 | **部分实现**（服务端 `owners`/`event_peers`） | 新增 `NetworkAuthorityContract` 的 assign/resume/release 规则并断言"重连不生成第二辆" |
| 加入/离开/阵亡观战/再出击/结束/下一局 | 既有 `_hello` 支持 `resume`、`disconnect_owner` 清理 | 验证 |
| 服务器退出安全保存或明确未完成 | 既有 `finish()/_freeze_finish()` + 摘要 | 验证 |
| **独立服务器/客户端导出配置** | **缺失**：无 server/client 预设 | **不动手**（改构建流程属红线）→ 请求授权 |
| **多人同局端到端事件比对** | 既有 `run_network_slice` 三进程编排 | **本轮真实运行**：PASS ×3，两客户端摘要一致 |

## 2. 改动清单

| 文件 | 改动 |
|---|---|
| `scripts/network/network_authority_contract.gd`（新，~140 行） | 权威状态表 + 协议版本（读自实现）+ 客户端消息校验（命令/确认白名单 + 16 类禁写字段）+ 跨进程身份映射（assign/resume/release）+ 观察者一致性 + 显示无关声明 + `snapshot()` |
| `tests/run_network_authority_checks.gd`（新，62 项） | 上述全部 + 缺显示资源的权威可用性 |
| `docs/wt/continuation/NETWORK_AUTHORITY.md`（新） | **服务器权威状态表与协议版本**（父项交付物第一条） |
| 本页 | 设计页与剩余工作 |

**未改动**：`network_battle_server/client/world/view/controller`、`network_event_journal`、`network_pose_buffer`、`export_presets.cfg`（红线：不改构建/发布流程）。

## 3. 关键设计决定

1. **边界数据化**：把"谁能写什么"写成 `AUTHORITATIVE_STATE` / `FORBIDDEN_CLIENT_FIELDS` 常量并逐条断言，避免"仅靠注释约定"。
2. **版本不发明**：协议三元组（6/1/3）+ 帧姿态 1 全部从实现读取，测试断言与实现相等（防漂移）。
3. **一 peer 一车**：`assign/resume/release` 把"掉线重连不生成第二辆可控制车"变成可执行规则。
4. **观察者一致用摘要**：`observers_agree()` 以服务端冻结结果的 digest + event_sequence 为唯一判据（与既有 `final_ack` 摘要校验一致）。
5. **显示无关结构性可查**：权威字段禁含显示类令牌 + 仓库内研究模型不可 `ResourceLoader` 加载但字节可用 → 证明"缺显示资源不导致权威失效"是结构事实而非承诺。

## 4. 本轮验证

| 套件 | 结果 |
|---|---|
| `run_network_authority_checks`（新） | **62/62 PASS** |
| 既有网络 8 套件重跑 | **246 项 0 失败** |
| `run_network_slice` 三进程真实编排 | **服务端 + 两客户端 PASS ×3**，两客户端**同一结果摘要/会话/事件序号** |
| `run_network_view_checks`（需已有服务端） | 对接后前 2 项 PASS，套件未结束 → `NOT_RUN` |

## 5. 自纠记录

契约套件首版引用了三处**不存在的 API 名**（`VehicleCommandCodec.COMMAND_VERSION`、`VehicleCatalog.get_definition()`、把静态需求写成实例方法），全部在运行前被解析错误暴露并改为真实接口（`VehicleCommandCodec.VERSION` / 数据文件断言 / `static func`）。未放宽任何断言。

## 6. 剩余工作与需授权项

- **需授权**：新增 server/client 专用导出预设（父项交付物第二条）→ 属改构建/发布流程，本单不动手。
- 真实进程级断线重连场景、WT-025 预测/插值/延迟一致性、公开部署：`NOT_RUN`（后两者分别属下一单与"未授权不做"）。
- 性能 `HOLD_BY_USER`；真人 `NOT_RUN`。

## 7. 回滚

删除契约模块与套件、回退文档；**零既有网络代码改动**，无协议兼容风险（版本号未变）。
