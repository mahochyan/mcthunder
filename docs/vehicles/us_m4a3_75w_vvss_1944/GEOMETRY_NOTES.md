# GEOMETRY_NOTES — us_m4a3_75w_vvss_1944

## 坐标约定

- 1 单位 = 1 米；+X 右、+Y 上、-Z 前；厚度毫米；关节角度。
- **根原点 = 炮塔回转轴在接地平面上的投影**（本车有炮塔，适用该定义）。
- 所有结构变换为无缩放、无镜像、无剪切的刚体变换。

## 尺度锚点（verified，TM 9-759 §5a）

| 项 | 米 | 原文 |
|---|---|---|
| 总长（含沙盾） | 6.274 | 20 ft 7 in |
| 总宽（含沙盾） | 2.667 | 8 ft 9 in |
| 总高（AA 枪座以上） | 3.375 | 132 7/8 in |
| 履带中心距 | 2.108 | 83 in |

几何拟合方法：历史布局的低模外形按上述 verified 总尺寸**拟合**；
车体内部宽度由履带中心距与总宽关系推得（履带外缘超出 sponson ≈ (2.667−2.108)/2
每侧 0.28 m；sponson 内缘按 23 in 宽履带推算）——这些推算步骤全部属于
estimated，不是实测。

## 层级

```
hull  (bind origin = 炮塔环接地投影)
└─ turret  (bind origin = 环上表面；yaw 范围 0-360 检视用)
   └─ gun  (bind origin = 火炮俯仰轴；pitch 范围 = 检视范围/未核验)
```

- 炮塔回转轴：estimated 置于车体中部（具体站位文本未给）。
- 火炮俯仰范围：M34A1 挂架限位在引用文本中**未核验到数值**——查看器姿态
  控制标"检视范围/未核验"，不冒充历史限位。

## 乘员方盒（空间近似，volume_status=estimated）

站位归属 verified（FM 17-67 §4b）；方盒大小与精确中心 estimated：
- commander：turret，右后区域，站姿/坐姿体积近似
- gunner：turret，炮右侧
- loader：turret，炮左侧
- driver：hull 前部左（左右分配 estimated）
- bow_gunner：hull 前部右

## 模块方盒（geometry_status=estimated，除注明）

方盒为空间占用近似；"一个方盒代表什么、为何此尺寸"在 FIELD_EVIDENCE.json
与 IDENTITY.md 有依据说明。发动机后舱/前变速箱/传动轴/湿式储弹弹架/发电机
（verified 位置）/电台/炮塔驱动/炮闩/油箱/外部履带盒。

## 装甲面片

- 车体六面 + 炮塔简化平面壳（多片近似）。
- **全部 geometry_status=estimated**（按 verified 总尺寸拟合的低模）；
- **全部 thickness unknown**（has_thickness=false）——TM 9-759 文本无厚度表，
  图板未能目视核验；未知显示"未知"，不显示 0 mm。
- 真实炮塔为铸造曲面，本模型用平面片近似，OPEN_QUESTIONS 登记在案。