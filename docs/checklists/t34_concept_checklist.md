# T-34 风格中坦 概念图验收清单（Stage A/C）

概念图：`docs/reference/concept_medium_4663339.png`（sha256 466333967f87737f485481cb6ab199b2181ec96174e4de002b1a1aedaac7703e）
用户口径：**"最还原、不看面数；图上有的一个不能缺，没有的不得多加。"** 练手资产（无种子 JSON，装甲壳体按概念图建模——偏差记录 manifest）。

判定记录于 pass 13（分支 work/art-001-bake-pilot @ a81d542+）；证据 = `docs/evidence/t34/`：
`t34_hero/side/front/rear/wheels/deck.png`（Godot 带贴图截图）+ `cmp_px_side/front/rear.png`（等比红绿叠加）+ `cmp_summary.png`（总图）。

## 必须有（逐项目检判定）

### 炮塔（大、前置、圆润铸造切面感）
- [x] T1 铸造多面体炮塔：前窄后宽带尾舱，立面外扩后收顶 —— deck/hero PASS（12 边形 3 环放样）
- [x] T2 车长舱盖：塔顶矮圆筒+盖+把手 —— hero/deck PASS（z-0.30 高鼓，爆炸图位置）
- [x] T3 塔顶前缘凸起块 —— **修正 2→6 块弧排**（爆炸图面板证据），deck PASS
- [x] T4 炮盾：铸造圆盾+长炮根套筒（爆炸图加长至 0.5m）+盾左垂直观察狭缝 —— wheels 特写 PASS
- [x] T5 光身长管无制退器+炮口台阶加粗 —— side/hero PASS（耳轴 1.74m 近平直，行带扫描证据）

### 车体
- [x] H1 大倾角首上(45°长斜)+鼻板折角、侧板上部内倾 —— side/front PASS（侧视轮廓 0.3%）
- [x] H2 驾驶员观察塞（左中圆塞+矩形玻璃缝）—— front PASS
- [x] H3 变速箱检修盖+2 拉杆 —— front PASS
- [x] H4 首上 D 形拖钩 ×2 —— front PASS
- [x] H5 大灯 ×2 带十字护罩 —— front/wheels PASS（pass11 修复悬浮，坐落首上斜面）
- [x] H6 翼子板（加厚板+前后挂耳）—— side PASS
- [x] H7 甲板中部条形百叶格栅 + 后视大矩形盖板 —— deck/rear PASS
- [x] H8 **双侧置副油箱 ×2**（x≈±0.86、甲板线高、双抱箍+支架）—— **rear 面板红掩码精确对位 PASS**（纠正早前"中置单罐"两轮误判）
- [x] H9 木箱（甲板中右）+长柄铲 —— deck PASS
- [x] H10 排气 ×2（后视内移 x±0.60）—— rear PASS
- [x] H11 车尾 D 形拖钩 ×2（x±0.80）+后下暗色 —— rear PASS

### 行走（克里斯蒂式）
- [x] S1 负重轮 5/侧：Ø0.80 pitch 0.83 近相切、橄榄盘+6 螺栓圈(几何)+毂盖 —— wheels/close-up PASS（与 pnl_wheel 一致）
- [x] S2 前置低位小主动轮（8 齿块）；S3 后置小诱导轮；**无托带轮** —— wheels/side PASS
- [x] S4 单节履带全环含上行段：深色块节+中央导齿 —— wheels PASS（上行段坐轮顶上方，概念侧视穿轮心系画师简化，偏差记录 manifest）

### 涂装/标记
- [x] P1 橄榄两阶（上浅下深侧带）+履带深灰+木件棕 —— deck/hero PASS（paint 平心采样修复"木纹"）
- [x] P2 无星标/徽记/天线/高机/铅笔管 —— 全源复核 PASS（脚本内无 tile5/6 引用，manifest 记录 not_added_by_design）

## EXTRA 复核
无图上不存在的部件；atlas 星板/高机位未使用；托带轮/制退器确认未建模。

## 判定：**Stage C 通过（零 MISSING / 零 EXTRA）**
剩余量化差均为概念面板内部标度矛盾（前视），按 skill per-view 规则记录于 manifest，不硬凑。
