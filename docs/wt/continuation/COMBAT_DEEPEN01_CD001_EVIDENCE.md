# COMBAT_DEEPEN01_CD001_EVIDENCE.md —— 首批交付清单第 1 项证据（CD001 第一个实际动作）

- 分支：`work/combat-deepen-01` · 工具：`tests/run_ammo_three_state_probe.gd`
- 范围来源：`02_FIRST_DELIVERY.md`「第一个实际动作」+ 其「交付清单 1」= **固定提交的满/半/空架实弹对照，含首个分歧点**
- 纪律：**未改动任何生产文件** ✓ · 未编造子单/场景/契约/迁移/战雷数值 ✓ · 三态**只由正常开火**产生（不写状态字段 ✓）

## 1. 锁定的实弹路径（以"伤害行 `item_id=="ammo_ready"`"为判据经验锁定 ✓）
| 车 | 锁定路径 | 未能打到弹架的尝试 |
|---|---|---|
| `ussr_t_80b` | `{part:"hull", standoff:-5.0}` | 炮塔 × 5 个距离（-5/-6/-8/-10/-12）**全部打不到** |
| `germ_leopard_2a4` | `{part:"turret", standoff:-5.0}` | — |

## 2. 满 / 半 / 空 对照（同一路径 · 真实弹丸 · 真实伤害通道已绑定）
| 车 | 状态 | 开火 | 打击后 available | **lost** | contacts | 打到弹架 | destroyed |
|---|---|---|---|---|---|---|---|
| T-80B | 满（38 发） | 0 | 0 | **38** | 2 | ✓ | **是** |
| T-80B | 半 | 19 | 0 | **19** | 2 | ✓ | 是 |
| T-80B | **空** | **38** | 0 | **0** | 2 | ✓ | **否** |
| 豹 2A4 | 满（42 发） | 0 | 28 | **14** | 2 | ✓ | 否（泄压 ✓） |
| 豹 2A4 | 半 | 21 | 21 | **0** | 2 | ✓ | 否 |
| 豹 2A4 | **空** | **42** | 0 | **0** | 2 | ✓ | 否 |

**首个分歧点**：T-80B 的 `lost` **恰等于打击前存量**（38/19/**0**）——未被隔离的转盘 ⇒ 现存弹全损并殉爆，**空架时为 0 且存活**；豹 2 的 `lost` ＝**待发架存量**（满装 14／半空 0），**始终泄压存活**。

## 3. 执行单点名风险的判定：**不成立** ✓
> 执行单原文：「如果**空架仍受弹药损伤/消耗预算**，交一份明确红例，再修动态占用。若空架路径已正确，保留版本绑定结果…」

实测：`empty rack takes no further stored-round loss from the strike (lost stays 0)` ✓ ⇒ **空架不产生任何弹药损失** ✓ ⇒ **无红例可修** ✓ ⇒ 按原文进入下一批检查 ✓。

## 4. 同一批的边界检查（执行单原文顺序：半装、搬运、同 tick 两发、重生、缓存 ✓）
| 项 | 实测结果 |
|---|---|
| 半装 | 由正常开火得到：19/38 与 21/42 ✓（见上表） |
| 搬运 | 真实 `begin_transfer_from` 开启 ✓；`chamber+in_transfer<=1`、一发只占一处 ✓；搬运中遭打击仍 `conserved()` ✓ |
| 同 tick 两发 | 同一事件重复 ⇒ `lost` 38→**38**（不重复扣 ✓）；不同事件（豹 2，可泄压存活）⇒ 14 且守恒 ✓；T-80B 首击即毁 ⇒ **如实标 not-applicable** ✓ |
| 重生 | 新生命恢复原配弹（38/42）✓、清空 ledger（`lost=0`, `fired=0`）✓、`generation` 1→2 ✓；**旧世代事件不能扣新生命** ✓ |
| 缓存/revision | 已有预留时第二次预留被拒 ✓；当前 token 提交一次 ✓；**stale token 不能再次提交** ✓；全程守恒 ✓ |

## 5. 保留给 CD001 子单的两条**实测生产行为**（只记录，不擅自改 ✓）
1. **自动补弹存在**：`feed_empty` 后长泵 → 每周期从备用架移 1 发进膛（`ammo_reserve` −1、`chamber`→1）；末段出现**备用→待发整架回填**。
2. **`feed_empty` 可与"待发架仍有弹"同时成立**（T-80B 余 10 发时仍报空 ✗ / 豹 2 余 8 发 ✗），**切换弹种后即可继续**（T-80B 为双弹种）。⇒ 需子单给出**判据**才能判断这是设计还是缺口 ✓。

## 6. 首批清单第 4 项：受影响回归（本轮实测 ✓ 只跑不改 ✓）

分支 `work/combat-deepen-01` @`fcd6579d`（已跟踪未提交=0 ✓）· 23 套件 · 合计 **1512 PASS / 2 FAIL** ✓
日志：`logs/COMBAT-DEEPEN-01/regression/SUMMARY.txt` + 每套件 `*.log` ✓

| 套件 | 结果 | 套件 | 结果 |
|---|---|---|---|
| loading_checks | 62/0 ✓ | armor_checks | 81/0 ✓ |
| loading_mechanism_checks | 65/0 ✓ | damage_checks | 57/0 ✓ |
| ammo_compartment_checks | 63/0 ✓ | spall_checks | 78/0 ✓ |
| shell_checks | 193/0 ✓ | recovery_checks | 64/0 ✓ |
| shell_cycle_player_checks | 41/0 ✓ | hud_checks | 56/0 ✓ |
| engineering_loading_checks | 23/0 ✓ | garage_checks | 151/0 ✓ |
| engineering_compartment_checks | 11/0 ✓ | app_flow_checks | 127/0 ✓ |
| engineering_material_checks | 85/0 ✓ | modern_garage_checks | 29/0 ✓ |
| projectile_checks | 标记 PASS ✓（计数格式不同 ⇒ 以标记+exit=0 为证 ✓） | modern_support_checks | 19/0 ✓ |
| modern_armor_frame_checks | 17/0 ✓ | modern_team_identity_checks | 76/0 ✓ |
| check_live_fire_respawn | 17/0 ✓ | bound_model_package_checks | 59/0 ✓ |
| **run_challenge_checks** | **138 PASS / 2 FAIL** ⚠️ | | |

⚠️ **唯二失败＝构建登记表已裁定例外** ✓：`real defense script pilot completes finite waves with opponent AI untouched` ×2（登记表第 2 条 · 用户裁定 B4 · 与本次改动无关 ✓）⇒ **本批未引入任何新失败** ✓。
⇒ 覆盖了执行单点名的"**两车正常生成、配弹、发射、接触、损伤、重生**"受影响面 ✓。

## 7. 证据位置（固定提交 ✓）
- 工具：`tests/run_ammo_three_state_probe.gd`
- 原始输出：`logs/COMBAT-DEEPEN-01/cd001-three-state-h.log`（三态）· `logs/COMBAT-DEEPEN-01/cd001-boundaries.log`（边界四项）
- 收尾标记：`=== 结果: 57 项检查, 0 失败 ===` · `CD001_THREE_STATE_PROBE_PASS`
- 生产代码改动：**0** ✓
