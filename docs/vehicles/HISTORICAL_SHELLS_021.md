# 021 当前历史弹种资料

运行目录为 configs/shells/historical_loadouts.json；它覆盖020车型包的弹道初值。020原始字段作为当时版本的档案保留，不代表021当前弹道。

适配有原始手册/目录依据；穿深曲线均为 estimated，内部爆发均为 game_rule。初速的 verified 只表示引用记录支持该值，不代表当前游戏完成实测标定。APHE不是工程级引信或爆药仿真。

每车默认主弹约70%、另一弹约30%（向下取整另一弹，总数保持车型载弹量）。M24默认M61，其他默认实心AP。M72适配M6来自TM9-729图197A；1951实际配发情况仍unknown。

M77/M82的90 mm游戏曲线远距离有交叉，不能概括成APHE在所有距离穿深更低。训练AP120/APHE96的0.8倍率是单独的TEST ONLY比较夹具，未用于历史弹种。

## m72_m3 · M72 AP-T

火炮：75-mm M3；口径：75 mm；作用：kinetic。
初速：618.744 m/s（verified）。

| 距离 m | 游戏法向穿深 mm（estimated） |
|---|---|
| 0 | 100 |
| 457.2 | 89 |
| 914.4 | 78.74 |
| 1828.8 | 58 |
| 2500 | 42 |

原文观察：M3: 2030 ft/s; 3.1 in homogeneous and 2.6 in face-hardened plate at 1000 yd, 0 degrees (printed 103).

估算及冲突处理：914.4m homogeneous anchor transcribed. Other ranges interpolate/extrapolate game estimates. No material-specific projectile failure model.

来源：tm1901

## m61_m3 · M61 APC-T / APHE

火炮：75-mm M3；口径：75 mm；作用：internal_burst。
初速：618.744 m/s（verified）。

| 距离 m | 游戏法向穿深 mm（estimated） |
|---|---|
| 0 | 90 |
| 457.2 | 81 |
| 914.4 | 71.12 |
| 1828.8 | 53 |
| 2500 | 39 |

原文观察：TM printed 101 data applies to M61 through printed 102 para.89: M3 2030 ft/s, 2.8 in homogeneous at 1000 yd, 0 degrees.

估算及冲突处理：914.4m homogeneous anchor transcribed. Other ranges are game estimates. SOIC gives 2024 ft/s and angled table; retained as differing source, not silently combined. Inside burst is a toy game effect.

来源：tm1901, soic3

## m72_m6 · M72 AP-T (sight chart)

火炮：75-mm M6；口径：75 mm；作用：kinetic。
初速：618.744 m/s（estimated）。

| 距离 m | 游戏法向穿深 mm（estimated） |
|---|---|
| 0 | 100 |
| 457.2 | 89 |
| 914.4 | 78.74 |
| 1828.8 | 58 |
| 2500 | 42 |

原文观察：TM9-729 printed 345 Fig.197A ADC75-H-2 explicitly includes M6 on M24 and an M72 column. Table V printed 360 does not list M72.

估算及冲突处理：Technical compatibility from the M6 sight chart; 1951 field issue is unknown. M3 M72 velocity/penetration used as estimated M6 simulation transfer, not claimed as M6 test results.

来源：m24tm, tm1901

## m61_m6 · M61 APC-T / APHE

火炮：75-mm M6；口径：75 mm；作用：internal_burst。
初速：618.744 m/s（verified）。

| 距离 m | 游戏法向穿深 mm（estimated） |
|---|---|
| 0 | 90 |
| 457.2 | 81 |
| 914.4 | 71.12 |
| 1828.8 | 53 |
| 2500 | 39 |

原文观察：TM9-729 printed 360 Table V authorizes fuzed M61; printed 345 Fig.197B/C explicitly gives M61/M61A1 2030 ft/s for M6.

估算及冲突处理：Gun-specific compatibility and velocity verified. Penetration transfers the M3 M61 game curve as an estimate; no M6-specific terminal test curve found. Inside burst is a toy effect.

来源：m24tm, tm1901

## m77_m3 · M77 AP-T

