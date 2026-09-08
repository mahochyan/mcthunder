# 020 历史车型与证据索引

本表从实际可玩内容包生成。verified表示引用支持该字段，既可能是一手也可能是明确标出的二手；它不表示整车几何、装填、穿深或整场表现均为历史实测。几何和内部体积为原创估算重建。完整字段值、适用配置、页码与文件SHA256均在各JSON包及游戏内资料档案中。

| 配置 | 炮 / 炮架 | 弹种 | 乘员 | 携弹 | 道路速度 km/h | 宽度 m | 参考车长 m |
|---|---|---|---:|---:|---:|---:|---:|
| M24 / M6 / T85E1 / 1951 | 75-mm M6 / M64 | M61 APC-T | 5 | 48 | 54.72 | 2.9464 | 5.0292 |
| M26 (T26E3) / M3 / 1945 | 90-mm M3 / M67 | M77 AP-T | 5 | 70 | 32.19 | 3.5128 | 6.3271 |
| M36 / M4A1 mount / 1945 | 90-mm M3 / M4A1 | M77 AP-T | 5 | 47 | 41.84 | 3.0480 | 6.1468 |
| M4A3(75)W / 1944 / VVSS | 75-mm M3 / M34A1 | M72 AP-T | 5 | 104 | 41.84 | 2.6670 | 6.2738 |

M4/M36采用VVSS，M24/M26采用扭杆结构。M24选五人选项，手册允许的四人战斗编制用同一配置管线验证。M36为1945年汽油发动机、M4A1炮架、敞顶版本，仍是全回转炮塔。受限射界是独立工程反例，不给这些历史车虚构固定炮。

M36下前装甲：所选1945军械局表为2.5—4英寸，二手AFV表为2—4.25英寸；本包按选定版本使用63.5—101.6 mm，不平均或静默合并。范围的局部分布未知，当前局部63.5 mm明确estimated。M4下前部同理采用范围内的50.8 mm局部估算。M36炮塔后部配重厚度分布未测绘，当前44.45 mm局部面是估算，不能把范围上界铺满。

M24的M61带历史引信；020仅接入动能路径，游戏车库明确提示尚未实现内部爆发，021实现相应规则。M26/M36的M77兼容性来自M3炮的明确弹药表，使用TM9-745炮弹证据不等于采用M36B2车体装甲。M26制退器外形参考军械目录PDF第34页（印刷第25页，15 May 1945）。下载文件名含1944，但其中存在1945修订页；使用的是具体页的日期。

## M24 / M6 / T85E1 / 1951

实际包：[JSON](../../configs/vehicles/historical/us_m24_m6_t85e1_1951.json)；可编辑模型：[Blender](../../authoring/vehicles/us_m24_m6_t85e1_1951.blend)。

