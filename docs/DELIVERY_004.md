# DELIVERY 004 — 装甲检视窗口（M4A3（75）W 历史研究布局）

- 分支：`work/004-armor-inspector`（自 db05bf2 起）；顺序提交：004-a `31ed6bb`、
  004-b `19bb403`、004-c `82f3003`、004-d 本提交。
- 检查基线：70/70 LAYOUT_CHECKS_PASS + 208/208 CHECKS_PASS（logs/004/82f3003/）。

## 玩家会看到什么（玩家视角）

1. **如何进入**：Esc → 暂停菜单 → 点 **Vehicle Inspector** → 打开独立检视窗口；
   Back 按钮 / Esc → 返回暂停菜单（游戏全程暂停，返回后仍暂停，继续按钮恢复）。
   检视窗口打开期间，Esc/Back 只关检视窗口，不恢复游戏；R/F3 等靶场输入被隔离。
2. **窗口内容**：左侧布局选择器（LayoutCatalog 可选布局）、部件/装甲/模块/乘员树、
   姿态滑杆（炮塔偏航 0-360、火炮俯仰，实时限位截断）、Back 按钮；
   右侧 SubViewport 独立世界渲染预览模型（拖动旋转视角、滚轮缩放）。
3. **三种模式**：
   - **外观 Appearance**：低模轮廓（车体斜面+履带盒+主炮管+炮盾），不是一个方盒。
   - **装甲 Armor**：面片按真实数据着色 + 边线线框（灰=厚度未知、橙=估算、
     蓝/绿/红=厚度分档 25/50mm 阈值）；选中面片高亮。
   - **内构 Interior**：外壳半透明，显示模块方盒（蓝）与乘员方盒（绿）。
4. **详情面板**：选中任一装甲面片/模块/乘员/部件 → 显示 kind、part、厚度与状态、
   材质、几何状态、证据 keys（可回查 FIELD_EVIDENCE.json）。

## 历史字段核验状态（诚实边界）

**verified（原始资料文字核验，一手 TM 9-759 1944-09-15 + FM 17-67 1944-08-05）：**
- 车型配置：M4A3 75mm wet stowage（封面+§4 变体描述）；VVSS；75mm M3 / M34-M34A1 挂架
- 总尺寸：长 6.274 m（20ft7in 含沙盾）、宽 2.667 m（8ft9in 含沙盾）、
  高 3.375 m（132⅞in 至 AA 枪座）、履带中心距 2.108 m（83in）、空重 63,097 lb
- Ford GAA 8 缸 60° V 液冷 500hp@2600rpm，**发动机位于车体后部**（原文）
- 变速箱前部（换挡杆在驾驶员右侧、变速箱左侧——原文）
- 五乘员岗位：车长炮塔 / 炮手炮右侧 / 装填手炮左侧 / 驾驶员+车首机枪手车体前部座椅（FM §3/§4b）
- 湿式储弹：全炮塔地板 bracket-mounted（原文）；75mm 104 发
  （100 发车体地板垂直弹架 + 4 发篮地板，原文）；.30 弹 16 盒右前 sponson + 7 盒左
  sponson 电池上方；.50 弹 6 盒右后 sponson
- 辅助发电机：左 sponson 后端战斗舱内（原文）
- 电台 SCR-508/528/538（存在性）；炮塔液压横转 Oilgear（存在性）

**estimated（有尺度参考的拟合，已标注非实测）：**
- 车体/炮塔面片顶点坐标（按 verified 总尺寸拟合的低模）、炮塔回转轴站位、
  模块方盒位置与尺寸、乘员方盒体积、驾驶员/车首机枪手左右分配、电台安装位置

**unknown（未核验，显示"未知"，不显示 0mm，不编造）：**
- **全部装甲面片厚度**——TM 9-759 文本层无装甲厚度表；图版为扫描图形，
  本轮未完成图板逐页目视核验（执行端无图像核验能力）
- 装甲材质轧制/铸造分配、炮塔环直径、火炮俯仰限位（滑杆限位标注"检视范围/未核验"）

**还不能做的：** 逐面片历史厚度值（需图板/图纸目视核验）、炮盾固定/随动拆分、
真实曲面炮塔（现为平面片近似）、命中查询（005 范围）。

## 工程结构（本单新增）

- `scripts/layout/`（004-a，9 个文件）：布局 schema + 校验器 + LayoutMath +
  ArmorPatchMesh + LayoutCatalog 注册表
- `docs/vehicles/us_m4a3_75w_vvss_1944/`（004-b）：IDENTITY / SOURCES /
  FIELD_EVIDENCE（字段级依据与 origin/status 分类）/ GEOMETRY_NOTES / OPEN_QUESTIONS
- `configs/layouts/us_m4a3_75w_vvss_1944.tres`：hull→turret→gun 层级、五乘员、
  13 模块+外部履带、declared_openings（炮塔环/炮盾）、allowed_overlaps（油箱↔发动机）
- `scripts/inspection/vehicle_preview_model.gd`：布局→部件层级 Node3D；
  姿态走 LayoutMath.posed_local（绕部件自身 bind 原点+限位截断）；选中=实例材质覆盖；
  颜色随真实厚度/状态数据变化
- `scripts/inspection/vehicle_inspector.gd` + `scenes/inspection/vehicle_inspector.tscn`
- HUD 暂停菜单按钮 + `open/close_vehicle_inspector` + Esc 路由 + 输入隔离
- `VehicleDefinition.layout_id: String = ""`（向后兼容；旧资源不受影响）
- `--inspect-demo`：真实窗口、真实信号链（暂停菜单按钮 → 窗口 → Back）、
  6 张证据自动退出，必需截图失败退出码非 0

## 证据

- `logs/004/82f3003/layout_checks.log`：70/70 LAYOUT_CHECKS_PASS（exit 0）
- `logs/004/82f3003/run_checks.log`：208/208 CHECKS_PASS（exit 0；003 全量回归）
- `docs/evidence/004/82f3003/1280x720/`：6 张检视窗口截图（exit 0, shots=6, errors=0）
- `docs/evidence/004/82f3003/1920x1080/`：6 张（exit 0, shots=6, errors=0）

## 边界遵守

- 未实现 005（命中查询）；未合并 main；未强推；未重写已签收 003；
  VehicleDefinition 只加了向后兼容的 layout_id 字段。
- 历史内容部分不报告完成（装甲厚度未知项见 OPEN_QUESTIONS.md）；
  查看器与测试夹具部分按工单口径完成。