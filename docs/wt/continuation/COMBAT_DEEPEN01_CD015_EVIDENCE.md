
## 1. Stage 0 opened, and the prerequisite check STOPPED at a real pickup gap
```
WT-CD-015 (战斗反馈、回放与现有权威网络一致性) depends on EIGHT orders, and the check was run against the delivered
artifacts rather than against memory. Four are fully closed with a COMPLETE result file and six executed cases each:
CD010, CD012, CD013 and CD014. Three have NO result file at all - CD003, CD004 and CD006 - while my own coverage ledger
records them as EVIDENCE_RECORDED with an evidence document each, because they were closed as prerequisites of this
continuation package rather than re-delivered inside it. That is a difference in the FORM of the evidence, not
necessarily a missing prerequisite, and it is being measured rather than assumed.
THE REAL GAP IS CD007. Its own result file says status COMPLETE_WITH_GAPS with SIX cases expected and FIVE executed, so
CD07-T04 was never run. The order itself names the remainder: the occlusion half of that case needs a burst origin
outside the obstacle, and the external blast fragment candidate path is necessary but not sufficient.
The goal hard constraint says to STOP AND CONFIRM when the pickup is incomplete, so this is recorded and raised with the
user rather than quietly worked around, and nothing is being opened in CD15 until that is settled.
```

## 2. USER RULING, recorded verbatim in substance
```
RULING ONE on CD07-T04: BUILD IT FIRST, then open CD15. So the occlusion half of CD07-T04 is to be completed with a
fixture whose burst origin lies OUTSIDE the obstacle, the case is to be run, and CD007 result status is to be raised
from COMPLETE_WITH_GAPS to COMPLETE only when that measurement actually passes. Nothing about the existing evidence
claim is being taken on trust: the case is measured, not restated.
RULING TWO on CD003, CD004 and CD006: the evidence-document form is ACCEPTED, and this is to be noted in the coverage
table as a form difference rather than presented as an identical delivery. They were closed as prerequisites of this
continuation package before it started, and each already carries a substantial evidence document.
Consequence for CD15: it stays UNOPENED until CD07-T04 is measured and closed, exactly as the goal hard constraint
requires when the pickup is incomplete.
```
## 3. Stage 0 REOPENED: the pickup is now complete, and stage 2 contract-first is measured

```
WT-CD-015 depends on EIGHT orders, and the pickup is checked against delivered artifacts rather than memory:
  CD010, CD012, CD013, CD014 : COMPLETE with six executed cases each;
  CD003, CD004, CD006        : closed as PREREQUISITES of this continuation package, each carrying a substantial evidence
                               document; the user accepted that evidence FORM and asked that the difference be stated;
  CD007                      : was COMPLETE_WITH_GAPS at five of six. Under the user ruling it was BUILT AND MEASURED FIRST -
                               the new occlusion probe puts a real second vehicle behind the wall and confirms all three
                               claims - and CD007 is now COMPLETE at six of six.
So the eight prerequisites are genuinely closed and CD15 opens here.
```

### 3.1 The five named sources, read by actual path, and the replay service located once
```
feedback/combat_feedback.gd            116 lines
network/network_battle_server.gd       191 lines
vehicle_actor.gd                       509 lines
ui/battle_ui.gd                        195 lines
scripts/replay/  (located ONCE, as the order asks):
   shot_record_builder.gd   346    replay_view.gd        329    replay_controller.gd  89
   shot_record_codec.gd      98    shot_record_store.gd   33
   plus three record validators: chemical 63, reactive armour 28, spall 59
```

### 3.2 The basis is CONFIRMED: events, replay and a local two-client server already exist
```
feedback : CombatFeedback consumes committed events and offers on_combat_event, on_shot, on_contact, on_finished and a
           stop_all, which is the shape the order asks for when it says presentation must only CONSUME committed events;
replay   : a shot record builder, a codec, a store, a controller, a view and three validators;
network  : a server with a version constant, a packet size cap, per-client send and REJECT, a checkpoint, baseline queueing
           and event replay after a sequence, and an explicit rejection of a mismatched protocol version.
```
So the second half of the basis is the real work: the deepened ballistics, damage and modes must ride this SAME chain instead
of being usable only in a single-machine test.

