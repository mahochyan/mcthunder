# WT-036-R1：`supply` 36 项失败**全部消除**；工业套件 `558/37 → 594/1`

## 1. 结果（完整运行，1437.6 s）
| 阶段 | PASS | FAIL | 说明 |
|---|---|---|---|
| 加固前（run2 完整，原 339 项） | 300 | **39** | 其中 **supply 36** |
| 加固后（595 项，含 256 净空断言） | 558 | 37 | 净空断言 **256/256 全绿** |
| **铺装 `supply→spawn` 后** | **594** | **1** | **supply 36 → 0** ✓✓ |

## 2. 机制得到验证
轨迹读出的原因（**未铺装地面 drag 0.55 + 到点曲线仅给 0.24 油门 ⇒ 从静止无法起步**）与
用户已授权的 **C 类铺装修复**完全吻合：**36 项 supply 失败一次性全部消除** ✓

## 3. 剩余唯一失败：**既有基线红**（非本分支引入）
```
[FAIL] restart frees old world and preserves selected map industrial_edge
```
- **四份日志一致失败**：`baseline-industrial-full.log`（**未改动基线**）· `cont-industrial-run2.log` · `industrial-hardened.log` · `industrial-after-supply-paint.log` ✓
- 检查内容：`restart_match()` 后要求 **旧场景已被释放**（`previous.get_ref()==null`）、新 round id 不同、地图保持 ✓
- ⇒ 属**世界生命周期/释放**问题（与别处 `ObjectDB instances leaked at exit` 告警同源），**与本分支改动无关**；
- 建议：作为**独立工作单**（场景拆卸与泄漏清理）处理；本轮**只登记**，不改产品代码。

## 4. 工业套件当前口径
| | 基线 main | 本分支 |
|---|---|---|
| PASS / FAIL | 283 / 56 | **594 / 1**（595 项） |
| 失败构成 | supply 36 · capture 19 · **restart 1** | **restart 1（既有）** |
| 256 条出生净空断言 | —（不存在） | **256/256 通过** ✓

⇒ **256 条 capture 与 256 条 supply 路线在本分支全部通过** ✓
