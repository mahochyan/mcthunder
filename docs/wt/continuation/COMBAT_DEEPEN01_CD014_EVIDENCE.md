
# MCT-COMBAT-DEEPEN-01 / WT-CD-014 evidence: realistic sortie rules and out-of-match settlement

## 0. Stage 0 — pickup check (verbatim from the packaged list)

```
07_WORK_ORDERS.json / items[13] (WT-CD-014):
  id=WT-CD-014 ; title=陆战拟真出击规则与局外结算 ; priority=P2 ; phase=G3 ; scope=core ; status=planned
  depends_on = **WT-CD-012, WT-CD-013**  ⇒ both are CLOSED, so CD14 may proceed.
  related_parent_orders = WT-022 / WT-033
  basis = 现有固定300票/等待再出击/胜负奖励为项目规则，不等于常规战雷Ground RB的个人出击资源。
  player_outcome = 保存经典训练与原对局，同时增加明确的拟真出击选择、贡献奖励和可靠局外保存。
  read_first = scripts/battle/match_rule_preset.gd / scripts/battle/respawn_service.gd /
               scripts/battle/team_match_director.gd / scripts/garage/（实际保存与编成服务定位一次）
  source_ids = R09 / W07 ; acceptance_case_ids = CD14-T01 .. CD14-T06
```

### 0.1 The six cases, quoted
| case | title | action | expected |
|---|---|---|---|
| **CD14-T01** | 旧模式回归 | 使用原team_standard_300完成正常局 | **旧规则和存档语义保持，新增行为仅在新preset生效** |
| **CD14-T02** | 个人SP与队票 | 占点/击毁/死亡后检查双方及个人账本 | **不同资源互不串账，收益依据提交事件** |
| **CD14-T03** | 出击失败与重复请求 | 出生被堵、取消、重发同token | **不重复扣费，预留释放正确** |
| **CD14-T04** | 编成次数与资格 | 切换车型、耗尽出击次数、资源不足 | **统一资格拒绝且原因可见，不生成默认车** |
| **CD14-T05** | 结算重试与存盘失败 | 重复提交结果、模拟隔离档写失败再恢复 | **不重复奖励，故障明确可恢复，不污染真实用户档** |
| **CD14-T06** | 重启与不同规则版本 | 新包重启并读取旧档/旧比赛结果 | **历史结果按原版本解释，未知版本明确迁移或拒绝** |

### 0.2 Rejection conditions carried forward verbatim
```
偷偷修改旧300票模式 ✗ · 队伍票数直接当个人SP ✗ · UI扣款但生成失败不退 ✗ · 用现实价格或假BR冒充已核实游戏数据 ✗
```

### 0.3 The dependency graph tail, measured at the same time
```
WT-CD-015 depends_on WT-CD-003, 004, 006, 007, 010, 012, 013, 014
WT-CD-016 depends_on ALL fifteen earlier orders
So the remaining order is exactly CD14 -> CD15 -> CD16.
```

## 1. Stage 2 — the named sources read, and the `basis` MEASURED rather than trusted

All three named battle files exist: `match_rule_preset.gd` (54 lines), `respawn_service.gd` (41) and
`team_match_director.gd` (138). The fourth entry asked for the save and line-up service to be LOCATED ONCE, and it was:
`scripts/garage/` holds `profile_store.gd` (224 lines, the actual save), `garage_service.gd` (79) and `lineup.gd` (20) for
the line-up, plus `garage_preparation.gd` (205), `progression_service.gd` (54), `research_graph.gd` (27) and
`match_config.gd` (32).

### 1.1 The existing preset is a versioned, snapshot-able rule object
`match_rule_preset.gd` declares `VERSION := 1`, `ID := "team_standard_300"`, `start_tickets := 300`, a `result_order` of
tickets exhausted, time limit, ticket compare and draw, and it exposes `standard()`, `id()`, `snapshot()` and
`fingerprint()` alongside a label.

⇒ So the new `ground_rb_like_v1` has an established shape to follow, and the old preset is a first class object that must be
LEFT ALONE. The fingerprint is the natural thing to carry into a saved result so a historical outcome can be read by the
version that produced it, which is exactly what the sixth case asks for.

### 1.2 Tickets already exist as a team pool, and that is precisely why SP must be separate
`ticket_ledger.gd` moves team tickets from committed events, and the director already reports hits, penetrations, kills and
deaths. Nothing in the tree holds a PERSONAL sortie-point balance, so:
```
team pool       : ticket_ledger.gd          (exists, stays the only ticket authority)
personal SP     : does NOT exist            (must be added, and must NOT read the team pool as its source)
research gain   : progression_service.gd    (exists separately)
repair/resupply : does NOT exist as a ledger (must be added as the fourth account)
```
The order names four INDEPENDENT books, and the rejection conditions forbid the team count being used as personal SP, so the
new SP ledger must be derived from committed events rather than from the team pool.

### 1.3 Respawn already knows how to avoid a blocked spawn, and nothing else
`respawn_service.gd` exposes `spawn_provider`, `step(state) -> int` and `find_safe(space, candidates, size, occupied)`, which
is a candidate search that avoids occupied points. So the BLOCKED SPAWN half of the third case has machinery already, while the
transaction the order actually specifies - validate, then RESERVE, then confirm the spawn, then commit the charge, releasing
the reservation when the spawn fails or is cancelled, with a repeat request being IDEMPOTENT and the balance never going
negative - does not exist and is the real work of this sub-order.