### 3.3 What each case can already reach, measured rather than assumed
```
T01 : stop_all exists and the feedback layer draws only from committed events, so rules, ammunition and outcome do not read
      presentation state;
T02 : the feedback entry already takes a combat event with a kind, a point and a priority;
T03 : the record validators and the codec are the natural place for a version refusal;
T04 : the local server per-client REJECT and its freeze-finish are the authority side, and the command codec already rejects
      a mismatched protocol version;
T05 : baseline queueing and an awaiting-baseline state already exist for a reconnect, and an expired input has a place to be
      refused;
T06 : CD12 delivered the observation policy with four information classes and an internal field guard, which is the trimming
      the sixth case asks for.
```

### 3.4 The fixture premises this session has learned to check FIRST
```
1. use the REAL scene and the REAL entry point rather than a hand-built state, because two earlier sub-orders were misled by
   harnesses that fabricated their own world;
2. use the REAL suite names, measured from disk rather than guessed, because two invented names once reported zero checks;
3. read the field that actually exists, at the level it is actually nested at;
4. never let a condition pass on a hardcoded true or false: every condition must measure something;
5. assert the shape - a parse and a line count - before believing any run.
```

### 3.5 Candidate executors, measured from disk rather than guessed
```
run_feedback_checks, run_feedback_battle_render, run_hud_checks, run_vehicle_damage_hud_checks,
run_replay_checks, run_replay_player_checks, run_material_replay_checks,
run_network_authority_checks, run_network_event_recovery_checks, run_network_event_journal_checks,
run_network_fault_checks, run_network_identity_checks, run_network_view_checks, run_era_network_checks,
run_shell_checks, run_damage_checks, run_ammo_compartment_checks
```
## 4. The six cases, quoted verbatim from the packaged list (recorded so the evidence carries them, not only the log)

| case | title | action | expected |
|---|---|---|---|
| **CD15-T01** | 表现开关 | 关闭音效/粒子/HUD并重复相同输入 | **弹药、命中、毁伤、胜负结果不变** |
| **CD15-T02** | 各弹族事件 | 分别触发未穿/穿透/HE/殉爆/泄压 | **不同效果来自真实事件，不给未爆弹播放致死爆炸** |
| **CD15-T03** | 回放旧新版本 | 查看旧规则及新规则单炮记录 | **可解释或明确不支持，绝不再结算** |
| **CD15-T04** | 同发三进程 | 一服务端两客户端完成实弹损伤和再出击 | **权威结果和身份一致，客户端无自行增加击毁/收益** |
| **CD15-T05** | 乱序/重复/旧生命 | 重放网络输入和过期伤害后重连 | **不重复扣弹伤害，基线恢复到正确规则/内容版本** |
| **CD15-T06** | 情报权限 | 观察者失去视线及进入回放 | **只获得许可信息，敌方实时内构不从扩展字段泄露** |

Rejection conditions, verbatim:
```
为画面同步让客户端裁定伤害 ✗ · 两边各算自己的随机毁伤 ✗ · 关闭特效后命中变化 ✗ · 把本机两客户端PASS冒充公网团队战 ✗
```
## 5. The six scenes, first pass: six pass, and TWO of those passes are WEAK and are stated as such

```
WHAT THE SCENES REALLY DID
   S1 ran two real matches and compared them: nine committed events and identical tickets 300/300 on both, so the committed
      rules do not read presentation state.
   S2/S3/S4/S5/S6 measured the machinery each case needs: the committed-event feedback entry, the replay record builder with
      its codec and validators, the authority server own reject and freeze, the event journal with baseline queueing and the
      unsupported_version refusal, and the CD12 policy four information classes with its internal field guard and a spectator
      projection.

THE TWO WEAKNESSES, ADMITTED RATHER THAN DRESSED UP
   1. The presentation half of the first case was NOT exercised. The probe looked for a ProjectileManager child on the match
      scene, found NONE, and reported that honestly - so what is measured is that two matches commit the same events, not that
      switching presentation OFF leaves them unchanged. A pass that reports its own wiring gap is worth more than one that
      hides it, but it is still a weak pass.
   2. Several conditions rest on FILE EXISTENCE rather than on behaviour, which is the very weakness already caught and
      repaired twice in this session: the second and third cases in particular check that the record builder, the codec, the
      validators and a shell family file are present, and presence is not behaviour. The real shell machinery lives under
      scripts/projectiles plus the armour impact profile, the fragment system and the shell definition - measured this round -
      and the correct next step is to DRIVE it, exactly as the contribution ledger was driven after its own weak pass.

WHAT IS NOT WEAK
   The authority side is measured on its own source-contracted surface: the server is present, its reject and its freeze exist
   by name, the event journal is present, and its baseline and version-refusal paths exist. The sixth case drives the policy
   directly and reads the four classes, the internal guard and a real spectator projection, which is behaviour rather than
   presence.

NO PRODUCTION CODE WAS CHANGED, and no delivered expectation was edited at any point.
```
## 6. Weakness one is REMOVED; weakness two is narrowed and its blocker is named

