
# MCT-COMBAT-DEEPEN-01 / WT-CD-013 evidence: death, loss and multi-contributor attribution

## 0. Stage 0 — pickup check (verbatim from the packaged list)

```
07_WORK_ORDERS.json / items[12] (WT-CD-013):
  id=WT-CD-013 ; title=死亡、损失与多人贡献归因 ; priority=P1 ; phase=G3 ; scope=core ; status=planned
  depends_on = **WT-CD-008, WT-CD-009, WT-CD-010**  ⇒ all three are CLOSED, so CD13 may proceed.
  related_parent_orders = WT-014 / WT-022 / WT-023
  basis = 已有死亡去重、来源和玩家统计；多来源贡献、持续火灾和同生命实弹链需更完整的统一账本。
  player_outcome = 玩家知道是谁、通过哪次打击让自己失能或死亡，击毁/助攻/损失只结算一次。
  read_first = scripts/vehicle_actor.gd / scripts/defs/vehicle_runtime_state.gd / scripts/damage/vehicle_recovery.gd /
               scripts/battle/team_match_director.gd / scripts/battle/ticket_ledger.gd
  source_ids = R06 / R09 / R11 ; acceptance_case_ids = CD13-T01 .. CD13-T06
```

### 0.1 The six cases, quoted
| case | title | action | expected |
|---|---|---|---|
| **CD13-T01** | 单发多模块 | 同炮穿透并损伤多个模块 | **发射1、接触/损伤按各自定义计数，击毁最多1次** |
| **CD13-T02** | 多射手与持续火灾 | 先伤/后伤/火灾延迟死亡 | **归因及助攻遵循固定版本，重复事件不加分** |
| **CD13-T03** | 同tick致死与重复回调 | 多条合法伤害同时使一个生命死亡 | **死亡/扣票/掉弹/奖励各一次** |
| **CD13-T04** | 射手先死与新目标生命 | 飞行中射手死亡，目标后续重生 | **合法已发弹归因保留，旧目标事件不伤新生命** |
| **CD13-T05** | 玩家实弹死亡再出击 | 正常规则/明确受控实弹夹具中被敌弹致死后点击UI | **同一生命链闭合，保留车型/配装且输入不穿透** |
| **CD13-T06** | 回放缓存与终局 | 超过回放缓存容量并终局后重放/下一局 | **全场账本不丢历史计数；终局冻结且下局身份独立** |

### 0.2 Rejection conditions carried forward verbatim
```
从残骸数当作全场死亡 ✗ · 同一伤害拆成多后效重复刷贡献 ✗ · 回放一次又发奖励 ✗ · 源码生命周期冒充新包结果 ✗
```

### 0.3 One instruction inside the order that governs how it is worked
```
若后继已验过则不重复制造缺口 - if a later order has already verified something, do NOT manufacture the gap again.
And: 先修统计入口而非改伤害 - fix the statistics entry rather than the damage model.
Both are honoured here: nothing in the damage path is to be changed, and no already verified behaviour is to be re-opened.
```

## 1. Stage 2 — the named sources read, and the `basis` MEASURED rather than trusted

All five named files exist: `vehicle_actor.gd` (509 lines), `defs/vehicle_runtime_state.gd` (225),
`damage/vehicle_recovery.gd` (161), `battle/team_match_director.gd` (138) and `battle/ticket_ledger.gd` (37).

### 1.1 The basis is CONFIRMED on both halves
The first half - that death de-duplication, its source and player statistics already exist - is measurable in the actor:
`state.death_notified` is the dedup gate, `_commit_death()` and `_publish_death()` are the two halves of committing and
publishing a death, and `state.death_record` already carries `point_world`, `ammo_before_loss`, `cause` and `turret_detached`.
The damage commit path also already reports `newly_destroyed` and threads a `secondary_death` out of `VehicleRecovery`.

The second half - that multi-source contribution, sustained fire and the same-life live-round chain need a more complete
unified ledger - is measurable too, and more starkly: searching the whole script tree for `ContributionLedger` or
`CombatEvent` returns **ZERO** files. The unified ledger the order asks for does not exist in any form.

### 1.2 The ticket ledger is deliberately tiny, and that matters
`ticket_ledger.gd` is thirty seven lines and exposes exactly two static functions: `apply_events(state, owned_seconds)` and
`result_after_tick(state)`. So tickets are already applied from events, and the ticket authority is already a small, readable
piece. The new ledger therefore must NOT become a second ticket authority and must NOT become a second death authority: it
records CONTRIBUTION and ATTRIBUTION, while `death_notified` stays the dedup gate for a death and `ticket_ledger` stays the
authority for tickets.

