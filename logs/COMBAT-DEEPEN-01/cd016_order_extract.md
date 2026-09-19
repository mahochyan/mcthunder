# WT-CD-016 as the package states it (verbatim, read-only source)

```json
{
  "id": "WT-CD-016",
  "title": "对标矩阵、两车完成样片与独立交付",
  "priority": "P1出口",
  "phase": "G4",
  "depends_on": [
    "WT-CD-001",
    "WT-CD-002",
    "WT-CD-003",
    "WT-CD-004",
    "WT-CD-005",
    "WT-CD-006",
    "WT-CD-007",
    "WT-CD-008",
    "WT-CD-009",
    "WT-CD-010",
    "WT-CD-011",
    "WT-CD-012",
    "WT-CD-013",
    "WT-CD-014",
    "WT-CD-015"
  ],
  "related_parent_orders": [
    "WT-016",
    "WT-023",
    "WT-029",
    "WT-038"
  ],
  "status": "planned",
  "scope": "core",
  "basis": "当前有可玩内部包及专项证据；新规则必须再绑定同一源码/内容/包验证，不能继承旧版本PASS。",
  "player_outcome": "从正常车库选两辆现代车之一，在同一独立包内完成可理解的战斗、恢复、死亡、再出击和保存。",
  "read_first": [
    "tests/build_release.ps1",
    "tests/run_suite_checks.ps1",
    "tests/run_modern_player_flow.ps1",
    "tests/run_player_flow_checks.ps1",
    "docs/wt/continuation/（最新入口文档）"
  ],
  "design_requirements": [
    "对照层分为公开机制符合、标准夹具符合、同条件战雷行为接近、真人体验接受四项，不以其中一个代替其余。",
    "每条外部对照绑定战雷版本/模式/车型改型/弹药/距离角度/装填与乘员条件/来源及取证时间；未知保留NOT_COMPARED。",
    "两车核心样片+至少一辆历史AP/APHE回归车+开放舱HE夹具；不要求这阶段把113模型全部战斗化。",
    "内部包必需内容为两现代车、各自弹种/装甲/模块、河谷和正常入口；缺任一不能降级历史车后声明通过。",
    "正常整局不要求为了证据强行产生所有伤害；专项夹具补罕见条件，明确来源。自然局与受控损伤不拼成一场。",
    "release_ready=false/public_release=false/human=PENDING/performance=HOLD_BY_USER。相似度只对已比较行为报告，不给伪精确总百分比。"
  ],
  "implementation_steps": [
    "每单完成即维护对照矩阵，最后只汇总事实，不开始新一轮全面文件搜寻。",
    "集成最新获准UI与后端提交，保留用户制作中资源，按确定提交快照构建。",
    "先短门禁/专项，再当前包的两车入口/正常对局/实弹同生命/下一局/关闭重启。",
    "独立目录验证不依赖logs、源码树和外部制作路径，缺资源真实失败。",
    "保留旧包和回退提交，源码被测身份和证据后续提交分开。"
  ],
  "deliverables": [
    "两车现代河谷内部开发包及manifest/hashes",
    "对标矩阵及未比较项",
    "整局/专项/重启证据索引",
    "已知问题、旧档迁移和回退说明"
  ],
  "rejection_conditions": [
    "把文件数量或PASS数当相似度",
    "同一项目检查器自证战雷一致",
    "必需工程车缺资源后换训练车通过",
    "未运行的最终包套用旧包证据"
  ],
  "source_ids": [
    "R11",
    "W01",
    "W02",
    "W03",
    "W04",
    "W05",
    "W06",
    "W07"
  ],
  "acceptance_case_ids": [
    "CD16-T01",
    "CD16-T02",
    "CD16-T03",
    "CD16-T04",
    "CD16-T05",
    "CD16-T06"
  ]
}
```

## Six acceptance cases

### CD16-T01 | 版本锁定与证据完整性

```json
{
  "id": "CD16-T01",
  "work_order": "WT-CD-016",
  "title": "版本锁定与证据完整性",
  "setup": "版本锁定与证据完整性",
  "action": "从明确集成提交生成包并核对全部identity",
  "expected": "源码/内容/规则/包身份能追溯，UNKNOWN exit和脚本错误拒收",
  "status": "NOT_RUN",
  "tested_sha": null,
  "evidence_paths": [],
  "origin": "proposed_project_acceptance",
  "evidence_level": "must_be_recorded_by_implementer"
}
```

### CD16-T02 | 两车入口与配装

```json
{
  "id": "CD16-T02",
  "work_order": "WT-CD-016",
  "title": "两车入口与配装",
  "setup": "两车入口与配装",
  "action": "正常UI分别选择T-80B和豹2A4进入河谷",
  "expected": "实际车型/弹药/模型/布局一致，缺必需资源不能降级",
  "status": "NOT_RUN",
  "tested_sha": null,
  "evidence_paths": [],
  "origin": "proposed_project_acceptance",
  "evidence_level": "must_be_recorded_by_implementer"
}
```

### CD16-T03 | 正常完整对局

```json
{
  "id": "CD16-T03",
  "work_order": "WT-CD-016",
  "title": "正常完整对局",
  "setup": "正常完整对局",
  "action": "正常操作/可记录AI按冻结规则完成一局再开一局",
  "expected": "真实票池/伤害/恢复/终局，下一局无旧事件污染",
  "status": "NOT_RUN",
  "tested_sha": null,
  "evidence_paths": [],
  "origin": "proposed_project_acceptance",
  "evidence_level": "must_be_recorded_by_implementer"
}
```

### CD16-T04 | 同生命实弹再出击

```json
{
  "id": "CD16-T04",
  "work_order": "WT-CD-016",
  "title": "同生命实弹再出击",
  "setup": "同生命实弹再出击",
  "action": "从包内受控实弹夹具产生玩家阵亡并正常点击",
  "expected": "死亡/扣票/新生命配置/可驾驶可开火连续有证据",
  "status": "NOT_RUN",
  "tested_sha": null,
  "evidence_paths": [],
  "origin": "proposed_project_acceptance",
  "evidence_level": "must_be_recorded_by_implementer"
}
```

### CD16-T05 | 历史与开放舱兼容

```json
{
  "id": "CD16-T05",
  "work_order": "WT-CD-016",
  "title": "历史与开放舱兼容",
  "setup": "历史与开放舱兼容",
  "action": "运行旧AP/APHE回归和新HE代表场景",
  "expected": "旧规则不被静默改写，新HE对标按本次版本声明",
  "status": "NOT_RUN",
  "tested_sha": null,
  "evidence_paths": [],
  "origin": "proposed_project_acceptance",
  "evidence_level": "must_be_recorded_by_implementer"
}
```

### CD16-T06 | 关闭重启和独立路径

```json
{
  "id": "CD16-T06",
  "work_order": "WT-CD-016",
  "title": "关闭重启和独立路径",
  "setup": "关闭重启和独立路径",
  "action": "新目录启动、保存、关闭、独立进程重启",
  "expected": "配装/研究/设置按版本恢复，不读开发目录补资源",
  "status": "NOT_RUN",
  "tested_sha": null,
  "evidence_paths": [],
  "origin": "proposed_project_acceptance",
  "evidence_level": "must_be_recorded_by_implementer"
}
```