| 字段 | 当前值 | 状态 / 来源性质 | 页码或位置 |
|---|---|---|---|
| identity.variant | "M24" | verified / historical_primary | TM9-729 (1951), pp.1-6: edition changes, four/five-man crew option, data table; PDF pp.9-14 |
| identity.year | 1951 | verified / historical_primary | TM9-729 (1951), pp.1-6: edition changes, four/five-man crew option, data table; PDF pp.9-14 |
| identity.suspension | "Torsion bar / T85E1" | verified / historical_primary | TM9-729 (1951), pp.1-6: edition changes, four/five-man crew option, data table; PDF pp.9-14 |
| weapon.gun | "75-mm M6" | verified / historical_secondary | M24: General, Armament and Armor; dimensions/identity below use TM9-729 (1951) |
| weapon.mount | "M64" | verified / historical_secondary | M24: General, Armament and Armor; dimensions/identity below use TM9-729 (1951) |
| weapon.caliber_mm | 75 | verified / historical_secondary | M24: General, Armament and Armor; dimensions/identity below use TM9-729 (1951) |
| crew.roles | ["commander","gunner","loader","driver","assistant_driver_bow_gunner"] | verified / historical_primary | TM9-729 (1951), pp.1-6: edition changes, four/five-man crew option, data table; PDF pp.9-14 |
| crew.placement | "See documented named positions; centers and volumes reconstructed separately." | verified / historical_secondary | M24: General, Armament and Armor; dimensions/identity below use TM9-729 (1951) |
| dimensions.width_m | 2.9464 | verified / historical_primary | TM9-729 (1951), pp.1-6: edition changes, four/five-man crew option, data table; PDF pp.9-14 |
| dimensions.reference_length_m | 5.0292 | verified / historical_primary | TM9-729 (1951), pp.1-6: edition changes, four/five-man crew option, data table; PDF pp.9-14 |
| weapon.capacity | 48 | verified / historical_secondary | M24: General, Armament and Armor; dimensions/identity below use TM9-729 (1951) |
| mobility.forward_speed_mps | 15.19936 | verified / historical_primary | TM9-729 (1951), pp.1-6: edition changes, four/five-man crew option, data table; PDF pp.9-14 |
| weapon.ammunition | "M61 APC-T" | verified / historical_primary | TM9-729 (1951), p.360 ammunition table (PDF p.368) |
| armor.hull_front_upper | 25.4 | verified / historical_secondary | M24: General, Armament and Armor; dimensions/identity below use TM9-729 (1951) |
| armor.hull_front_lower | 25.4 | verified / historical_secondary | M24: General, Armament and Armor; dimensions/identity below use TM9-729 (1951) |
| armor.hull_sides_front | 25.4 | verified / historical_secondary | M24: General, Armament and Armor; dimensions/identity below use TM9-729 (1951) |
| armor.hull_sides_rear | 19.05 | verified / historical_secondary | M24: General, Armament and Armor; dimensions/identity below use TM9-729 (1951) |
| armor.hull_sides_lower | 25.4 | verified / historical_secondary | M24: General, Armament and Armor; dimensions/identity below use TM9-729 (1951) |
| armor.hull_rear_upper | 19.05 | verified / historical_secondary | M24: General, Armament and Armor; dimensions/identity below use TM9-729 (1951) |
| armor.hull_rear_lower | 19.05 | verified / historical_secondary | M24: General, Armament and Armor; dimensions/identity below use TM9-729 (1951) |
| armor.hull_roof_front | 12.7 | verified / historical_secondary | M24: General, Armament and Armor; dimensions/identity below use TM9-729 (1951) |
| armor.hull_roof_rear | 12.7 | verified / historical_secondary | M24: General, Armament and Armor; dimensions/identity below use TM9-729 (1951) |
| armor.hull_floor_front | 12.7 | verified / historical_secondary | M24: General, Armament and Armor; dimensions/identity below use TM9-729 (1951) |
| armor.hull_floor_rear | 9.525 | verified / historical_secondary | M24: General, Armament and Armor; dimensions/identity below use TM9-729 (1951) |
| armor.turret_front | 38.1 | verified / historical_secondary | M24: General, Armament and Armor; dimensions/identity below use TM9-729 (1951) |
| armor.turret_sides | 25.4 | verified / historical_secondary | M24: General, Armament and Armor; dimensions/identity below use TM9-729 (1951) |
| armor.turret_rear | 25.4 | verified / historical_secondary | M24: General, Armament and Armor; dimensions/identity below use TM9-729 (1951) |
| armor.turret_roof | 12.7 | verified / historical_secondary | M24: General, Armament and Armor; dimensions/identity below use TM9-729 (1951) |
| armor.gun_shield | 38.1 | verified / historical_secondary | M24: General, Armament and Armor; dimensions/identity below use TM9-729 (1951) |
| weapon.stowage_counts | {"floor_total":48,"ready":0} | verified / historical_secondary | M24: General, Armament and Armor; dimensions/identity below use TM9-729 (1951) |
| geometry.exterior | 详见实际JSON中的完整结构；非省略内容的默认值 | estimated / game_rule | docs/IMPLEMENTATION_020.md |
| geometry.modules | 详见实际JSON中的完整结构；非省略内容的默认值 | estimated / game_rule | docs/IMPLEMENTATION_020.md |
| geometry.crew | 详见实际JSON中的完整结构；非省略内容的默认值 | estimated / game_rule | docs/IMPLEMENTATION_020.md |
| runtime.simulation | 详见实际JSON中的完整结构；非省略内容的默认值 | estimated / game_rule | docs/IMPLEMENTATION_020.md |
| identity.power_unit | "Two Cadillac 44T24 engines (aggregate damage volume)" | estimated / historical_secondary | M24: General, Armament and Armor; dimensions/identity below use TM9-729 (1951) |

来源登记：