### 1.4 What the order demands, in its own words
```
1. a new ground_rb_like_v1 that does NOT overwrite team_standard_300, with four INDEPENDENT books: team pool, personal SP,
   research gain, and repair/resupply cost;
2. initial SP, vehicle cost, the repeat sortie limit and contribution income all come from a FROZEN PROJECT TABLE, and where
   a real battle rating or price is absent the project uses a project_balance_band - inventing an official battle rating is
   forbidden by name;
3. mode selection changes the real rules and the information shown; a vehicle with no configuration is REFUSED rather than
   falling back to a historical or training hull;
4. a respawn request is validate, reserve, confirm, commit, with the reservation released when the spawn is blocked, fails or
   is cancelled, a repeat request idempotent, and the balance never negative;
5. net out-of-match income and cost are itemised and booked exactly ONCE; no paid store, account service or real currency in
   this round; the cost side may be switched off but that must be LABELLED as a project divergence;
6. where reference data is incomplete the project initial value is allowed, and the divergence is registered in
   DIVERGENCE_REGISTER rather than waiting for field by field confirmation.
```

## 2. Next steps
1. write the **acceptance scenes first**: the old 300 ticket mode played normally with its rules and save semantics intact;
   capture, kill and death then checking both teams AND the personal book; a blocked spawn, a cancellation and a repeated
   token; switching vehicles, exhausting sorties and running short of resources; a repeated settlement with an isolated save
   failure and recovery; and a restart reading an old save and an old match result;
2. then add the versioned preset, the personal SP book and the sortie transaction, keeping `team_standard_300`, the ticket
   ledger and the death gate exactly as they are;
3. emit itemised out-of-match receipts booked once, and register the project divergences rather than claiming real prices.

## 3. The six scenes, first pass, and what they measured
```
The scenes drive the real preset, the real line-up validator, the real garage service, the real profile store and the
real progression service, and the readings are informative on every case:
   HELD  T04 line-up legality: all six line-up vehicles are known to the garage, an unconfigured id is refused with
         ok false AND a reason, and the garage does not claim to hold it, so no default hull is generated.
   GAP   T01 the old preset is confirmed INTACT - id team_standard_300, version 1, three hundred tickets and a real
         fingerprint - while the probe finds NO new versioned preset file, which is the thing this sub-order must add.
   GAP   T02 the stored profile keys were listed in full and contain research points, unlocked vehicles, the garage
         block and receipts, but NO personal sortie book of any kind, so the four independent books cannot yet be
         shown to be separate. That is a measured absence rather than an opinion.
   GAP   T03 the spawn search class is present while no reservation bookkeeping is, which is exactly the difference
         between avoiding a blocked spawn and making a sortie request idempotent.
   GAP   T05 the result entry point and the commit both REFUSED, and their readings are worth keeping: the first
         result was rejected as a match result that had not been registered, and the store refused the candidate.
         Both need their real preconditions measured rather than guessed, and that is named as the next step.
   GAP   T06 there is no interpreter at all, so a historical result cannot yet be read by the version that produced it.
One observation is recorded without a conclusion: a refusal reason came back as mojibake in the captured log. That may
be the log capture decoding rather than the product, and it will be measured before anything is claimed about it.
NO PRODUCTION CODE WAS CHANGED, and no delivered expectation was edited at any point.
```

## 4. The two refusals and the mojibake, measured rather than assumed
```
REFUSAL ONE, the result entry point: its own body gates on the token being REGISTERED, on the director being BOUND and
non null, on the director phase being finished and on its result being exactly the submitted one. The first pass bound
nothing, so the refusal was correct and the fault was the harness. The binding is now attempted and PRINTED rather than
assumed, together with the director phase and result and the token that registration actually issued.
REFUSAL TWO, the store commit: validate() rejects any candidate whose key count differs from the declared schema, so the
probe key I had added was refused BY DESIGN. The commit is now exercised with the store own snapshot, and it succeeds:
commit ok true and the reloaded store reports the same size, so the transactional write path is measured working.
THE MOJIBAKE, settled rather than left hanging: the localization service falls back to a bracketed key when a string is
MISSING, and the table assets/localization/zh_CN.json is sixty thousand bytes with no byte order mark and DOES hold the
key in question. So the text is not missing and the service is not the cause; the garbling is in how the captured output
was decoded. That is recorded as a measurement, and no product fault is claimed from it.
```

## 5. T05 traced to the very last link, and the mojibake settled
```
The registration path was followed link by link and each link was PRINTED rather than assumed:
   register_match returns an EMPTY token unless the config mode is normal, which is its own first line;
   bind_director with an empty token returns true immediately (its own early exit) and binds nothing;
   apply_result_once with an empty token returns ok TRUE with ZERO points, which is its own designed early return.
So the two calls both reporting success is not a double reward - it is two zero point returns from an empty token, and
the acceptance case correctly refuses to call that a pass. The reason the token was empty is that MatchConfig.build
REFUSED the config, reporting ok false with an EMPTY error list, so the next measurement is named and narrow: read what
that builder returns besides errors, because it evidently reports its refusal through a different field.
THE MOJIBAKE IS SETTLED. The localization service falls back to a bracketed key ONLY when a string is missing. The table
assets/localization/zh_CN.json is sixty thousand bytes with no byte order mark and DOES hold the key, and the text that
came back garbled is Chinese - it decodes to a sentence about training and free battles not counting research. So the
string is present and correct in the source, the service is not at fault, and the garbling is in how captured console
output was decoded. Recorded as a measurement with no product fault claimed from it.
NO PRODUCTION CODE WAS CHANGED, and no delivered expectation was edited at any point.
```
