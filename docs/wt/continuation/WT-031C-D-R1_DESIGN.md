# WT-031C-D-R1 设计页（角色映射作者化与完整绑定校验）

- 对应父项：WT-030/WT-031 家族；承接 WT-031B-D-R1（探查）与 WT-030D-R1（审计）
- 目标：把"角色名不匹配"从**障碍**变成**一张据实编写的映射表**，并逐条用实时资产复核

## 1. 输入（上一单的实测结论）

- 四个 GLB 全部可由 `GLTFDocument` 解析（含无 `.import` 的研究模型）；
- 外形 9.42–10.88 m、单位=米（真尺度）；
- 绑定六角色仅 **8/24** 自动解析 → 需要**显式角色映射**。

## 2. 改动清单

| 文件 | 改动 |
|---|---|
| `scripts/content/role_mapping.gd`（新，~200 行） | 观测节点清单（证据）+ **作者映射表**（node / derived / missing 三类）+ `validate()`（对实时资产复核，错误具名）+ `draft_binding()`（含 `applied=false`）+ `coverage()` + `missing_roles_for()` + `snapshot()` |
| `tests/run_role_mapping_checks.gd`（新，72 项） | 映射校验 + **对实时 GLB 重新探查复核** + 逐车结论 + 草稿不安装 + 只读性 |
| `docs/wt/continuation/ROLE_MAPPING.md`（新） | 映射表 + 结论 + 对注册的影响 |
| 本页 | 设计页与剩余工作 |

**未改动**：GLB、`model_sources.json`、packet、`MODERN_ASSETS.json`、脏文件、构建流程。

## 3. 关键设计决定

1. **三类角色而非两类**：`node`（资产已有）/ `derived`（装配期作者帧）/ `missing`（需重导出）——把"没有节点"与"需要作者偏移"分开，避免把设计偏移伪装成测量值。
2. **映射必须对实时资产成立**：套件对每条映射**重新探查 GLB**并断言节点/父节点存在；转录清单仅作旁证。
3. **零安装**：`applied=false`、`installed=false`、`registry_untouched=true`、源码无写入路径（全部硬断言）。
4. **缺失具名**：M1A1 的两履带角色报 `merged_lod_has_no_track_nodes`，`registration_ready=false`。

## 4. 本轮验证

| 套件 | 结果 |
|---|---|
| `run_role_mapping_checks`（新） | **72/72 PASS** |

实测结论：`cn_ztz_99a` **6/6 全节点**；`ussr_t_80b`/`germ_leopard_2a4` **6/6（各 1 作者帧）**；`us_m1a1_abrams` **4/6（缺 2 履带角色）**。

## 5. 自纠记录（1 处，我的缺陷）

`snapshot()` 里使用了 **GDScript 不支持的字典推导式** `{id: ... for id in ...}` → 解析失败；改为显式循环，并把原先链式 `filter/map` 的缺失角色计算抽成 `missing_roles_for()`（更清晰、无 lambda 类型风险）。

## 6. 剩余工作（如实）

- 装配期创建作者帧 + 提供 packet `model_binding` 与三个 source 字段 → 随后注册（下一单）。
- M1A1 重导出带履带角色的 GLB（作者资产工作）。
- 窗口与真人 `NOT_RUN`；性能 `HOLD_BY_USER`；不做全库 LOD/纹理专项。

## 7. 回滚

删除映射模块与套件、回退文档；**零既有文件改动**（纯新增）。