- [m24tm](https://www.military-references.com/wp-content/uploads/books/tanks/usa/m24_chaffee/M24_Chaffee_Light_Tank_Technical_Manual_TM9-729_1951.pdf)：historical_primary / image_and_text_read；SHA256 `4e099cff1f8ee3d0f07cb07e3980955e88aece4894cbf0c2daed1c3e960d668f`。
- [m24table](https://afvdatabase.com/usa/m24chaffee.html)：historical_secondary / text_read；SHA256 `c673c9854a45824472c243174a8342f581d26952322b28887427f040ab8425fe`。

## M26 (T26E3) / M3 / 1945

实际包：[JSON](../../configs/vehicles/historical/us_m26_m3_1945.json)；可编辑模型：[Blender](../../authoring/vehicles/us_m26_m3_1945.blend)。

| 字段 | 当前值 | 状态 / 来源性质 | 页码或位置 |
|---|---|---|---|
| identity.variant | "M26 (T26E3)" | verified / historical_secondary | M26: General, Dimensions, Armament, Armor and Suspension; excludes T26E4 |
| identity.year | 1945 | verified / historical_primary | Mobile Artillery (May 1945), pp.5-7 M26 (T26E3) |
| identity.suspension | "Torsion bar" | verified / historical_secondary | M26: General, Dimensions, Armament, Armor and Suspension; excludes T26E4 |
| weapon.gun | "90-mm M3" | verified / historical_secondary | M26: General, Dimensions, Armament, Armor and Suspension; excludes T26E4 |
| weapon.mount | "M67" | verified / historical_secondary | M26: General, Dimensions, Armament, Armor and Suspension; excludes T26E4 |
| weapon.caliber_mm | 90 | verified / historical_secondary | M26: General, Dimensions, Armament, Armor and Suspension; excludes T26E4 |
| crew.roles | ["commander","gunner","loader","driver","assistant_driver_bow_gunner"] | verified / historical_secondary | M26: General, Dimensions, Armament, Armor and Suspension; excludes T26E4 |
| crew.placement | "See documented named positions; centers and volumes reconstructed separately." | verified / historical_secondary | M26: General, Dimensions, Armament, Armor and Suspension; excludes T26E4 |
| dimensions.width_m | 3.51282 | verified / historical_secondary | M26: General, Dimensions, Armament, Armor and Suspension; excludes T26E4 |
| dimensions.reference_length_m | 6.32714 | verified / historical_secondary | M26: General, Dimensions, Armament, Armor and Suspension; excludes T26E4 |
| weapon.capacity | 70 | verified / historical_secondary | M26: General, Dimensions, Armament, Armor and Suspension; excludes T26E4 |
| mobility.forward_speed_mps | 8.9408 | verified / historical_primary | Mobile Artillery (May 1945), p.7 |
| weapon.ammunition | "M77 AP-T" | verified / historical_primary | TM9-745 (1945), p.500 (PDF p.508), AP-T M77: guns 90-mm M1/M2/M3/T8 |
| armor.hull_front_upper | 101.6 | verified / historical_secondary | M26: General, Dimensions, Armament, Armor and Suspension; excludes T26E4 |
| armor.hull_front_lower | 76.2 | verified / historical_secondary | M26: General, Dimensions, Armament, Armor and Suspension; excludes T26E4 |
| armor.hull_sides_front | 76.2 | verified / historical_secondary | M26: General, Dimensions, Armament, Armor and Suspension; excludes T26E4 |
| armor.hull_sides_rear | 50.8 | verified / historical_secondary | M26: General, Dimensions, Armament, Armor and Suspension; excludes T26E4 |
| armor.hull_sides_lower | 76.2 | verified / historical_secondary | M26: General, Dimensions, Armament, Armor and Suspension; excludes T26E4 |
| armor.hull_rear_upper | 50.8 | verified / historical_secondary | M26: General, Dimensions, Armament, Armor and Suspension; excludes T26E4 |
| armor.hull_rear_lower | 19.05 | verified / historical_secondary | M26: General, Dimensions, Armament, Armor and Suspension; excludes T26E4 |
| armor.hull_roof_front | 22.225 | verified / historical_secondary | M26: General, Dimensions, Armament, Armor and Suspension; excludes T26E4 |
| armor.hull_roof_rear | 22.225 | verified / historical_secondary | M26: General, Dimensions, Armament, Armor and Suspension; excludes T26E4 |
| armor.hull_floor_front | 25.4 | verified / historical_secondary | M26: General, Dimensions, Armament, Armor and Suspension; excludes T26E4 |
| armor.hull_floor_rear | 12.7 | verified / historical_secondary | M26: General, Dimensions, Armament, Armor and Suspension; excludes T26E4 |
| armor.turret_front | 101.6 | verified / historical_secondary | M26: General, Dimensions, Armament, Armor and Suspension; excludes T26E4 |
| armor.turret_sides | 76.2 | verified / historical_secondary | M26: General, Dimensions, Armament, Armor and Suspension; excludes T26E4 |
| armor.turret_rear | 76.2 | verified / historical_secondary | M26: General, Dimensions, Armament, Armor and Suspension; excludes T26E4 |
| armor.turret_roof | 25.4 | verified / historical_secondary | M26: General, Dimensions, Armament, Armor and Suspension; excludes T26E4 |
| armor.gun_shield | 114.3 | verified / historical_secondary | M26: General, Dimensions, Armament, Armor and Suspension; excludes T26E4 |
| appearance.muzzle_brake | true | verified / historical_primary | Standard Ordnance Items Catalog, M26, printed p.25 (PDF p.34), 15 May 1945: caption and gun description |
| weapon.stowage_counts | {"floor_total":60,"ready":10} | verified / historical_secondary | M26: General, Dimensions, Armament, Armor and Suspension; excludes T26E4 |
| geometry.exterior | 详见实际JSON中的完整结构；非省略内容的默认值 | estimated / game_rule | docs/IMPLEMENTATION_020.md |
| geometry.modules | 详见实际JSON中的完整结构；非省略内容的默认值 | estimated / game_rule | docs/IMPLEMENTATION_020.md |
| geometry.crew | 详见实际JSON中的完整结构；非省略内容的默认值 | estimated / game_rule | docs/IMPLEMENTATION_020.md |
| runtime.simulation | 详见实际JSON中的完整结构；非省略内容的默认值 | estimated / game_rule | docs/IMPLEMENTATION_020.md |
| identity.power_unit | "Ford GAF" | verified / historical_secondary | M26: General, Dimensions, Armament, Armor and Suspension; excludes T26E4 |

来源登记：

- [oco1945](https://www.lonesentry.com/manuals/mobile-artillery/index.html)：historical_primary / text_read；SHA256 `cac565aff13387247f2d71f8d9f816f7c0dfa28a0e2be03c26f5438abee1e764`。
- [m26table](https://afvdatabase.com/usa/m26pershing.html)：historical_secondary / text_read；SHA256 `21f41364379f61fb71bf78746e03d708f721db4be19d377492f69515e0167c30`。
- [soic1944](https://www.ibiblio.org/hyperwar/NHC/NewPDFs/USArmy/US%20military%20Technical%20and%20Field%20manuals/Standard.Ordnance.Items.Catalog.Vol.1.1944.pdf)：historical_primary / image_and_text_read；SHA256 `f6758794a50c777645f9af15ae2fb90f49756ccfe76948af6f5c60df53a5dd4f`。
- [m36ammo](https://ia800805.us.archive.org/33/items/TM9-745/TM9-745.pdf)：historical_primary / image_and_text_read；SHA256 `55eda0c283a9fbdc380ba8f932b9b059481d4734a896bcd3007811bc49453914`。

## M36 / M4A1 mount / 1945

实际包：[JSON](../../configs/vehicles/historical/us_m36_m4a1_1945.json)；可编辑模型：[Blender](../../authoring/vehicles/us_m36_m4a1_1945.blend)。

| 字段 | 当前值 | 状态 / 来源性质 | 页码或位置 |
|---|---|---|---|
| identity.variant | "M36" | verified / historical_primary | Mobile Artillery (May 1945), pp.9-11 M36 description/characteristics |
| identity.year | 1945 | verified / historical_primary | Mobile Artillery (May 1945), pp.9-11 M36 description/characteristics |
| identity.suspension | "VVSS" | verified / historical_primary | Mobile Artillery (May 1945), pp.9-11 M36 description/characteristics |
| weapon.gun | "90-mm M3" | verified / historical_primary | Mobile Artillery (May 1945), pp.9-11 M36 description/characteristics |
| weapon.mount | "M4A1" | verified / historical_primary | Mobile Artillery (May 1945), pp.9-11 M36 description/characteristics |
| weapon.caliber_mm | 90 | verified / historical_primary | Mobile Artillery (May 1945), pp.9-11 M36 description/characteristics |
| crew.roles | ["commander","gunner","loader","driver","assistant_driver_bow_gunner"] | verified / historical_primary | Mobile Artillery (May 1945), pp.9-11 M36 description/characteristics |
| crew.placement | "See documented named positions; centers and volumes reconstructed separately." | verified / historical_secondary | M36: General, Armor and Suspension; excludes M36B1/M36B2 and optional roof kit |
| dimensions.width_m | 3.048 | verified / historical_primary | Mobile Artillery (May 1945), pp.9-11 M36 description/characteristics |
| dimensions.reference_length_m | 6.1468 | verified / historical_primary | Mobile Artillery (May 1945), pp.9-11 M36 description/characteristics |
| weapon.capacity | 47 | verified / historical_primary | Mobile Artillery (May 1945), pp.9-11 M36 description/characteristics |
| mobility.forward_speed_mps | 11.62304 | verified / historical_primary | Mobile Artillery (May 1945), pp.9-11 M36 description/characteristics |
| weapon.ammunition | "M77 AP-T" | verified / historical_primary | TM9-745 (1945), p.500 (PDF p.508), AP-T M77: guns 90-mm M1/M2/M3/T8 |
| armor.hull_front_upper | 38.1 | verified / historical_primary | Mobile Artillery (May 1945), p.11, Actual armor column (not Basis) |
| armor.hull_front_lower | [63.5,101.6] | verified / historical_primary | Mobile Artillery (May 1945), p.11, Actual armor column (not Basis) |
| armor.hull_sides_front | 19.05 | verified / historical_primary | Mobile Artillery (May 1945), p.11, Actual armor column (not Basis) |
| armor.hull_sides_rear | 19.05 | verified / historical_primary | Mobile Artillery (May 1945), p.11, Actual armor column (not Basis) |
| armor.hull_sides_lower | 25.4 | verified / historical_primary | Mobile Artillery (May 1945), p.11, Actual armor column (not Basis) |
| armor.hull_rear_upper | 19.05 | verified / historical_primary | Mobile Artillery (May 1945), p.11, Actual armor column (not Basis) |
| armor.hull_rear_lower | 25.4 | verified / historical_primary | Mobile Artillery (May 1945), p.11, Actual armor column (not Basis) |
| armor.hull_roof_front | 19.05 | verified / historical_primary | Mobile Artillery (May 1945), p.11, Actual armor column (not Basis) |
| armor.hull_roof_rear | 9.525 | verified / historical_primary | Mobile Artillery (May 1945), p.11, Actual armor column (not Basis) |
| armor.hull_floor_front | 12.7 | verified / historical_primary | Mobile Artillery (May 1945), p.11, Actual armor column (not Basis) |
| armor.hull_floor_rear | 12.7 | verified / historical_primary | Mobile Artillery (May 1945), p.11, Actual armor column (not Basis) |
| armor.turret_front | 76.2 | verified / historical_primary | Mobile Artillery (May 1945), p.11, Actual armor column (not Basis) |
| armor.turret_sides | 31.75 | verified / historical_primary | Mobile Artillery (May 1945), p.11, Actual armor column (not Basis) |
| armor.turret_rear | [44.45,127] | verified / historical_secondary | M36: General, Armor and Suspension; excludes M36B1/M36B2 and optional roof kit |
| armor.turret_roof | null | unknown / historical_secondary | M36: General, Armor and Suspension; excludes M36B1/M36B2 and optional roof kit |
| armor.gun_shield | 76.2 | verified / historical_primary | Mobile Artillery (May 1945), p.11, Actual armor column (not Basis) |
| geometry.front_collar_thickness | 31.75 | estimated / game_rule | docs/IMPLEMENTATION_020.md |
| weapon.stowage_counts | {"floor_total":36,"ready":11} | verified / historical_secondary | M36: General, Armor and Suspension; excludes M36B1/M36B2 and optional roof kit |
| geometry.exterior | 详见实际JSON中的完整结构；非省略内容的默认值 | estimated / game_rule | docs/IMPLEMENTATION_020.md |
| geometry.modules | 详见实际JSON中的完整结构；非省略内容的默认值 | estimated / game_rule | docs/IMPLEMENTATION_020.md |
| geometry.crew | 详见实际JSON中的完整结构；非省略内容的默认值 | estimated / game_rule | docs/IMPLEMENTATION_020.md |
| runtime.simulation | 详见实际JSON中的完整结构；非省略内容的默认值 | estimated / game_rule | docs/IMPLEMENTATION_020.md |
| identity.power_unit | "Ford GAA" | verified / historical_secondary | M36: General, Armor and Suspension; excludes M36B1/M36B2 and optional roof kit |

来源登记：

- [m36table](https://afvdatabase.com/usa/90mmgmcm36.html)：historical_secondary / text_read；SHA256 `eda1f8c150c8ac35c47955c8d416fe84d93c78111c1eeaa094a236d2fa40fe43`。
- [oco1945](https://www.lonesentry.com/manuals/mobile-artillery/index.html)：historical_primary / text_read；SHA256 `cac565aff13387247f2d71f8d9f816f7c0dfa28a0e2be03c26f5438abee1e764`。
- [m36ammo](https://ia800805.us.archive.org/33/items/TM9-745/TM9-745.pdf)：historical_primary / image_and_text_read；SHA256 `55eda0c283a9fbdc380ba8f932b9b059481d4734a896bcd3007811bc49453914`。

## M4A3(75)W / 1944 / VVSS

实际包：[JSON](../../configs/vehicles/historical/us_m4a3_75w_vvss_1944.json)；可编辑模型：[Blender](../../authoring/vehicles/us_m4a3_75w_vvss_1944.blend)。

| 字段 | 当前值 | 状态 / 来源性质 | 页码或位置 |
|---|---|---|---|
| identity.variant | "M4A3(75)W" | verified / historical_secondary | M4A3(75)W: General, Dimensions, Armament, Armor, Suspension, Performance |
| identity.year | 1944 | verified / historical_secondary | M4A3(75)W: General, Dimensions, Armament, Armor, Suspension, Performance |
| identity.suspension | "VVSS" | verified / historical_secondary | M4A3(75)W: General, Dimensions, Armament, Armor, Suspension, Performance |
| weapon.gun | "75-mm M3" | verified / historical_secondary | M4A3(75)W: General, Dimensions, Armament, Armor, Suspension, Performance |
| weapon.mount | "M34A1" | verified / historical_secondary | M4A3(75)W: General, Dimensions, Armament, Armor, Suspension, Performance |
| weapon.caliber_mm | 75 | verified / historical_secondary | M4A3(75)W: General, Dimensions, Armament, Armor, Suspension, Performance |
| crew.roles | ["commander","gunner","loader","driver","assistant_driver_bow_gunner"] | verified / historical_secondary | M4A3(75)W: General, Dimensions, Armament, Armor, Suspension, Performance |
| crew.placement | "See documented named positions; centers and volumes reconstructed separately." | verified / historical_secondary | M4A3(75)W: General, Dimensions, Armament, Armor, Suspension, Performance |
| dimensions.width_m | 2.667 | verified / historical_secondary | M4A3(75)W: General, Dimensions, Armament, Armor, Suspension, Performance |
| dimensions.reference_length_m | 6.2738 | verified / historical_secondary | M4A3(75)W: General, Dimensions, Armament, Armor, Suspension, Performance |
| weapon.capacity | 104 | verified / historical_secondary | M4A3(75)W: General, Dimensions, Armament, Armor, Suspension, Performance |
| mobility.forward_speed_mps | 11.62304 | verified / historical_secondary | M4A3(75)W: General, Dimensions, Armament, Armor, Suspension, Performance |
| weapon.ammunition | "M72 AP-T" | verified / historical_primary | Standard Ordnance Items Catalog Vol.1 (1944), 75-mm gun tank ammunition table: AP M72 |
| armor.hull_front_upper | 63.5 | verified / historical_secondary | M4A3(75)W: General, Dimensions, Armament, Armor, Suspension, Performance |
| armor.hull_front_lower | [50.8,107.95] | verified / historical_secondary | M4A3(75)W: General, Dimensions, Armament, Armor, Suspension, Performance |
| armor.hull_sides_front | 38.1 | verified / historical_secondary | M4A3(75)W: General, Dimensions, Armament, Armor, Suspension, Performance |
| armor.hull_sides_rear | 38.1 | verified / historical_secondary | M4A3(75)W: General, Dimensions, Armament, Armor, Suspension, Performance |
| armor.hull_sides_lower | 38.1 | verified / historical_secondary | M4A3(75)W: General, Dimensions, Armament, Armor, Suspension, Performance |
| armor.hull_rear_upper | 38.1 | verified / historical_secondary | M4A3(75)W: General, Dimensions, Armament, Armor, Suspension, Performance |
| armor.hull_rear_lower | 38.1 | verified / historical_secondary | M4A3(75)W: General, Dimensions, Armament, Armor, Suspension, Performance |
| armor.hull_roof_front | 19.05 | verified / historical_secondary | M4A3(75)W: General, Dimensions, Armament, Armor, Suspension, Performance |
| armor.hull_roof_rear | 19.05 | verified / historical_secondary | M4A3(75)W: General, Dimensions, Armament, Armor, Suspension, Performance |
| armor.hull_floor_front | 25.4 | verified / historical_secondary | M4A3(75)W: General, Dimensions, Armament, Armor, Suspension, Performance |
| armor.hull_floor_rear | 12.7 | verified / historical_secondary | M4A3(75)W: General, Dimensions, Armament, Armor, Suspension, Performance |
| armor.turret_front | 76.2 | verified / historical_secondary | M4A3(75)W: General, Dimensions, Armament, Armor, Suspension, Performance |
| armor.turret_sides | 50.8 | verified / historical_secondary | M4A3(75)W: General, Dimensions, Armament, Armor, Suspension, Performance |
| armor.turret_rear | 50.8 | verified / historical_secondary | M4A3(75)W: General, Dimensions, Armament, Armor, Suspension, Performance |
| armor.turret_roof | 25.4 | verified / historical_secondary | M4A3(75)W: General, Dimensions, Armament, Armor, Suspension, Performance |
| armor.gun_shield | 88.9 | verified / historical_secondary | M4A3(75)W: General, Dimensions, Armament, Armor, Suspension, Performance |
| armor.rotor_shield | 50.8 | verified / historical_secondary | M4A3(75)W: Armor, rotor shield 2.0 inches |
| weapon.stowage_counts | {"floor_total":100,"ready":4} | verified / historical_secondary | M4A3(75)W: General, Dimensions, Armament, Armor, Suspension, Performance |
| geometry.exterior | 详见实际JSON中的完整结构；非省略内容的默认值 | estimated / game_rule | docs/IMPLEMENTATION_020.md |
| geometry.modules | 详见实际JSON中的完整结构；非省略内容的默认值 | estimated / game_rule | docs/IMPLEMENTATION_020.md |
| geometry.crew | 详见实际JSON中的完整结构；非省略内容的默认值 | estimated / game_rule | docs/IMPLEMENTATION_020.md |
| runtime.simulation | 详见实际JSON中的完整结构；非省略内容的默认值 | estimated / game_rule | docs/IMPLEMENTATION_020.md |
| identity.power_unit | "Ford GAA" | verified / historical_secondary | M4A3(75)W: General, Dimensions, Armament, Armor, Suspension, Performance |

来源登记：

- [soic1944](https://www.ibiblio.org/hyperwar/NHC/NewPDFs/USArmy/US%20military%20Technical%20and%20Field%20manuals/Standard.Ordnance.Items.Catalog.Vol.1.1944.pdf)：historical_primary / image_and_text_read；SHA256 `f6758794a50c777645f9af15ae2fb90f49756ccfe76948af6f5c60df53a5dd4f`。
- [m4table](https://afvdatabase.com/usa/m4sherman.html)：historical_secondary / text_read；SHA256 `1980381315cb546b392a15fc1b4cefde5bf31670d412877ba1eb25d71c75a1d6`。

## 使用与限制

车库正常下拉选车后可以检视外观/装甲/内构、打开证据档案、驾驶并射击；选中车型进入4对4时，双方镜像编成实际四种车，阵亡后保留所选车型。专项工程课目及1对1工程夹具仍用于旧规则回归。

装甲表、模块体积、炮盾和轴心经同一装配管线核验。Blender导出检查逐片匹配装甲三角形和顶点，允许Godot导入压缩的0.1毫米偏差。动态外饰、格栅、轮盘等不增加装甲或损伤盒；履带由真实速度驱动的共享装饰动画表示。

未知字段不补数字冒充数据；无效来源/改型/炮架/弹种/人数、非整数弹药、超出文献范围的局部厚度等会拒绝装配。高保真弧面、精确乘员姿态、历史穿深验证与实测悬挂行为尚未完成。人工作战验收NOT_RUN。
