# 房间、分队、匹配与连续运行服务（WT-037-R1）

- 依据：`03_全部42项目标工作单.md` WT-037（行 1543-1582）
- 实现：新增 `scripts/network/network_room_service.gd`（房间/分队状态机 + 加载门 + 连续运行 + 小规模匹配 + 外部服务提案）
- 验证：新增 `tests/run_room_service_checks.gd`（**52/52 PASS**）+ 回归 `run_network_identity_checks` **PASS**、`run_network_authority_checks` **PASS**

## 1. 房间与分队状态机（交付物第一条）

```
created → waiting → ready_check → loading → playing → settled → ready_check(下一局)
                                     ↑                              │
                                     └──────── closed（最后一人离开/房主关闭）─┘
```

| 事件 | 结果 |
|---|---|
| `create_room(id, host, {mode, protocol_version, content_hash, region, rules_id})` | `state=waiting`、容量 **8**（4v4）、携带冻结规则 id（`MatchRulePreset.ID`） |
| `join(peer, hello)` | 自动分队（交替、每队上限 4）；重复 join → **resume 同一座位**（不新增） |
| `mark_loaded(peer)` | 逐座位确认加载；**全员加载才进入 `playing`** |
| `settle(result, receipt, digest)` | 仅在 `playing` 可结算；签发**幂等收据**（客户端房 = `host_self_hosted`，专服 = `authority_server`） |
| `begin_next_round()` | 清空**全部局内事件**、座位重新置为未加载、`round_id+1` |
| `leave(peer)` | 客户端房：房主离开 → **迁移给剩余最小 peer**；专服：**房间保持**（不因客户端退出停止） |

## 2. 验收对照

| 验收要求 | 实测证据 |
|---|---|
| **未加载完成不能提前控制车辆** | 全员加载前 `controls_allowed()` 恒为 false；单座位已加载 → `loading` 且仍不可控；全员加载 → `playing` 且可控；无座位者永不可控 |
| **旧局事件不会污染下一局** | `begin_next_round()` 后 `round_events == 0`；携带旧 round 的事件 → **`stale_round`** 被拒；当前 round 事件可入 |
| **满房/版本不兼容/授权失效有明确反馈** | `room_full`（第 9 人）、`version_mismatch`、`content_mismatch`、`authorization_expired`（四类各自独立原因码） |
| **局域网回环与公网双端测试分开登记** | `register_test_scope()`：`loopback` 登记且 `public_tested=false`；显式 `public` 才标 true；未知域拒绝 |

## 3. 连续两局与断线重连（交付物第三条）

| 项 | 证据 |
|---|---|
| 连续两局 | 契约级实测：结算 → 下一局 → 局内事件清零 → 座位全部回到未加载 → 不可控直到再次加载 |
| 断线重连 | `join()` 对已存在 peer **resume 同一座位**（座位数不变）；WT-024 的 `NetworkAuthorityContract.resume()` 已实测"重连不生成第二辆可控制车" |
| 进程级"连打两局 + 真实断线重连" | **`NOT_RUN`**（需要窗口/交互与真实断线注入，属 WT-037 剩余工作） |

## 4. 小规模匹配（父项要求：少量用户不强行依赖复杂全球架构）

- 分组键：`mode | content_hash | region`；组内按能力段（`tier`）排序，**跨度 > 1 即不匹配**；单房间容量 8。
- 实测：8 名同条件玩家 → **单房间**（`fallback=single_room`）；内容哈希不同 → 分组隔离；tier 跨度 1↔5 → 多余者进入 unmatched。
- `MATCHMAKING` 明确标注为**设计值**（`max_tier_spread=1`、每队 2..4），**不照搬任何商业 BR 系统**。

## 5. 最小可用房间界面（交付物第二条）

`ui_contract()` 明确界面**必须展示**：房间 id、带分队的座位表、准备/加载状态、协议与内容一致性、房主标识、以及满房/版本不符/授权失效反馈；**必须阻止**：全员加载前不可操作载具。

**实际窗口界面 → `NOT_RUN`**（需窗口套件；本单交付契约，未伪造界面完成）。

## 6. 外部运行/部署方案（交付物第四条，全部**未授权替身**）

| 服务 | 本地可验证替身 | 成本 | 授权 |
|---|---|---|---|
| 房间发现 | 本地房间登记（进程内/文件） | 托管 + 出网 | **未授权（需单独提案）** |
| 中继 | 当前仅回环直连 UDP | 带宽 | **未授权** |
| 专服托管 | `START_LOCAL_SERVER.bat`（操作者机器） | 算力 | **未授权** |
| 账号 | 仅 peer/session id（**非账号系统**） | 身份提供商 | **未授权** |

明确不做：不自动开付费云服务、不注册商店、不向公开互联网发行、**不把本地 session id 包装成安全账号系统**。

## 7. 未完成（如实）

- 真实窗口房间界面与进程级连续两局/断线重连：`NOT_RUN`。
- 房间服务**尚未接入** `NetworkBattleServer`（当前服务端仍是单局 2 座回环权威）→ 属 WT-037 剩余工作；本单为零侵入契约与状态机。
- 公网双端：`NOT_RUN`（且未授权不部署）；性能 `HOLD_BY_USER`（零带宽/帧率采样）；真人 `NOT_RUN`。