火炮：90-mm M3；口径：90 mm；作用：kinetic。
初速：822.96 m/s（verified）。

| 距离 m | 游戏法向穿深 mm（estimated） |
|---|---|
| 0 | 175 |
| 457.2 | 151.37 |
| 914.4 | 129.75 |
| 1828.8 | 99 |
| 2500 | 80 |

原文观察：SOIC PDF88 M3 column: 2700 ft/s, homogeneous 5.6 in at 500 yd and 4.8 in at 1000 yd at 20 degrees.

估算及冲突处理：Angled thickness divided by cos(20 degrees) to calibrate the simple LOS game resolver; this is a game normalization, not a verified normal-impact test. Other ranges extrapolated.

来源：soic3, m36tm

## m82_m3_2800 · M82 APC-T 2800 / APHE

火炮：90-mm M3；口径：90 mm；作用：internal_burst。
初速：853.44 m/s（verified）。

| 距离 m | 游戏法向穿深 mm（estimated） |
|---|---|
| 0 | 160 |
| 457.2 | 150 |
| 914.4 | 140 |
| 1828.8 | 119 |
| 2500 | 105 |

原文观察：January 1945 OCO pamphlet explicitly names M82 2800 ft/s for M3 on T26E3 and M36. Its own 20/30 degree homogeneous curve is the visual calibration source.

估算及冲突处理：Graph read approximately, then mapped into the simple LOS game rule. Deliberately not the older 2670 ft/s SOIC M82 curve. No AP multiplication. Inside burst is a toy effect.

来源：m36tm, oco90, oco90graph

## 来源索引

### tm1901

[TM 9-1901 Artillery Ammunition, 29 June 1944](https://archive.org/download/Tm9-1901/Tm9-1901.pdf)

printed 101-103 / PDF 105-107

historical_primary · image_and_text_read

SHA256 `238cd4b2e34d75d3b2ca5a93772894787322b57dd01b1062ad3c8bb29524eef3`

### soic3

[Catalogue of Standard Ordnance Items Vol.3, 1944](https://www.ibiblio.org/hyperwar/NHC/NewPDFs/USArmy/US%20military%20Technical%20and%20Field%20manuals/Standard.Ordnance.Items.Catalog.Vol.3.1944.pdf)

PDF 71,88: gun-specific performance tables

historical_primary · image_and_text_read

SHA256 `f928cec1bd9bcb1a22595a9f635bd1e2a4001e25b42ff4c09d857aaca829670d`

### m24tm

[TM 9-729 Light Tank M24, May 1951](https://www.military-references.com/wp-content/uploads/books/tanks/usa/m24_chaffee/M24_Chaffee_Light_Tank_Technical_Manual_TM9-729_1951.pdf)

printed 345 Figure 197 / PDF 353; printed 360 Table V / PDF 368

historical_primary · image_and_text_read

SHA256 `4e099cff1f8ee3d0f07cb07e3980955e88aece4894cbf0c2daed1c3e960d668f`

### m36tm

[TM 9-745 M36B2, 1945 (gun ammunition compatibility only)](https://ia800805.us.archive.org/33/items/TM9-745/TM9-745.pdf)

printed 500 / PDF 508: authorized M3 rounds

historical_primary · image_and_text_read

SHA256 `55eda0c283a9fbdc380ba8f932b9b059481d4734a896bcd3007811bc49453914`

### oco90

[OCO Armor-Piercing Ammunition for Gun, 90-mm, M3, January 1945, primary pamphlet transcription](https://ww2.lonesentry.com/manuals/90-mm-ammunition/index.html)

M82 2800 fps section; names T26E3 and M36

historical_primary · text_read

SHA256 `1f7a9503a81535a821f74f72ee03141804da87f18460bd7c106d4aeb06ae08bb`

### oco90graph

[OCO January 1945 M82 penetration versus range, printed graph](https://ww2.lonesentry.com/manuals/90-mm-ammunition/armor-penetration-vs-range-table.jpg)

20/30 degree homogeneous plate graph (visual reading is approximate)

historical_primary · image_and_text_read

SHA256 `4a23fff3926765f83ae588380c77a399adc8440351d22aa9500ed9f8c672e1fe`
