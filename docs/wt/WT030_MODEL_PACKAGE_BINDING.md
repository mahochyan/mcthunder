# WT-030 模型绑定进入车辆包与运行时

开发基线dd6af774。WT-030保持in_progress，42项要求不删减；性能HOLD、真人NOT_RUN、release_ready=false。本轮不是苏德两车或完整游戏验收。

## 实际接入

VehicleContentPipeline对model_binding检查独立来源、实际GLB字节、单位、可动层级、机构静止位置和限位、炮口与内构锚点。新车型ID必须有绑定；既有四车无绑定包继续旧路径。VehicleCatalog默认读取工程内configs/vehicles/model_sources.json，按准确车型ID登记id/path/sha256/resource_version/delivery_status/provenance，仅delivered/authored_asset可入绑定门；失败不写入车型、武器、布局或车库名册。当前来源表为空，两款现代模型尚未达到交付条件。

注册时深复制来源，由VehicleDefs传给Actor.setup。BoundVehicleModel重新核对哈希，使用通过校验的同一解码场景安装，不验证A文件却加载固定车型名下的B文件，也不读取旧导入缓存。文件必须位于工程assets/vehicles，GLB缓冲和贴图须内嵌，外部依赖在解码前拒绝。准入后改写文件会导致生成失败，失败Actor停止物理并解绑控制器。

hull/turret/gun及左右行走机构各安装一次，挂到实际HullFrame、TurretRig、BarrelPivot及左右框架；厘米/毫米网格在视觉容器中换算成米，查询布局仍以米为单位。源模型的左右分组可在轮心，内构坐标按游戏静止drive原点校验。炮塔、炮管、炮口静止位置及限位必须和战斗包一致，各可动部分须有自己的网格；可见炮管包络须到达炮口前端，工程容差10cm。该门不能代替轮廓史料或完整外观审核。

炮管外观挂到真实后坐容器；绑定车辆接入既有弹药殉爆炮塔脱离和重置。实际炮塔节点携带视觉与查询一起移动。仍是游戏规则，没有新增现代泄压舱、真实爆压或轮系动画声明。旧历史模型的Atlas/细节路径保持兼容，新绑定模型直接使用其GLB视觉，不套用另一份历史manifest。

## 资源包问题及修复

实测Godot普通include_filter只导出GLB的scn替代物，未保留原始字节。在工程目录运行会读到散装原文件而误通过。logs/WT030-model/dd6af774-pack-probe/20260912-184208保存反例：散装目录probe=0；empty_runtime中同一PCK的probe=1、RAW_MODEL_PACK_CHECKS_FAIL。

新增addons/bound_model_export并由project.godot启用。导出时只对登记为delivered的模型核对身份、路径和SHA256，将原始GLB加入PCK；来源错误输出ERROR且不加入原文件，不能当作发布通过。普通导出过滤器已恢复原配置。

修复实测在logs/WT030-model/dd6af774-pack-plugin/20260912-184439：实际import/export/空目录probe均退出0，无ERROR，RAW_MODEL_PACK_CHECKS_PASS。FileAccess及GLTFDocument读取包内原文件成功。这是隔离小资源包验证，不是游戏客户端/专服或全部资源发布验收。

## 验证记录

| 批次 | 通过项 | 目录 |
|---|---|---|
| 新车型ID、发射与生命周期 | 55绑定包、63绑定API、105参考准入、192历史四车、193选弹射击 | logs/WT030-model/dd6af774-binding-wip3/20260912-183812 |
| 产品与网络关联回归 | 55绑定包、151车库、71实际毁伤外观、58真实ENet恢复 | logs/WT030-model/dd6af774-binding-final4/20260912-184032 |
| 最终可见炮管和外部依赖门 | 59绑定包、63独立API | logs/WT030-model/dd6af774-binding-final6/20260912-185016 |
| 最终实际窗口 | 63项，退出0；米/厘米两张图 | logs/WT030-model/wip-uncommitted/window-20260912-185200 |

专项用TEST ONLY新车型ID和既有M24布局生成独占目录GLB，走真实导出、来源验证、注册、Actor.setup、VehicleCommand开火、炮塔脱离和重置；验证单位、可见顶点与查询一致、悬挂与行走独立、实际炮口发射及库存扣除。殉爆原因是明确生命周期夹具，不冒称实际弹架命中；71项旧毁伤外观回归另走实际炮弹。还覆盖错ID/哈希、制作中状态、缺版本、坏来源、缺绑定/炮口、机构限位和静止位置冲突、外部路径、无可见炮管、外部buffer、准入后文件改写。

窗口截图为docs/evidence/WT030-model/wip-uncommitted/window-20260912-185200/bound_m.png及bound_cm.png。此前184550/184832窗口对应较早检查版本，均保留，不混称最终代码。测试夹具只体现模型接线，不是苏德模型或美术交付；生成的临时文件在测试结束后按明确路径清理。最终源码哈希在本批SOURCE_MANIFEST.json收尾保存，不倒填为旧运行的启动前快照。

## 外部模型与后续

本轮只读复核外部两车GLB，T-80B和豹2A4哈希与既有冻结快照一致；T-80B状态仍明确“正在制作：不是最终验收版”。豹2A4的verification PASS仅是其几何检查，不能覆盖缺失的炮口/轮履分组/内构及整车门。两车继续candidate_only，没有上架，也未改动外部制作成果。

MCP只读审查再次成功，指出固定文件名、单位与行走层级冲突，已用于集成。未重试此前失败的外部写入槽，代码由主集成者完成。

继续事项：APFSDS/HEAT与防护材料、苏德两车战斗数据/几何和实际模型交付、履带UV/轮系表现、正式名册与存档迁移、完整驾驶对抗及真人验收。绑定API不自动扫描或发布候选；后续只将通过完整车辆流程的车型加入正式名册。
