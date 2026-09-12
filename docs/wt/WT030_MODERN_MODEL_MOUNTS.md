# 现代模型机构绑定增量 — 2026-09-13

基于 502d4835。T-80B、豹 2A4 的工程内静态模型已经派生为可安装到真实 Actor 的机构模型，保留源模型的中立姿态、真实炮塔轴、炮口与左右行走机构。没有修改外部制作任务的文件。

入口：`authoring/reference_data/build_modern_model_bindings.gd`；适配器：`scripts/content/modern_model_mount_adapter.gd`；派生包：`authoring/reference_data/modern_bound/`；派生 GLB：`assets/vehicles/modern_bound/`。

准确车型 ID、源文件哈希、静态模型审核状态和机构轴均为强校验。错误型号、源哈希变化、制作中状态、缺失行走机构及轴变化会拒绝。源模型全部网格中立姿态保持；炮口由实际炮管端部顶点测量。豹 2A4 约 5.25 cm 的横向炮轴偏移保留。

验证：`logs/WT030-mounts/502d4835-final/20260912-233424/` 中机构 41、绑定 63、车辆包 59、现代候选 56、弹舱 63 项通过（共 282）。`logs/WT030-mounts/wip-uncommitted/window-20260912-234010/` 实际窗口 43 项通过，两款车辆截图已目视。验证真实 Actor 驾驶、炮塔/俯仰、真实炮口发射和扣弹。构建器重复运行，两 GLB 与四 JSON 字节一致，记录在 `logs/WT030-mounts/502d4835-builder/`。

这是机构绑定工程增量。两包仍为 candidate、combat_admitted=false；装甲贴合、内构空间审核、完整自身受弹/战损/恢复和战损外观仍待完成。未开放苏德正式战斗，未将原始候选装甲宣称为已贴合模型。性能专项继续 HOLD；真人体验与整版验收未完成。

用户最新优先级为大型地图设计，后续先推进 10v10 / 16v16 河谷战场方案与环境样板。
