# WT-037-R1 设计页（房间、分队、匹配与连续运行服务）

- 对应父项：WT-037（前置 WT-024、WT-026、WT-035）
- 依据：`03_全部42项目标工作单.md` 行 1543-1582

## 1. 现状核查（实测）

| 要求 | 现状 | 处置 |
|---|---|---|
| 房间创建/加入/准备/队伍/规则/加载确认/比赛/结算/下一局 | **全部缺失**：`NetworkBattleServer` 是**单局 2 座**回环权威（`create_server(port,2,2)`），无房间/分队/准备/连续局 | 新增 `NetworkRoomService` 状态机 |
| 匹配（编成能力段/模式/队伍/区域） | **缺失** | 新增小规模分组匹配（设计值，非 BR 照搬） |
| 权限/版本与内容一致性/满房/掉线/重连/房主变化 | **部分**：服务端有 peer 所有权与会话恢复；**无版本/内容哈希一致性、无满房概念、无房主迁移** | 状态机补齐并逐项反馈 |
| 专服不因客户端退出停止 | **缺失**（单局模型下"结束即冻结"） | 专服模式下房间保持 |
| 最小可用房间界面 | **缺失** | 交付 `ui_contract()`；窗口实现 `NOT_RUN` |
| 房间发现/中继/托管/账号 | **缺失** | 四项**未授权替身提案**（不自动开云、不注册商店） |

## 2. 改动清单

| 文件 | 改动 |
|---|---|
| `scripts/network/network_room_service.gd`（新，~215 行） | 房间/分队状态机 + 加载门 + 结算与连续局 + 小规模匹配 + 外部服务提案 + 测试域登记 + UI 契约 |
| `tests/run_room_service_checks.gd`（新，52 项） | 上述全部 |
| `docs/wt/continuation/ROOM_SERVICE.md`（新） | **状态机 + 最小房间界面契约 + 连续两局/重连证据 + 外部运行部署方案** |
| 本页 | 设计页与剩余工作 |

**未改动**：`network_battle_server/client/world`、启动器 `.bat`、任何战斗与规则参数。

## 3. 关键设计决定

1. **加载门硬约束**：`controls_allowed()` 只在 `playing` 且该座位已加载时为真 → 从接口层杜绝"未加载就开车"。
2. **局内状态隔离**：结算 → `begin_next_round()` 清空 `round_events` 并重置座位加载位；带旧 round 的事件直接 `stale_round`。
3. **容量与一致性四类反馈**：`room_full` / `version_mismatch` / `content_mismatch` / `authorization_expired` 各自独立，不混为一句"加入失败"。
4. **专服语义**：`mode=dedicated` 时房主离开**不迁移、不关房**；客户端房才迁移给最小 peer。
5. **重连即同座**：已存在的 peer `join` → `resumed`，座位数不变（与 WT-024 契约一致）。
6. **收据衔接**：结算调用 WT-026 的 `NetworkResultReceipt.issue()`，客户端房标 `host_self_hosted`、专服标 `authority_server` → 信任级别随房间类型自动正确。
7. **外部服务只提案**：四项服务均 `requires_authorization=true` + 本地替身，避免"悄悄开云"。

## 4. 本轮验证

| 套件 | 结果 |
|---|---|
| `run_room_service_checks`（新） | **52/52 PASS** |
| `run_network_identity_checks` / `run_network_authority_checks` | **PASS / PASS** |

## 5. 自纠记录（我的缺陷，2 处）

1. `external_service_proposal()` 写成实例方法却在类上静态调用 → 改为 `static`（该数据本就是常量事实）。
2. 测试读取 `begin_next_round()` 返回中**不存在的 `previous` 键** → 给返回值补上 `previous`（对审计有用），而非删断言。
两处均未放宽验收断言（加载门、局隔离、四类反馈、专服语义始终为硬断言）。

## 6. 剩余工作（如实）

- 房间服务**接入真实服务端**（多局、>2 座、房主迁移的真实进程验证）→ 属 WT-037 剩余工作。
- 真实窗口房间界面、进程级连续两局与断线重连 → `NOT_RUN`。
- 公网双端、发现/中继/托管/账号服务 → `NOT_RUN` 且**未授权不部署**。
- 性能 `HOLD_BY_USER`；真人 `NOT_RUN`。

## 7. 回滚

删除房间服务模块与套件、回退文档；**零既有代码改动**，协议版本与启动器未变。
