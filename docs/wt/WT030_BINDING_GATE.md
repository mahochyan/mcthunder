# WT-030：现代模型显式绑定检查门

2026-09-12接续：绑定已接入车辆包、实际运行装配及原始GLB导出，见WT030_MODEL_PACKAGE_BINDING.md；下方“API尚未接入”描述此前独立工具阶段。两款现代模型仍未交付为战斗车。

2026-09-12，独立工具已由主任务完成Godot导入及63项专项，全部通过；本子任务已只读核实日志。
**当前API尚未接入VehicleContentPipeline或自动上架流程**，两份真实候选模型仍维持拒绝。

## 范围与现有工具的关系

`authoring/reference_data/inspect_model_candidates.gd`已有冻结快照SHA256、实际节点/变换、
网格包围盒与三角数检查，证据见`WT030_MODEL_INSPECTION.md`。它保留候选身份，
没有验证战斗节点及内构绑定。因此本增量只新增
`scripts/content/model_binding_validator.gd`、`tests/run_model_binding_checks.gd`和本文。
没有修改原inspector、VehicleDefinition、Actor、VehicleContentPipeline、装填代码或外部模型。

该门只回答“这份明确声明是否与指定模型及布局挂点一致”。它不是车型准入器，
不生成或猜测节点，不修GLB，不写回来源，不把包围盒/可读网格当史料或完整可战验收。
现有装甲/布局完整性、弹种、证据、模型许可证与玩家体验门仍分别执行。

## 接口

```gdscript
ModelBindingValidator.check_file(binding, expected_vehicle_id, source_record, layout)
ModelBindingValidator.check_scene(binding, expected_vehicle_id, model_root, layout)
```

`check_file`接受独立可信的来源登记项`{id,path,sha256}`，与现有
`MODEL_INSPECTION_INPUT.json.models`字段兼容。车型请求ID、绑定ID、模型source_vehicle_id、
来源登记ID必须精确相同；声明路径/哈希必须匹配登记，再读取指定文件验证实际SHA256并用
GLTFDocument生成场景。文件名或相似车型不会补偿身份不一致。

`check_scene`用于已实例化场景的结构检查和合成夹具，不读取文件；
它始终返回`artifact_verified=false`，其成功不能证明场景来自声明的GLB。
上层如要作文件绑定准入，应使用`check_file`并要求`ok && artifact_verified`。

返回字段：`ok`、`status`（`binding_checked`/`rejected`）、`errors:Array[String]`、
`scope=model_binding_only`、`artifact_verified`、`historical_verified=false`、
`vehicle_admission=unchanged`与`measured`（米制全模型包围盒、网格数、明确路径）。
文件字节与来源匹配、GLB可读取时，即使后续绑定被拒，`artifact_verified`也可为true；
必须同时检查`ok`。工具不创建`validated`车型，也不修改传入节点或资源。

## schema_version 1

以下是合成夹具契约，不是T-80B、豹2A4参数或完成包：

```json
{
  "schema_version": 1,
  "vehicle_id": "test_binding_vehicle",
  "model": {
    "source_vehicle_id": "test_binding_vehicle",
    "path": "res://path/to/explicit.glb",
    "sha256": "<64 hexadecimal characters from the actual artifact>"
  },
  "units": {
    "source_unit": "m",
    "meters_per_unit": 1.0,
    "dimensions_m": [2, 1, 4],
    "tolerance_fraction": 0.001,
    "attachment_tolerance_m": 0.001
  },
  "nodes": {
    "hull": "Vehicle",
    "turret": "Vehicle/Turret",
    "gun": "Vehicle/Turret/Gun",
    "muzzle": "Vehicle/Turret/Gun/Muzzle",
    "running_left": "Vehicle/RunningLeft",
    "running_right": "Vehicle/RunningRight"
  },
  "axes": {
    "turret": {"space": "local", "axis": [0,1,0], "limits_deg": [-180,180]},
    "gun": {"space": "local", "axis": [1,0,0], "limits_deg": [-10,20]}
  },
  "internal_attachments": {
    "modules": {"engine": "Vehicle/EngineAnchor"},
    "crew": {"gunner": "Vehicle/Turret/GunnerAnchor"}
  }
}
```

