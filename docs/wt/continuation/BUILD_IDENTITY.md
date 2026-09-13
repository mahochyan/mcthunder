# WT-001-R2 构建身份约定与历史包路径映射

- 依据：`03_全部42项目标工作单.md` WT-001 行 30-44；`02_首轮10张执行单.md` §02
- 目标：任何后续模型与用户都能明确"正在运行哪一份源码"，且旧 RC 包不冒充当前能力。

## 1. 身份分层（四件不同的事，不互相替换）

| 层 | 载体 | 当前值 |
|---|---|---|
| 语义版本（显示） | `project.godot` → `application/config/version` | `1.0.0-rc.2` → **修正为 `1.0.0-rc.3-dev`**（见 §2） |
| 构建编号（build id） | `scripts/core/build_identity.gd` → `BUILD_ID` | **`continuation-20260913`** |
| 源码身份 | `scripts/core/build_identity.gd` → `SOURCE_BASE_COMMIT` | **`a1bac406d2bc12b32c7f7d130590f1c1a17907c9`** |
| 发布状态 | `scripts/core/build_identity.gd` → `RELEASE_READY` | **`false`**（不宣称 release_ready） |

约定：
1. **固定语义版本不包含自引用 SHA**——避免"包含自己最终 SHA 的文件"循环；SHA 只出现在 `SOURCE_BASE_COMMIT` 与打包 manifest 中。
2. 语义版本只在**能力边界变化**时递增；`-dev` 后缀表示开发候选，非发布版本。
3. `BUILD_ID` 采用 `continuation-YYYYMMDD`，由本轮接续起点确定，**不由打包时动态生成**（可复现）。
4. 引擎身份与 `docs/wt/BASELINE.json` 保持一致：`4.7.2.stable.official.ed1daf0bf`，`sha256 C8F0A6BC45A19B33541501E57F6F7CD972AB18453743266339D495CBBE846643`。

## 2. 显示点（主菜单可见）

| 位置 | 文件:行 | 现状 | R2 后 |
|---|---|---|---|
| 菜单版本行 | `scripts/core/garage_shell.gd:74` | `menu_version % config/version` | 追加 `BuildIdentity.describe()` → 显示 `1.0.0-rc.3-dev · build continuation-20260913 · base a1bac406 · 开发候选(非发布)` |
| 车库页脚 | `scripts/ui/garage_frontend.gd:110` | `"MCT  /  " + config/version` | 同上追加身份，保证任一入口都能看到源码身份 |

**验证要求**（`02` §02 必须验证）：主菜单显示开发候选身份，且**不宣称 release_ready**。

## 3. 历史包路径映射（旧路径 → 实际位置）

仓库文档里引用的旧交付/构建路径**在当前工作区已不存在**（工作区整理时迁入归档）；文件未丢失，仅路径变化：

| 文档引用（旧路径） | 引用处 | 实际位置（已验证存在） |
|---|---|---|
| `E:/AIprogram/PixelArmor交付/1.0.0-rc.2-b9051149` | `README.md:127`、`NEXT_ACTION.md:127` | `E:/AIprogram/mcthunder-archive/retired/PixelArmor交付/1.0.0-rc.2-b9051149` |
| `E:/AIprogram/PixelArmor交付/1.0.0-rc.1-9998f448` | 历史交付记录 | `E:/AIprogram/mcthunder-archive/retired/PixelArmor交付/1.0.0-rc.1-9998f448` |
| `backups/builds/019/d2afacfe.../20260908-221404/PixelArmor.exe` | `README.md:58` | 归档工作树内 `mcthunder-archive/retired/mcthunder-mainline/backups/**`（多个 probe 目录，含 `PixelArmor.exe`） |
| `backups/packs/village.pck`（export preset 0） | `export_presets.cfg` | 仓库内 `backups/` 不存在（`.gitignore` 排除且未随工作区整理回填） |
| `backups/builds/PixelArmor.exe`（export preset 1/2） | `export_presets.cfg` | 同上 |

**处置**：
- 本单**只建立索引，不改 `export_presets.cfg`**（改导出路径属于构建/发布流程变更，超出授权）。
- 交付包索引以**相对包路径**优先：新包一律落在 `<候选目录>/delivery/`，由打包步骤生成 `SOURCE_MANIFEST.json`（含源码 SHA、内容哈希、引擎哈希），不在源码树内提交自引用 manifest。
- 旧包（RC1/RC2、019 候选）**保持历史身份**，不重命名、不搬运、不作为今天的构建。

## 4. 历史包身份记录（不改动）

| 包 | 版本 | 源码 SHA | 记录 |
|---|---|---|---|
| RC1 | `1.0.0-rc.1` | `9998f448…` | `docs/RELEASE_FREEZE_RC.json`、`docs/DELIVERY_036.md` |
| RC2 | `1.0.0-rc.2` | `b90511496fe84195ee8421bd3b4c6bfce2768b7a` | 同上；`docs/GATE_E.md` |
| 019 四对四独立候选 | — | `d2afacfe7c360efdd4b8abd13173b9f9ac1f72e2` | `docs/DELIVERY_019.md` |

**当前候选 = 本分支（`work/continuation-20260913`，基线 `a1bac406`）+ 本单之后的实现**，与前三个包**没有任何身份继承关系**；`README.md:3` 已声明"历史 RC2 独立包不包含之后的 RC3 修复"。

## 5. 回滚

- `project.godot` 版本串与 `scripts/core/build_identity.gd` 均为纯显示/常量改动，回滚 = `git revert` 本单提交；不影响任何游戏逻辑、导出预设或历史包。
