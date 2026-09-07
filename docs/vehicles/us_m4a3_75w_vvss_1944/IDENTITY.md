# IDENTITY — us_m4a3_75w_vvss_1944

- **工程 identity_id**: `us_m4a3_75w_vvss_1944`
- **车型**: M4A3 (75) W Sherman（Medium Tank M4A3, 75-mm Gun M3, Wet Stowage, VVSS）
- **时期**: 1944 年式参考配置
- **主炮**: 75 mm Gun M3（Combination Gun Mount M34 / M34A1，TM 9-759 B 部分）
- **悬挂**: VVSS（Vertical Volute Spring Suspension，TM 9-759 §XXIV）
- **弹药储存类型**: Wet Stowage（TM 9-759 §4f/§4h 描述的穿孔水箱夹层储弹车）
- **content_tier**: `research`（不是 production——见 §历史内容口径）

## 配置锁定依据

TM 9-759（1944-09-15）明确分开讨论 75 毫米湿式（§4b/§4h，PDF 页 14）、75 毫米干式
（§4c/§4i）、76 毫米（§4d）与 105 毫米榴弹炮（§4e）车型。本档案只采用 75 毫米
湿式储弹章节的数据；不混入早期干式储弹车、76 毫米大炮塔车型、105 毫米榴弹炮车型、
M4A3E2 或 HVSS 配置。

## 明确不指定

- 车厂序列号、铸造件编号、具体实车编号——"1944 年式参考配置"不等于复原了
  某一辆有完整履历的实车。
- 75 毫米干式/76 毫米/105 毫米混装部件。
- 未经核实的炮塔环直径、装甲厚度数值（见 FIELD_EVIDENCE.json / OPEN_QUESTIONS.md）。

## 关键已核验配置事实（详见 FIELD_EVIDENCE.json）

| 项目 | 值 | 状态 | 依据 |
|---|---|---|---|
| 发动机 | Ford GAA，8 缸 60° V，液冷，500 hp @ 2600 rpm | verified | TM 9-759 §1（PDF p9）、§5b（PDF p15） |
| 发动机位置 | 车体后部（rear of the hull） | verified | TM 9-759 §1（PDF p9） |
| 总长（含沙盾） | 20 ft 7 in ≈ 6.27 m | verified | TM 9-759 §5a（PDF p14） |
| 总宽（含沙盾） | 8 ft 9 in ≈ 2.667 m | verified | TM 9-759 §5a（PDF p14） |
| 总高（AA 枪座以上，75mm） | 132 7/8 in ≈ 3.375 m | verified | TM 9-759 §5a（PDF p14） |
| 履带中心距 | 83 in ≈ 2.108 m | verified | TM 9-759 §5a（PDF p14） |
| 空重（75-mm） | 63,097 lb ≈ 28,616 kg（近似） | verified | TM 9-759 §5a（PDF p14） |
| 乘员 | 5 men | verified | TM 9-759 §5a + FM 17-67 §3 |
| 湿式储弹炮塔地板 | 75-mm 湿式车有 bracket-mounted 全炮塔地板 | verified | TM 9-759 §4h（PDF p14） |
| 75mm 弹药储放 | 104 rounds：4 on basket floor + 100 in vertical racks on hull floor | verified | TM 9-759 §9a（PDF p24） |
| .30 弹药储放 | 16 boxes right front sponson + 7 boxes left sponson (over battery) | verified | TM 9-759 §9b（PDF p25） |
| 辅助发电机 | 左 sponson 后端、战斗舱内 | verified | TM 9-759 §57a（PDF p57） |
| 电台 | SCR-508/528/538（FM） | verified | TM 9-759 §5d（PDF p15） |
| 炮塔驱动 | 液压横转（Oilgear hydraulic traverse 提及） | verified | TM 9-759 工具清单（PDF p23） |

## 五名乘员（FM 17-67 §3/§4b，PDF 页 6，印刷页 2，verified）

| 岗位 role | 位置（手册原文） | 部件归属 |
|---|---|---|
| Tank Commander | 炮塔内，站炮塔地板或后炮塔座椅 | turret |
| Gunner | 炮手座椅，**炮右侧** | turret |
| Cannoneer (loader) | 炮塔内，**炮左侧**座椅 | turret |
| Driver | 驾驶员座椅（车体前部） | hull |
| Bow gunner (assistant driver / radio operator) | 车首机枪手座椅（车体前部） | hull |

不创建四人通用模板。