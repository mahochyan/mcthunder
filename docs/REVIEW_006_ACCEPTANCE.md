# REVIEW 006 ACCEPTANCE — 有限速度炮弹、重力与连续路径检测

状态：accepted（正式签收记录，依 GPT 裁决正文登记；登记提交不替代 accepted_sha）
签收范围：projectile_flight_engineering_baseline_with_carryover

## 机器可读登记（GPT 裁决正文，不依赖附件）

```
ORDER = 006
STATUS = accepted
ACCEPTANCE_SCOPE = projectile_flight_engineering_baseline_with_carryover

ACCEPTED_SHA = 17f4e23974382d80def2cf3a0fa31d3b3f7f3e0a
TESTED_CODE_SHA = 5d2c0bbb121b7add15408e30a18af785f1c3cebe
EVIDENCE_COMMIT = 17f4e23974382d80def2cf3a0fa31d3b3f7f3e0a

006_R1_STATUS = closed
FINITE_CLOSEOUT_STATUS = closed
REVIEW_METHOD = source_and_submitted_execution_evidence

INDEPENDENT_GODOT_RUN = NOT_RUN
HUMAN_ACCEPTANCE = NOT_RUN
SCREENSHOT_VISUAL_REVIEW = NOT_REVIEWED
```

分支：work/006-projectile-flight（ACCEPTED_SHA 的直接父提交即 TESTED_CODE_SHA；main 仍在 29376e20…，未合并 main，无强推）。

## 签收范围（GPT 裁决原文要点）

本次签收覆盖此前已认可的：有限初速、重力推进、完整子段路径查询、实际接触后反馈、
出生 tick 门、射程裁短、弹药与容量管理、暂停冻结、取消清理，以及飞弹显示层
（ProjectileVisuals）、近远射道和不同实际渲染帧率的对照。可作为后续装甲接触处理的
工程基础，但不是完整游戏或历史弹道真实性认证。

裁决要点：
- 取消过程发射门通过：try_spawn 在占容量/记身份/编号前依次检查退出状态/在树内/排队
  删除/清理深度/暂停；清理期间明确 manager_clearing；cancel_all 与 cancel_by_shooter
  共用 _cancel_depth、出口递减、finish_once 逐发移除；末尾整表清空已删除。
- 重入与嵌套取消测试覆盖原失败路径（同步监听者内调用生产 try_spawn，未手工设门）。
- 0.9m 接触时间真值 = 0.9/300 = 0.003s（容差 5×10⁻⁵；生产公式未改）。
- 路程边界三案例区分：首接触面 1.9m/上限前正常接触；2.0m/端点接触优先 impact_world；
  2.1m/不得命中 expired_distance 停在 2.0m。

## 证据

- 无头：logs/006-R1/<tested_sha>/（四套 144/214/140/123 全绿，退出码 0，stderr 脚本错误 0；
  RUN_METADATA.md 含修复前 7 项反例先红记录）。
- 画面：docs/evidence/006-R1/ac8bfb3…/1280x720/{15,60}fps/（实际帧率 15.0 vs 60.0 分离，
  撞击数据逐字节一致；PNG NOT_REVIEWED）。
- 006-R1 整改记录：docs/DELIVERY_006_R1.md（含 6. 有限收尾节）；
  授权单 docs/planning/work_orders/WO006_R1_authorized.md。

## 保留事项（按既有决定继续管理，不降低目标）

| 项目 | 状态 |
|---|---|
| 真人操作、手感、系统级失焦切回、UI 可读性 | NOT_RUN，最迟 011 核心体验签收前，针对当时版本完成 |
| 既有 12 张演示截图目视 | NOT_REVIEWED，保留原被测 ac8bfb3… 归属 |
| 历史装甲厚度与车型资料完整核验 | UNKNOWN／研究未完成 |
| 七张史料原页转存与目视 | BLOCKED_TRANSFER／NOT_REVIEWED |

## 下一单

RECOMMENDED_NEXT_ORDER = 007（分区装甲、入射角、跳弹与剩余穿透）
007_IMPLEMENTATION_AUTHORIZED = false（仅登记；不自动执行；等待单独下发实现方案与授权）