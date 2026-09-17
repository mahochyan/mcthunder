# 现代车材料与弹架接续

上一轮为实际进展：7b8d1837 包完成现代正常流程与独立保存、专用生命周期、两车入口、M36 和历史完整流程；2922587b 源码修复按队伍分配车型。本轮保持现代河谷可玩包目标，4v4、最多 A/B/C 三点、原地图与比赛规则。原 main 与外部模型制作成果不改。

## T-80B：未知车体材料导致无法继续结算

通过实际 Actor 的几何查询，对双方各 12 个车体区分别输入对方原有 APFSDS 和 HEAT 规则。基线 `logs/WT040-progress/material-before.log` **81 项、25 失败、exit 1**：T-80B 24 个材料结果均为 unknown_material，侧面 APFSDS 实弹接触真实车体后中止，内部损伤为空。豹 2A4 同类查询正常。没有修改目标几何、穿深或伤害来产生结果。

`authoring/reference_data/restore_t80_materials.py` 从已有 `authoring/reference_data/modern_bound/ussr_t_80b.json` 恢复仅 12 个缺失车体材料的游戏规则（含原设计首上复合响应），通过原包/作者包/实际 GLB 哈希保护迁移。已知炮塔和炮盾材料保持 cast，厚度、几何、弹药、装填和驾驶参数保持。新增 immutable evidence `configs/vehicles/evidence/t80_material_restoration_20260917.json` 保存前后字段和来源；每个原始缺失材料仍有独立 `raw.material.* = null / unknown / warthunder_reference`，用于结算的 `protection.zone.*` 单独登记为 game_rule / estimated。

修复后首次 **83/0**，增加真实 HEAT 弹体/射流检查后 **85/0、exit 0**：两车 24 个区域、双方两类弹种均能得到明确结算；原弹药参数的 APFSDS 与 HEAT 实弹均穿过 T-80B 侧面车体并提交内部损伤。改材料但不改对应独立证据会被拒绝。原始未知记录没有被补写成历史已知。两次日志为 `material-after.log`、`material-two-shells.log`。

## 豹 2A4：弹架和隔离设备在转换时遗漏

生产 Actor 基线 `compartment-before-r2.log` **5 项、3 失败、exit 1**：实际是 10/16/16 三架，两个车体弹架重用同一挂点；没有显式补弹规则、隔板或泄压模块。最早 `compartment-before.log` 是检查脚本类型推断错误，不计为功能基线。

`authoring/reference_data/restore_leopard_stowage.py` 恢复既有作者的 15 待发 / 27 备用、人工装填/补弹 profile、尾舱隔板与泄压模块，逐项校验实际交付 GLB 的直接 part-local 挂点。总容量 42、射击装填时间、弹药参数、外装甲和驾驶数值未改。独立证据为 `configs/vehicles/evidence/leopard_stowage_restoration_20260917.json`。迁移只接回原有规则，不把隔离逻辑描述为真实压力模拟，也未制作动态顶甲开口。

生产包专项 `compartment-after.log` **11/0、exit 0**：T-80B 原 APFSDS 实弹穿过豹炮塔尾部装甲，触发待发架损伤与已实现的隔离规则；损失 14 发存弹，保留 27 发备用及 1 发膛内弹，车组存活，泄压模块消耗。正常计时维修和补弹只搬运剩余库存，不返还损失；下一生命恢复原 42 发。该项是明确的实弹位置夹具，不冒充自然玩家对局。

## 回归与后继

相关源码回归全部 exit 0：装填 23、模块毁伤 29、两弹种实际发射/自然装填 44、材料 85、实际苏德分队 76，总计 **257/0**，日志前缀 `logs/WT040-progress/restored-run_*`。新增两项检查进入现代候选必需构建门。干净源码导入检查 `restored-import.log` 完成。

两迁移已应用，重复运行会因输入身份改变而拒绝。不要重写旧证据。当前成果尚未进入 7b8d1837 包；下一步在修正分队和配置下跑自然整局，再构建后继独立包并验证完整入口链。真人 PENDING、性能 HOLD_BY_USER、10v10/16v16 未验证；内部包保持 release_ready=false、public_release=false。
