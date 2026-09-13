# 网络身份、命令校验与在线结果可信性（WT-026-R1）

- 依据：`03_全部42项目标工作单.md` WT-026（行 1069-1107）
- 实现：新增 `scripts/network/network_identity_policy.gd`（威胁/权限模型 + 有界命令校验）+ `scripts/network/network_result_receipt.gd`（幂等收据与分域）
- 验证：新增 `tests/run_network_identity_checks.gd`（**60/60 PASS**）+ 回归 `run_command_contract_checks` **PASS**、`run_network_authority_checks` **PASS**

## 1. 权限映射（peer / session / entity / life）

| 角色 | 允许消息 |
|---|---|
| `player` | `command` + 全部确认/请求 |
| `observer` | 确认/请求（**不可发 command**） |
| `spectator` | 确认/请求（不含 `final_ack`） |
| 未绑定 peer | 一律 `handshake_required` |

- `bind(peer, session, entity, life, role)` 建立映射；**未知角色**拒绝。
- **他人 entity_id 的输入在进入模拟前被拒**（`not_owner`，实测）。
- 会话到期 → `expire_authorization()` 返回 **`feedback="authorization"`**（与错误分开）；之后必须重新握手。

## 2. 有界命令校验（允许消息表与字段边界）

| 校验 | 规则 | 拒绝原因 |
|---|---|---|
| 消息白名单 | `hello/command/baseline_ack/events_ack/events_request/final_ack` | `unsupported_message` |
| 每 tick 消息数 | ≤ **4** | `rate_limited_per_tick` |
| 每秒命令数 | ≤ **20** | `rate_limited_per_second` |
| 序号 | 必须递增（`> 上次`） | `stale_sequence` |
| 序号跳跃 | ≤ **64** | `sequence_gap_too_large` |
| 输入时刻 | 年龄 0..**12 tick** | `stale_input_tick` |
| 浮点字段 | 必须有限 | **`non_finite_field`**（NaN/Inf 绝不进入模拟） |
| 数值范围 | `throttle/steer ∈ [-1,1]`、`gun_pitch ∈ [-0.35,0.35]`、`turret_yaw ∈ [-2π,2π]` | `field_out_of_range` |
| 瞄准点 | 有限且 \|x\|,\|y\|,\|z\| ≤ **5000** | `non_finite_field` / `field_out_of_range` |
| 布尔旗标 | 必须 bool | `invalid_flag_type` |
| 信封结构 | 必须有 entity/sequence/input_tick/command | `malformed_envelope` |
| **资源 ID** | 仅接受逻辑 ID 前缀 `shell:/vehicle:/map:/objective:/smoke:` | `resource_id_not_allowed` |

**不污染保证**：所有被拒命令**不会推进序号**（实测：连续十余次拒绝后 `last_sequence` 仍为最后一次通过值）。

**任意路径/代码/对象构造**：`res://...`、`user://...`、`../../`、`GDScript`、外部 URL 一律拒绝（实测逐项）。

## 3. 伪造 / 重放 / 越权 负例（交付物第二条，全部有运行证据）

| 负例 | 结果 |
|---|---|
| 伪造成他人 `entity_id` | `not_owner` |
| 观察者发 command | `action_not_permitted_for_role` |
| 重放旧序号 | `stale_sequence` |
| 陈旧/未来输入时刻 | `stale_input_tick` |
| NaN / Inf / 越界 / 旗标非布尔 | `non_finite_field` / `field_out_of_range` / `invalid_flag_type` |
| 消息洪泛 / 命令洪泛 | `rate_limited_per_tick` / `rate_limited_per_second` |
| 任意资源路径 | `resource_id_not_allowed` |
| 未知消息类型 | `unsupported_message` |
| 未绑定/已失效会话 | `handshake_required` |

## 4. 结果收据与幂等入账（交付物第三条）

| 规则 | 实现/实测 |
|---|---|
| 只有**已结束**比赛可出收据 | `match_not_finished`（未结束即拒） |
| 收据必须匹配**冻结结果摘要** | `digest_mismatch` |
| 未知结果不可发奖 | `unknown_outcome` |
| 重复发同一收据 | 幂等返回 `duplicate` |
| 同 token 发不同收据 | `receipt_conflict` |
| **重复领奖不加收益** | 首次 +60 → 再次 `duplicate, points=0`，`online_points` 不变 |
| 无收据领奖 | `no_receipt` |
| **本地存档不能铸收据** | `edit_offline_save(9999)` 后仍 `no_receipt`；可信在线点数不变 |
| **网络错误不删除离线存档** | 失败的领奖后 `offline_research.points` 保持 9999 |
| 自建房信任级别 | `host_self_hosted` 明确标注，且**不计入权威结果**（`trusted_result_tokens()` 排除） |

分域声明：`trusted_online`（权威收据）与 `offline_research`（本地存档，`can_mint_receipt=false`）显式分离。

## 5. 会话数据与日志

`log_safe()` 剥离 `token/reconnect_token/secret/key/password/session_secret/authorization`；**重连令牌、授权失效、错误反馈**分别是 `reconnect_token_accepted` / `feedback="authorization"` / 各错误码（实测三者分开）。

## 6. 验收对照

| 验收要求 | 证据 |
|---|---|
| 他人 entity_id 被拒；NaN/Inf/越界不污染模拟 | §2/§3（含"拒绝不推进序号"） |
| 重复领奖或同场结果重送不增加收益 | §4（首次/再次/冲突三态） |
| 用户改本地存档不能改变可信战果 | §4（本地编辑后仍无法铸收据） |
| 网络错误不删除唯一离线存档 | §4（失败领奖后离线点数不变） |

## 7. 明确不做 / 未完成（如实）

- **不承诺绝对无作弊**；不做密码学签名；不测试任何第三方系统（全部为**本机隔离**的契约与负例）。
- **两套实现并存**：生产路径目前是 `ProgressionService.apply_result_once(token,result)`（WT-022-R1 已验证幂等），本单新增的是**显式威胁模型 + 收据契约**；把二者统一到单一权威实现属 WT-026 剩余工作。
- 真实账号系统（peer/session 之外的身份）、网络断线重连端到端、真人 `NOT_RUN`；性能 `HOLD_BY_USER`。
