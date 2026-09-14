# WT-036-R1 取证：`challenge_defence_waves` 失败是**测试夹具缺陷**，非产品缺陷

## 1. 现象
```
[active defense] { } held=45.0 kills={ } player_shots=0 remaining=6
[FAIL] real defense script pilot completes finite waves with opponent AI untouched
（同检查两项，均失败；`run_challenge_checks` 总计 138 通过 / 2 失败）
```

## 2. 代码级根因（`scripts/challenges/challenge_director.gd`）
```gdscript
"hold_ground":
    if _inside(world.actor,config.zone,config.radius) and not contested(): held = minf(config.hold, held+delta)
    ...
    success = held >= config.hold-0.000001 and kills.size() == config.enemies.size()
```
`hold_ground` 的胜利条件**同时**要求：
1. **`held` 达阈值** —— 仅当**待在占区内**才累积；
2. **`kills.size() == config.enemies.size()`** —— **敌人全部被击杀**。

场景参数（`challenge_catalog.gd`）：`hold_ground` → `zone=(−78,0,100)`、`radius=12`、`start=(−78,0.03,100)`、`hold` 阈值、`enemies` 若干。

## 3. 测试夹具的两处硬伤（`tests/run_challenge_checks.gd::_hold_active`）
| # | 夹具行为 | 与判定冲突 |
|---|---|---|
| ① | 把车驱到 **(−62,0,100)** 与 **(−65,0,90)/(−65,0,100)** | 这些点距占区中心 **16.0 / 10.2 / 13.0 m**（`_inside` 用 2D 距离 ≤ `radius=12`）→ **多数在区外** ⇒ `held` 不再累积（实测停在 **45.0 s**）✓ |
| ② | **全程从不射击**（该夹具只调用 `_drive`，没有 `_shoot_at`） | `kills` 恒为空 ⇒ **即使 `held` 达标也永不 success** ✓ 与 `player_shots=0` 完全一致 |

⇒ **夹具在当前写法下不可能通过**；断言（`phase=="finished" and result.status=="passed"`）本身**是合理的产品要求**，**不应放宽**。

## 4. 处置（测试侧修复，**不改断言**）
在 `_hold_active` 中：
1. 把驻留点改到**占区内**（如 `(−78±4, 100±4)`）；
2. 用套件已有的 `_shoot_at(...)` **实际交战**（对每个敌人开火直至击杀或超时），使 `kills` 能达成；
3. 保留原断言与阈值不变，并**保留**"硬难度"分支（`--hard-defense`）。

## 5. 影响与安全
- 该失败**此前从未被测量**（第 2 轮为 DEFERRED）→ 不属回归；修复仅动**测试夹具**；
- 若修复后仍不能通过，再回到产品侧（挑战胜利条件是否可达）并附证据。