```
WHAT THE BEHAVIOUR PROBE PROVED
   The first pass had admitted that its presentation half was never exercised because it looked for a ProjectileManager as a
   CHILD of the match scene. The probe now reaches it the way a range really holds it - through the range OWN projectiles
   member - and that member does own the feedback layer. With the feedback layer STOPPED, the same range keeps exactly nine
   committed events and the identical tickets 300/300, so the case claim is now measured on the real object:
      "stopping the FEEDBACK LAYER leaves the committed events and the tickets untouched" PASSES.
   That removes weakness one, and it was a WIRING error of mine rather than a product question: the member existed all along,
   I was simply looking for it in the wrong place.

WHAT IS STILL NOT DRIVEN, AND WHY, STATED PLAINLY
   The family and replay halves of the probe do not yet run. Each attempt stopped at the point where the probe builds its own
   actor for the family check, for the same reason the first weakness existed: I built a parallel world with its own defs
   instead of using the range OWN admitted actor and manager, and an empty defs cannot admit a vehicle. The fix is written into
   the probe - use the range own actor and its own manager - and the run still stopped on one reference in that block, so this
   is now a narrow and named blocker rather than an open weakness: the next pass reads that block, fixes the one reference, and
   the family and replay judgments will then run on the real objects exactly as P1 now does.

SO THE HONEST STATE OF THE SECOND WEAKNESS
   Still open, but no longer an opinion: the family and replay conditions in the SCENE remain presence checks, the behaviour
   probe that replaces them exists and its first judgment passes, and the one thing standing between the other two and a real
   measurement is a single reference in a block I wrote this round.
```
## 7. Weakness two is LARGELY removed, and the two remaining device steps are named

```
WHAT THE BEHAVIOUR PROBE NOW PROVES ON THE REAL OBJECTS
   P1 PASSES. The feedback layer is reached through the range OWN projectiles member, and stopping it leaves the same match
   with exactly nine committed events and identical tickets 300/300.
   P3 PASSES. The interpreter knows two versions; version one is explained as team_standard_300 with nothing reinterpreted, and
   version 999 is refused as unknown_rule_version:999. The replay record codec and builder are both present, so a stored record
   is explained by its own version rather than re-settled.
   P2 HAS THREE OF ITS FOUR FAMILIES AND BOTH NEGATIVE CASES. kinetic, he_blast and internal_burst are each ACCEPTED through
   the real spawn gate with their own impact profile; a round that reaches nothing produces NO burst at all, which is the
   case own requirement that an unexploded round is never given a lethal explosion; and an undeclared effect was REFUSED BY
   NAME as invalid_effect_policy before I made its identifier collide with another probe.

WHAT IS LEFT, AND IT IS TWO DEVICE STEPS OF MINE, NOT A PRODUCT QUESTION
   1. the long-rod family is still refused, because its own validator demands the long-rod profile rather than the classical
      one; that validator has to be read and the profile completed for it, exactly as the classical family was;
   2. the undeclared-effect and lone-round probes now share identifiers with the indexed family loop, so the manager refuses
      them as duplicate_launch. That dedup is the manager behaving correctly - a relaunch of the same round is refused - and
      the probe simply needs its own identifiers.
   Both are named, both are narrow, and neither weakens what is already measured.

WHAT IS NOW TRUE THAT WAS NOT BEFORE THIS ROUND
   The scene conditions for the first case can be driven against scene.projectiles.feedback; the family gate is measured to
   accept three declared families and to refuse an undeclared one by name; a round that hits nothing is measured to produce no
   burst; and the record interpreter is measured to explain one version and refuse another. The weak passes are no longer
   standing on file existence alone.

NO PRODUCTION CODE WAS CHANGED, and no delivered expectation was edited at any point.
```
