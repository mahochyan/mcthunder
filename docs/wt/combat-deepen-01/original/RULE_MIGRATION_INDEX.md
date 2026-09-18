# 规则迁移入口索引（本次补发编排，不是原包旧文件）

原始依据：`original/05_DELIVERY_AND_ACCEPTANCE.md` §6；`original/templates/RULE_CHANGE.template.json`；每张子单的“必须设计/实现顺序”。

| 要求 | 原始依据与填法 |
|---|---|
| old_rule_version/new_rule_version | RULE_CHANGE模板；记录实际版本，不编造已部署版本 |
| affected_vehicles/affected_modes | 每次真实变更填写，不一概改全部车型 |
| fields/reason/reference_sources | 明确字段变化、规则语义、来源与项目选择 |
| old_reference_unchanged | 原始参考档不修改；工程配置及证据claim一致更新 |
| legacy_behavior_retained/legacy_tests | 保留原规则的独立入口及相关检查，范围记在迁移结果中 |
| new_expected_declared_before_run/independent_oracle | 先冻结期望与容差，不用被测函数生成自己的期望 |
| migration/rollback | 旧配置、存档、回放的迁移或明确拒绝；回退脚本/提交及档案边界 |
| divergences | 与对标规则不同或未经比较的内容明确列出 |

模板原本没有名为`legacy_tests`的独立字段；可以在现有迁移说明/本地扩展schema中记录测试清单，必须标识自己的schema变更，不能声称这是原模板已存在字段。

## CD014必须保留的对照

`team_standard_300`为原规则预设；`ground_rb_like_v1`为拟新增预设，不覆盖旧模式。

- CD14-T01：旧模式的正常局/存档语义保持；新增行为只在新预设生效。
- CD14-T06：旧档/旧结果按原版本解释，未知版本明确迁移或拒绝。
- 团队票池、个人SP、局外收益、修理/补弹费用独立；缺真实BR/费用时使用已声明项目值。

原包是规范与空模板，没有任何已经执行过的规则迁移记录。本索引同样不是迁移完成证明。