单位只接受明确的m/cm/mm转换（1/0.01/0.001），不从外观猜比例。
场景内所有Node3D必须是有限、正定、无缩放/剪切/镜像的刚体变换，不能用top_level逃离父链。
厘米/毫米模型的单位转换独立于节点变换声明；工具不自动应用缩放。
全模型包围盒包含炮管/天线等附件，`dimensions_m`只是绑定者声明的工程包络，不能作历史尺寸证据。
允许误差必须明确填写；最大包络容差10%、挂点容差0.1m为本工具的保守工程界限，
示例值和界限均不是车型实测或已冻结产品性能目标。

六个角色必须各自绑定规范相对路径，禁止绝对路径、`..`、属性子路径、`%`快捷名和重复角色节点。
turret在hull下，gun在turret下，muzzle在gun下；左右轮履在hull下且彼此、与炮塔独立，
左右锚点位于车体X轴对应侧。中间刚体组织节点可以存在，不要求所有角色直接一层父子。
现有机构只接受局部+Y炮塔轴、+X俯仰轴，并检查实际枢轴相对父部件的轴向；
角域必须有限、有序且位于-180..180度内。这里校验声明及轴映射，不模拟限位碰撞或机构战损。

Muzzle必须显式存在，为无网格的叶子Node3D或Marker3D，位于炮管枢轴前方且朝炮管-Z。
Blender Empty导入GLB后可能只是Node3D，所以不强制Godot专有Marker3D类型。

必须传入车型身份一致且含装甲、模块、乘员条目的战斗布局。
每个模块和乘员ID都需明确挂点；多写未知ID、漏挂、错可动父部件、挂点位姿不匹配均拒绝。
挂点相对所属part的刚体朝向和米制位置必须与layout.local_box_transform一致。
布局part映射为hull/turret/barrel→hull/turret/gun，running_left/right同名，drive→hull。
这些检查不替代LayoutValidator：合成专项的最小布局仅用于检查绑定行为，不宣称通过完整布局门。

## 首批候选缺口与测试边界

两车准确哈希已在本轮通过只读SHA256核对，与冻结输入清单相同：

- germ_leopard_2a4：`4e7a35151a6452a8b5db738f42b729765107fc06980cd1262bce5cbe08e8bd88`。
- ussr_t_80b：`8f47a0a27d254e3d677a7f0baf78c3c081586cd75f126f3e7751fcb94a3ae5af`。

既有真实节点清单显示两车有TurretPivot/GunPivot，缺独立Muzzle；未交付明确左右轮履绑定组、
同车型装甲/内构及挂点。T-80B的外观薄片问题见模型核查文档。本门不创建缺失物。
专项对两冻结GLB设置的是明确的“期望缺项反例”，不是作者批准的绑定声明；
实际执行证明文件字节正确，但两车均缺声明路径下的Muzzle、RunningLeft/RunningRight，
并缺匹配战斗布局，因此仍拒绝且保持candidate_only。这不表示模型没有任何轮履网格；
当前缺的是可供机构绑定的明确分组路径及完整挂接声明。

`tests/run_model_binding_checks.gd`还覆盖米/厘米合成场景、JSON解析、规范路径、同名错车型、
错误单位/尺寸、NaN、缩放/剪切/反射、父链、枢轴方向、炮口及内构位置与朝向，
并检查调用不修改输入配置/场景。

真实证据目录：`logs/WT-parallel/5787094-model-binding-wip9/20260912-172624/`。
`RESULTS.json`记载Godot 4.7.2的import和`run_model_binding_checks`均exit_code=0、
passed=true、script_error=false；专项stdout为63项、0失败并含`MODEL_BINDING_CHECKS_PASS`，
stderr为0字节。`CANDIDATE_GAPS`逐车列出上述缺项，相关断言同时确认哈希未变、
错来源车型ID被拒和伪造SHA256不能覆盖实际字节。该目录当前没有`SOURCE_MANIFEST.json`，
因此本文不声称已通过源码清单逐文件哈希核对；结果中的source_sha为
`5787094-model-binding-wip9`工作树标签，不冒称5787094基线提交已包含新增API。

这次是独立绑定工程检查通过，未进行完整车型实战/外观史料/真人验收，亦未对两份GLB授予车型准入。

上层接入建议：在完整车辆包已有可信模型来源登记和已验证战斗layout后调用`check_file`，
成功结果作为独立工程检查证据再交既有VCP/内容目录处理；本批不修改共享接入位置。
