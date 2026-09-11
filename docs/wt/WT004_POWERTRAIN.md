# WT-004 纵向动力首轮

开发基线5fdb679，工作树codex/rc3-playability-fixes。新增DriveProfile与DrivePowertrain并替换TankVehicle原恒定加速度路径，本地玩家、AI和网络服务器继续通过实际Actor命令入口使用同一实现。

玩家现在会经历随速度降低的加速能力、升降动力区间时短暂牵引中断、连续坡度负载，以及反向输入先刹停再按倒车加速度起步。松开控制保留自动停车与坡面驻车行为，前进/倒车仍有限速。不是完整发动机/变速箱物理模型。

## 参数与权威状态

- VehicleDefinition持有只读DriveProfile；运行时gear、shift_left、rpm_fraction、traction_acceleration和braking保存在每辆TankVehicle的powertrain，reset_vehicle会清空。rpm_fraction是归一化等效转速，不是实测RPM；动力区间数不是该历史车型的真实挡位数。
- 加速度为原车型设计加速度乘以`1 - power_falloff * speed_fraction²`，换挡期间再乘shift_power。降挡阈值带迟滞；坡面负载采用实际GroundProbe法线投影得到有符号坡度，连续影响牵引。坡度上限仍独立保护不可通行坡面。
- 默认曲线、4区间、0.18秒换挡是设计值。M4A3独立设计资源采用falloff=0.5、换挡0.24秒；M24为0.3、0.12秒。两者grade_acceleration=4.0是配合原简化加速度的等效坡阻调校，使现有低速车辆保有可用爬坡能力；不宣称真实重力、传动效率或历史爬坡性能。
- 原historical JSON事实与证据内容未改。设计资源放在configs/drive，内容管线显式关联，不将新增曲线混入verified历史字段。

## 真实验证

最终生产文件及配置SHA256见`logs/wt004-drive/SOURCE_FILES.json`；以下日志记录各自命令与退出码。标签中的5fdb679是开发基线加工作树补丁，不冒称基线提交本身已包含实现。

1. `run_suite_checks.ps1 -Suites run_powertrain_checks,run_drive_checks,run_checks,run_network_controller_checks -Order wt004-drive -SourceSha 5fdb679-power-final`：14+25+216+11项通过，证据`logs/wt004-drive/5fdb679-power-final/20260911-140635`。含真实地形、驾驶/射击/重置基础回归与网络命令保留/失效。
2. 此后只给新测试增加历史车真实坡道案例，再跑`run_powertrain_checks`，15项通过，证据`logs/wt004-drive/5fdb679-power-slope-final/20260911-140757`。两辆实际历史Actor相同4秒命令：M4A3行驶15.498m、速度7.318m/s；M24行驶24.139m、速度11.451m/s。M4A3在真实20度碰撞坡面从静止起步，2秒行驶2.229m，末速度1.649m/s、采样坡度20度。
3. `run_network_view.ps1`：12项真实窗口检查通过，证据`logs/wt009-view/20260911-140710`，服务器/客户端退出0，键盘驾驶、鼠标单发及R重连保持有效；客户端仍不运行自己的驾驶模拟。1280×720截图已目视车辆和中文状态显示。

按最新版本去除14项旧重复计数，覆盖279项检查。早期power-profiles新套件缺少规定的CHECKS_PASS标记，尽管14个断言通过，runner判失败；已补标记并重新运行，不将早期结果计作成功。

基础套件仍输出旧测试布局的包围盒警告，以及退出时13个ObjectDB实例未释放的警告；此前`logs/wt009-headless/925e819-network-headless/20260911-133843/run_checks_stderr.log`已有同数量警告。此次断言通过不等于已解决该清理问题。新动力和网络窗口测试stderr为空。

## 尚缺

WT-004仍在进行中。尚无不同路面材质阻力、精确传动比、完整负载/RPM音效与HUD、两车制动距离/倒车撤回掩体的完整标定。运行状态还未进入可恢复网络快照。本轮没有高速差速转向、单侧履带牵引、悬挂反馈（WT-005/006），也没有重跑完整AI对局/性能或完成真人驾驶验收。两种动力曲线已接入，不等于两辆“完成样车”已经签收。

## 滑行状态修复与制动对照（基线dae8e4c）

新增反例证明松油门时旧实现不更新挡位/等效转速：`logs/wt004-coast/dae8e4c-counterexample/20260911-141144`中套件退出1。现已共用带迟滞的动力区间选择逻辑，滑行更新状态，降速到0的当步清空；倒车滑行使用倒车限速计算状态。

DriveProfile新增brake_scale/coast_scale，支持独立标定反向制动与松油门减速。M4A3为0.85/0.9，M24为1.1/1.15，均是游戏调校，不更改历史事实或冒称车辆实测。两车原基础制动10m/s²不变，通过各自设计资源作用到实际TankVehicle动力链。

`run_suite_checks.ps1 -Suites run_powertrain_checks,run_drive_checks,run_network_controller_checks -Order wt004-coast -SourceSha dae8e4c-brake-final`：19+25+11=55项通过，退出0，证据`logs/wt004-coast/dae8e4c-brake-final/20260911-141310`。被测源码与配置SHA256另见`logs/wt004-coast/SOURCE_FILES.json`。旧反例与最终成功分别保存。

两辆真实历史Actor使用相同6m/s初速，持续提交倒车命令：M4A3刹停2.068m，M24刹停1.587m；120个物理步检查结束时，从各自停车点后撤1.158m/2.239m。初始速度由夹具直接设置，后续制动/倒车走真实命令与碰撞路径，不冒称完整玩家输入起跑。真实20度坡道与原4秒加速差异保持通过。地形套件保留原布局警告；新动力及网络控制套件stderr为空。

尚缺多速度、多坡度、路面材质条件下的标定，完整AI对局中的调校影响也未验证。本次未重跑上一轮216项基础/12项窗口，不能将这些历史结果混成当前源码全量复测。WT-005履带与转向仍未实现。