### 1.3 What the order demands of the new ledger, in its own words
```
1. a SINGLE service with complete identity: match / entity / life / generation / shot / projectile / root_effect / event;
2. and explicitly NOT the sixteen entry replay buffer used as the whole match statistics ledger;
3. separate counters for actual contacts, effective damage, shots fired, firing slots and kills;
4. statistics subject and dedup key must not be conflated;
5. kill attribution, the assist window, recon and repair contribution, and sustained fire inheritance must be explicitly
   VERSIONED;
6. damage without a legitimate cause must not be credited as a kill, and friendly fire, abandonment and environmental
   death must be handled separately;
7. the key damage and the final death may come from DIFFERENT shooters, decided by a frozen rule for primary and assist;
8. a temporary UI hint must never be written into the reward;
9. contribution is recorded AFTER the production commit, and a kill is never guessed from an observed HUD colour.
```

## 2. Next steps
1. write the **acceptance scenes first**, covering: one shot damaging several modules with one firing and at most one kill;
   several shooters with a delayed fire death; several legitimate damages in one tick; a shooter dying while its round is in
   flight and the target respawning; a player killed by a live round and re-entering; and a replay buffer overflow with a
   frozen end of match and a distinct next match identity;
2. then add the single `CombatEvent` / `ContributionLedger` service with the five separate counters and versioned attribution,
   keeping `death_notified` the only death dedup gate and `ticket_ledger` the only ticket authority;
3. emit a settlement receipt and a read-only replay interface for later modes, economy and network to share.

## 3. The six scenes, first pass, and what their own readings exposed
```
The scenes drive the real versioned event stream, the real destroy_once gate and the real director report, and they
already show two things holding and four not, with the four explained by the readings rather than by opinion:
   HELD  T01: the hull carries ten modules and a single cause destroys the same life ONCE - the first call returns true and
         the second returns false, so the de-duplication gate is real and is measured.
   HELD  T05: after a death the state reports destroyed true with all ten of its module keys intact and a respawn service
         present, so the life can close and re-enter keeping the vehicle and its loadout.
   GAP   T02: the director report carries hits, penetrations, kills, deaths and last death, but its per shot de-duplication
         sets are empty and no contribution ledger class exists at all, so a fixed attribution version cannot be shown.
   GAP   T03: ONE EVENT WAS PRODUCED IN THE TICK AND NO DEATH EVENT EXISTS IN THE STREAM, because the state the scene
         built by hand is not the state the director commits into. That is a wiring fault in the harness, named here so
         the next pass wires a fresh state per scene and a director that has actually begun.
   GAP   T04: a stale cause is refused, which is right, but the attribution of a round already in flight is not something
         this build can read yet, and the case needs the ledger to judge it.
   GAP   T06: finishing the match returns false and the match identity still reads as zero, because the director was never
         begun in this harness - again a wiring fault, not a product finding.
The honest summary is that the scenes are a FIRST PASS whose own readings show the harness is not yet wired to the match
lifecycle, and that two of the six expectations already hold on the machinery that exists. The next pass fixes the wiring
first - a fresh match state and a proper director begin per scene - so that the four remaining readings mean something.
```

## 4. Second pass: the harness is real now, and the four remaining readings mean something
```
The first pass built its match state by hand; this pass uses the fixture the existing match suite proved - a real TeamRange
scene added to the tree and awaited until the director has spawned and committed its opening events - and gives EACH case
its own scene. The difference is visible in every reading: match identities 101 through 107, nine committed events and a
sequence of nine in every case, where the first pass had zero of all three.
WHAT NOW HOLDS:
  T01 the hull carries eight modules, destroy_once returns true then FALSE, and a death event of kind death really lands
      in the versioned stream, so one firing destroys at most once and the de-duplication gate is real.
  T06 finishing returns TRUE then FALSE, so the end is frozen; the sequence advances from nine to ten; the next match
      carries its own identity 107 against 106; and the finished match still holds all ten of its events, so the ledger
      keeps its history.
WHAT IS NOW PROPERLY DIAGNOSED RATHER THAN GUESSED:
  T03 one tick produced EXACTLY ONE death event and the ticket count moved 300 to 270 exactly once, which is the substance
      the order names. My condition also demanded a director report field that this path does not update, and I then read
      the ticket AFTER-value before the death had happened - two device faults of mine, both now named, neither of them a
      product finding.
  T04 the de-duplication holds (first true, repeat false) but no contribution ledger class exists at all, which is the
      genuine gap this sub-order exists to close.
  T02 the director per shot de-duplication sets stayed empty after two identical contacts, so either my contact record
      does not match the shape observe_contact expects or the registration does not happen on this path; that has to be
      measured rather than assumed.
  T05 the hull is destroyed with all eight module keys preserved and a respawn service present, which is the loadout half;
      the acceptance condition failed on the same director report field as T03, again mine rather than the product.
NO PRODUCTION CODE WAS CHANGED, and no delivered expectation was edited at any point in either pass.
```
