# SOURCES — us_m4a3_75w_vvss_1944

资料登记按 GPT 004 工单 §1.2 规则：每条记录 source_id、标题、机构、日期、URL、
本地 SHA256、印刷页码、PDF 页码（从 1 起）、章节/图号、适用/不适用车型、读取状态。

## SRC-TM9-759

| 字段 | 值 |
|---|---|
| source_id | SRC-TM9-759 |
| 标题 | TM 9-759, Tank, Medium, M4A3 |
| 发布机构 | War Department |
| 日期 | 1944-09-15 |
| 公开 URL | https://www.theshermantank.com/wp-content/uploads/2015/12/TM9-752-TANK-MEDIUM-M4A3-44.pdf |
| 本地文件 | E:\AIprogram\research-sources\TM9-759_TANK_MEDIUM_M4A3_1944.pdf |
| SHA256 | 78CE6B3F5B29FB04823EBDE1E861A601FFDFF9E4B85C837F11BA130B3415A818 |
| 页数 | 477 |
| **型号核对** | **封面（PDF p1-3）确认为 TM 9-759 "TANK, MEDIUM M4A3", WAR DEPARTMENT, SEPTEMBER 1944**——镜像 URL 文件名 TM9-752 有编号混淆，资料编号按封面正文，不按 URL |
| 适用 | M4A3 各变体（75 湿式/干式、76mm、105mm howitzer；VVSS/HVSS 章节区分） |
| 本轮使用范围 | §4 车型差异（PDF p14）、§5 DATA（PDF p14-15）、§6-11 stowage（PDF p16-29）、发动机/传动描述（PDF p9, 33-44）、辅助发电机（PDF p57） |
| 读取状态 | 文本层提取完成（OCR 质量不均：§4 数据表部分页面为扫描图，p13 无法读取；p14-15 文本可核验）；**装甲图板逐页目视核验未完成**（执行端无图像核验能力，见 OPEN_QUESTIONS.md） |

## SRC-FM17-67

| 字段 | 值 |
|---|---|
| source_id | SRC-FM17-67 |
| 标题 | FM 17-67, Crew Drill and Service of the Piece, Medium Tank M4 |
| 发布机构 | War Department |
| 日期 | 1944-08-05 |
| URL | https://www.theshermantank.com/wp-content/uploads/2015/12/FM17-67_Crew_Drill_and_Service_M4_Medium_Tank_1944.pdf |
| 本地文件 | E:\AIprogram\research-sources\FM17-67_Crew_Drill_M4_Medium_1944.pdf |
| SHA256 | AEC18997838B5C4D9A0D6F5D800C58018EE5D7B7F28F493FDC4D9289A5964C1D |
| 页数 | 132 |
| 本轮使用范围 | §3 Composition（PDF p6，印刷页 2）、§4b Mounted posts（PDF 页 6） |
| 读取状态 | 乘员组成与五岗位位置段文本核验完成（GPT 侧亦目视核对过印刷页 2） |

## 使用规则

- 不使用战雷截图、模型游戏化数值或二次转载参数表作为历史依据
  （它们只能进"玩法对照记录"，不属于本轮任何 evidence key）。
- 每个参数的依据单独登记在 FIELD_EVIDENCE.json；"厚度有文字依据"不代表
  "面片所有顶点坐标也经过实测"。
- 原始 PDF 保存在工程外资料目录（E:\AIprogram\research-sources\），
  不塞进游戏构建；本目录只保存来源清单、哈希与核验记录。