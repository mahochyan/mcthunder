像素战雷 / mcthunder：从工作单001到可交付v1.0的执行包
制定日期：2026年9月7日。此包是计划，不是游戏代码或已完成证明。

你只做三件事：
1. 把ZIP里的docs文件夹合并到本地mcthunder工程根目录。
   正确位置：mcthunder/docs/planning/work_orders/WO002.md。
   不用新建游戏，不要删除当前代码。遇到同名文件先让Codex比较，不直接覆盖。
2. 把docs/planning/NEXT_CODEX_MESSAGE.txt的内容发给Codex，本轮只执行002。
3. 它推送后，把分支、提交SHA、DELIVERY_002.md和你的实机反馈发回本对话。
   审核未过就修复同一单；通过后才授权下一单。

完整范围看 MASTER_PLAN.md。
规则细节看 GAME_RULES.md。
AI工作约束看 EXECUTION_PROTOCOL.md。
每张可执行工作单都在 work_orders/。
测试矩阵看 TEST_MATRIX.md，所有项目当前都是“未执行”。
ALL_WORK_ORDERS.md只是汇编，不能作为一次全部开发的指令。

当前状态：仓库已有001工程和自述交付；本次仅阅读了仓库资料，
没有在此环境运行该工程，没有对001进行完整代码审查或签收，
没有把这些计划写入远程仓库。
002专门负责补验收、修整和冻结基线。

全部35张后续工作单为002—036。
不按工作单数量推算工期；不把“计划已写完”当作“游戏已完成”。
