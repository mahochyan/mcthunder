# 007 实现方案（2026-09-08）
用户本轮明确要求按交接计划完成后续开发，目标为体素/低模方块风、尽可能还原战争雷霆陆战内容。此授权替代旧逐单等待和 007 未授权条款；仍保留历史签收记录、不代签真人、不默认合并 main。

起点 3a9326ddebc9c1ca88dadaf3d0943bcad7601641；开发目录 E:/AIprogram/mcthunder-development，分支 work/007-armor-resolution，原主目录保持 main 及全部未跟踪文件。
完整继承计划：docs/handoff/DEVELOPMENT_007_036.md。依次推进 007—036，037 以后作为远期路线保存。不能把计划写成完成状态。

## 先修已复现错误
上一轮核验的真实日志保留在 C:/Users/lapyin/AppData/Local/Temp/mcthunder-audit-75906485b6f64f7da9ad66486de83964/。
先入树再设特效 global_position、先入树再对测试墙 look_at。新检查运行器须区分预期负例 ERROR 与意外引擎错误。

## 核心接口
- PenetrationCurve.validate/sample_mm：有限、非负、距离严格递增、穿深不递增；线性插值并夹到端点。
- ArmorResolver.resolve：纯函数，接触时速度方向、厚度/法线、当前距离预算；给出穿透/穿孔停止/未穿/跳弹/次数上限/未知/掠射/无效结果。
- ProjectileManager：唯一推进；预算 scale/consumed 与 curve 在发射时冻结；剩余时间循环，接触后重新规划；同面起点去重；8 接触/步、32 接触/发。
- projectile_contact 与 projectile_finished 分开；contact_index 单调；先提交预算与记录再通知，回调重置后不可续飞。每发每目标生命期只触发一次首次接触计分。
- 旧 006 的 ap_75 配置及旧数学/弹道夹具显式 legacy_contact_only；正式 armor 模式拒绝无效曲线，UNKNOWN 不回退为 0。
- ArmorRange 通过现有 VehicleActor/PlayerController/Gunner/ProjectileManager 发射，无第二份射击代码。薄/厚/斜/双层/跳弹/UNKNOWN 训练板进入真实布局快照，世界背墙单独碰撞。

## 规则与验证
P(s)=max(0,k*P_base(s)-C)；每层消耗等效厚度。75 度跳弹、速度乘0.6、k与C同时乘0.5、最多一次；背面仍计成本，近90度保守停止；全部为 TEST ONLY 游戏近似。
纯逻辑黄金值、真实管理器多层/重力/墙/回调/暂停/上限反例、玩家入口/命令射击、现有四套回归和真实窗口截图分别留证。
通过工程自审后推进 008；human 保持 not_run，content_history 保持 test_only/research。
