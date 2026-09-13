# WT-026-R1 设计页（网络身份、命令校验与在线结果可信性）

- 对应父项：WT-026（前置 WT-024）
- 依据：`03_全部42项目标工作单.md` 行 1069-1107

## 1. 现状核查（实测）

| 要求 | 现状 | 处置 |
|---|---|---|
| peer/session/entity/life 权限映射 | **部分**：服务端 `owners[peer]` + `not_owner` 校验；无显式角色表 | 新增 `NetworkIdentityPolicy` 角色/权限表并断言 |
| 命令字段类型/范围/序列校验 | **部分**：`VehicleCommandCodec` 校验版本/实体/序号/时刻与类型；**缺少数值范围、NaN/Inf、资源 ID、频率** | 新增有界校验并逐项负例 |
| 频率限制 | **部分**：服务端每 tick ≤4 包 | 补"每 tick 消息"与"每秒命令"两级 |
| 只接受允许结构与资源 ID | **缺失**：无资源 ID 白名单 | 新增逻辑 ID 前缀白名单 |
| 在线收益来自已结束比赛的幂等收据 | **已实现**：`ProgressionService.apply_result_once(token,result)`（WT-022-R1 验证） | 新增**显式收据契约**（签发/领取/冲突/信任级别） |
| 离线存档与可信在线进度分域 | **部分**：收据表与研发点同库 | 契约中显式分域（`can_mint_receipt=false`） |
| 主机自建房信任级别标明 | **缺失** | `trust_label()` + 收据 `trust` 字段 |
| 敏感会话数据不入公共日志 | **缺失显式保证** | `log_safe()` 剥离敏感字段 |
| 重连令牌/授权失效/错误反馈分开 | **部分**：客户端有重连与基线恢复 | 三种结果分开并断言 |

## 2. 改动清单

| 文件 | 改动 |
|---|---|
| `scripts/network/network_identity_policy.gd`（新，~165 行） | 角色权限表 + 字段范围/有限性/序号/时刻校验 + 两级频率 + 资源 ID 白名单 + 敏感日志剥离 + 重连/失效/错误分离 + 信任标签 |
| `scripts/network/network_result_receipt.gd`（新，~95 行） | 收据签发（仅已结束比赛 + 摘要匹配）/幂等领取/冲突拒绝/离线域分域/信任级别 |
| `tests/run_network_identity_checks.gd`（新，60 项） | 上述全部负例与正例 |
| `docs/wt/continuation/NETWORK_IDENTITY.md`（新） | **威胁/权限模型与允许消息表 + 负例 + 收据设计** |
| 本页 | 设计页与剩余工作 |

**未改动**：`network_battle_server/client`、`vehicle_command_codec`、`progression_service`、任何战斗参数。

## 3. 关键设计决定

1. **越权先于模拟**：`authorizes()` 在字段校验之前判定归属，他人 entity 的命令连解析都不进入。
2. **非有限值零容忍**：NaN/Inf 一律 `non_finite_field`，且**拒绝不推进序号**（避免"被拒命令占用序号"造成的隐性状态污染）。
3. **逻辑 ID 白名单**：客户端只能命名 `vehicle:/shell:/map:/objective:/smoke:`，路径、脚本类名、URL 全部拒绝。
4. **收据三重约束**：已结束 + 摘要匹配 + 已知结果；领取幂等；同 token 冲突拒绝。
5. **分域不可越**：本地存档可任意编辑，但**不能铸收据**；失败的网络领取不动离线存档。
6. **信任级别显式**：自建房收据标 `host_self_hosted` 且不计入权威结果。

## 4. 本轮验证

| 套件 | 结果 |
|---|---|
| `run_network_identity_checks`（新） | **60/60 PASS** |
| `run_command_contract_checks` / `run_network_authority_checks` | **PASS / PASS** |

## 5. 自纠记录（我的测试缺陷，3 处）

1. 读了**成功返回时不存在**的 `reason` 键（且该行断言写成 `or true` 的空断言）→ 改为实义断言 `allowed.ok`。
2. "冲突重发"用例传了**不同摘要**，先命中 `digest_mismatch` → 改为同摘要不同结果，才走到 `receipt_conflict`。
3. 对**已领取**收据再测"摘要不符"→ 幂等分支先返回 duplicate（实现正确）→ 改用未领取的收据测摘要校验。
三处均**未放宽安全断言**（越权/非有限/幂等/分域始终为硬断言）。

## 6. 剩余工作（如实）

- **统一两套实现**：把生产 `ProgressionService` 收据与本契约合并为单一权威路径（当前并存，行为一致）。
- 真实账号系统、进程级断线重连、客户端伪造的端到端注入 → `NOT_RUN`。
- 不承诺绝对无作弊；不做密码学签名；只对本机隔离测试对象注入（不触碰第三方系统）。
- 性能 `HOLD_BY_USER`；真人 `NOT_RUN`。

## 7. 回滚

删除两个新模块与套件、回退文档；**零既有网络/存档代码改动**，协议版本未变。
