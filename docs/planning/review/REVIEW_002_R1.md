# 002-R1 复审记录

日期：2026-09-07
仓库：mahochyan/mcthunder
代码提交：f87de0e9a9f060e3903083f4b52b2eebee9f162f
证据提交：7e658bc684e9700082891960177b100a3c7a71b3
结论：部分完成；002仍needs_revision；本次仅授权002-R2有限收尾，不开始003。

## 审核实际完成了什么
读取远程分支、代码提交、证据提交、相机/炮塔/主流程/测试代码、变异日志、截图日志与docs树。
本地原始规划ZIP通过CRC和SHA检查：55文件，manifest中的54文件尺寸与SHA256全部匹配。
没有在本审核环境独立运行Godot；没有成功下载并目视PNG；不能签Windows真实体验。
尝试在指定仓库新建文档交接分支以解决文件传递，连接返回403 Resource not accessible by integration；未创建分支、未改main或工作分支。故交付包仍需由真人转存一次。

## 可认可的增量
相机已接入aim_pitch；GUI测试已走真实鼠标事件分发；装填冻结改为差值比较；20次重置补全部靶板与位置朝向；截图错误计数/非零退出已在代码中；变异日志补全了可审查的来源与正反例输出。
这些修改保留；认可的是提交内容与证据，不是本审核端独立复跑。

## 尚未关闭

### A：平行不等于同点
相机方向和炮管方向均由同一yaw/pitch决定，但发射线起点与观察线起点不同。一般不能射中相机中心指向的有限距离点。
审阅到的新增测试直接设置10度，调用snap，再检查夹角<5度；没有实际目标收敛、自然追赶或鼠标事件覆盖。
正确应将相机/意图射线选择的世界点P变换成武器目标角，再限速限位跟随，命中仍用炮口真实射线。
公式示意（非游戏实测）：相机C=(0,4,8)、炮根O=(0,1,0)、意图d=(0,0,-1)，靶点P=(0,4,-20)。相机线能过P，炮根沿相同d却始终y=1，不会经过y=4的P；应使用normalize(P-O)。
青色标记由相机中心射线产生，出现在中心不证明炮管指向它。

### B：已补按钮点击，不等于所有输入路径已覆盖
持续持火的GUI段发送了鼠标释放，没有断言之后fire仍处于按住状态。需将GUI点击和Esc恢复下的真正持续持火分开测试。
窗口autoshot仍直接调用_resume/_reset_all，运行中三次重置日志不能代替原单要求的暂停中R与真实Esc/R/F3路径。
现有装填冻结比较是有效增量，保留并补恢复后继续推进。

### C：截图正常路径、失败路径和归档分开
_ shot错误计数与非零退出已写入，提交日志只有双分辨率成功运行，尚不能证明失败负例执行过。
两种分辨率都写同一批docs/autoshot_*.png，日志显示路径一致。当前autoshot_2_sight.png与autoshot_2_sight_1080p.png同一blob：4a61dfa4cc6b5121b79f43e2a9eb4d7f875b521c。相同字节不可能是两个不同像素尺寸的文件。
例如autoshot_1_thirdperson_1080p.png仍为50f8bfc2f91434e008849568362b6c7f413c2c97，和旧证据一致。应保存分SHA、分分辨率的本次原图及manifest，而非证明仅“两个命令退出0”。
此结论不否定执行端运行两次，只否定当前归档足以证明两套新图。

### D：转存阻塞与报告未落库
原ZIP在本对话真实存在并再次校验；附件地址不是可由本地curl读取的公网URL。
7e658bc下README仍含“缺失（原包未包含…）”，未出现报告所称追加更正。应检查本地未提交修改再实际补交，不仅修改交付摘要。

## 后续
按002-R2完成A/B/C技术收尾；原包文件未到D单列BLOCKED_TRANSFER，不能因此空转等待，也不能代签D。
用户实际试玩与目视U002-01/02继续pending。技术通过与用户接受分开，不预授权003。

## 可定位证据
基准路径前缀：https://github.com/mahochyan/mcthunder/blob/7e658bc684e9700082891960177b100a3c7a71b3/
- scripts/camera_rig.gd
- scripts/turret_rig.gd
- scripts/main.gd
- tests/run_checks.gd
- logs/002-R1/mutation_R1_rerun.log
- logs/002-R1/autoshot_R1_dualres.log
- docs/planning/README_先看这里.txt
- docs/DELIVERY_002_R1.md
目录树：https://api.github.com/repos/mahochyan/mcthunder/git/trees/42346532c14e152eece17c0a2cca6efac2fdcfb0
API参考：https://docs.godotengine.org/en/stable/classes/class_input.html
