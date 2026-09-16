# WT-040-R1 **复现配方**（冷启动一遍复验全部结论 ✓）

> 本文只列**实际执行过**的命令 ✓，并给出**实测到的输出**（非预期值 ✗）。
> 环境 ✓：工作树 `E:/AIprogram/mcthunder-cont` ✓；分支 `work/continuation-20260913` ✓；基线 `main @ a1bac406` ✓（**未改动** ✓）。
> 引擎 ✓：`tools/godot/Godot_v4.7.2-stable_win64_console.exe` ✓（版本 `4.7.2.stable.official.ed1daf0bf` ✓）。
> **约定** ✓：`$c` = 工作树根 ✓；`$g` = 上列引擎路径 ✓；中文路径不经 argv 传递 ✓。

---

## 0. 前置核对（应全部成立 ✓）
```powershell
git -C $c rev-parse --short HEAD                      # 记录当前分支 HEAD
git -C $c status --porcelain | Where-Object { $_ -notmatch '^\?\?' } | Measure-Object   # 已跟踪未提交 = 0
git -C 'E:\AIprogram\mcthunder' rev-parse --short HEAD        # a1bac406（基线未改）
git -C 'E:\AIprogram\mcthunder' status --porcelain | Measure-Object   # 379（基线 porcelain）
& $g --version                                        # 4.7.2.stable.official.ed1daf0bf
```
实测 ✓（2026-09-16 ✓）：已跟踪未提交 **0** ✓ · 基线 `a1bac406` ✓ · 基线 porcelain **379** ✓。

## 1. 两车战斗包：一条命令流水线 ✓
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$c\tests\run_modern_vehicle_pipeline.ps1"
```
**实测输出** ✓：`import/geometry/facts/geometry_check/crew/modules/armor/evidence/gap_audit` 九步 **exit=0 errors=0 OK** ✓ ·
`== steps: 9 ok, 0 failed ==` ✓ · **`MODERN_PIPELINE_OK`** ✓ · gap **`error count=9`**（T-80B ✓）/ **`=10`**（豹2 ✓），
两车 **`BEYOND the shape gate … = 1`** ✓。

## 2. 几何自校验（**必须用裸 ASCII id** ✓）
```powershell
& $g --headless --path $c --fixed-fps 60 -s res://tests/check_modern_geometry.gd -- ussr_t_80b germ_leopard_2a4
```
**实测输出** ✓：`=== 结果: 50 项检查, 0 失败 ===` ✓ · **`MODERN_GEOMETRY_CHECKS_PASS`** ✓ · exit **0** ✓。
> ⚠️ 该检查**跳过任何含 `=` 的参数** ✗（现改为**响亮报错** ✓）⇒ 若写成 `id=path` 会 **exit=1** ✓ 并提示 ✓。

## 3. 层级探针（`LayoutValidator` / `definitions`）✓
```powershell
& $g --headless --path $c --fixed-fps 60 -s res://tests/probe_package_layers.gd
```
**实测输出** ✓：T-80B `geometry.build -> ok, parts=6 armor_patches=56` ✓ · **`LayoutValidator.errors=0`** ✓ ·
`VehicleShellCatalog.ok=false errors=1`（**`no admitted shell set`** ✓）· `definition ussr_t_80b{,_gun,_shell} errors=0` ✓；
豹2 `armor_patches=47` ✓ · **`LayoutValidator.errors=2`** ✓（两项 `response_profile` **设计** ✓）· 三个 `definition` **errors=0** ✓。

## 4. 同域回归（9 套件，**以退出码为准** ✓）
```powershell
foreach ($s in 'run_modern_model_mount_checks','run_model_binding_checks','run_model_binding_probe_checks',
               'run_role_mapping_checks','run_chemical_content_checks','run_composite_content_checks',
               'run_content_record_checks','run_long_rod_content_checks','run_spall_content_checks') {
  & $g --headless --path $c --fixed-fps 60 -s ("res://tests/"+$s+".gd")
  "$s exit=$LASTEXITCODE"
}
```
**实测** ✓：**41** ✓ · **63** ✓ · **60** ✓ · **72** ✓ · **31** ✓ · **50** ✓ · **65** ✓ · **24** ✓ · **33**（PASS ✓，FAIL 全 0 ✓），**exit 全 0** ✓。
> ⚠️ **必须看退出码** ✗：只数 `[FAIL]` 行会让**不存在的套件名**也报"全绿" ✓（实测假名 ⇒ **exit=1** ✓）。

## 5. 运行证据（第 ③/⑤ 阶段 ✓）
```powershell
# 应用流程（127/0 ✓）· 辅助能力（51/0 ✓）· 科技树（50/0 ✓）
foreach ($s in 'run_app_flow_checks','run_support_actions_checks','run_tech_segment_checks') {
  & $g --headless --path $c --fixed-fps 60 -s ("res://tests/"+$s+".gd"); "$s exit=$LASTEXITCODE"
}
# 无注入真实对局（14/14 ✓；两张图各走完整链路；约 10 分钟，自带 1500 s 硬超时 ✓）
& $g --headless --path $c --fixed-fps 60 -s res://tests/run_app_match_cycle.gd
```
**实测** ✓：`APP_FLOW_CHECKS_PASS` ✓ · `SUPPORT_ACTIONS_CHECKS_PASS` ✓（**51/0** ✓）· `TECH_SEGMENT_CHECKS_PASS` ✓（**50/0** ✓）；
对局 **`=== 结果: 14 项检查, 0 失败 ===`** ✓ · **`APP_MATCH_CYCLE_CHECKS_PASS`** ✓
（两图各含：正常车库 → 对局 → `reason=tickets` → 摘要冻结 ✓ → 单据无待发 ✓ → 幂等 ✓ → 新世界 ✓ → 回车库 ✓）。

## 6. 官方门禁（**约 40–90 分钟；须独占，期间不要再跑引擎** ✓）
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$c\tests\run_suite_checks.ps1" `
  -EnginePath $g -TimeoutSeconds 1500 *> "$c\logs\WT-040-R1\gate-check.log"
(Get-Content "$c\logs\WT-040-R1\gate-check.log" | Select-String ': checks=').Count   # 128
(Get-Content "$c\logs\WT-040-R1\gate-check.log" | Select-String 'passed=False').Count # 2
```
**实测** ✓（干净独占运行 ✓）：**128 套件** ✓ · **126 PASS / 2 FAIL** ✓，两红为
`run_industrial_battle_checks`（**既存到点红** ✓）与 `run_challenge_checks`（**140 项**登记夹具边界 **B4** ✓）
⇒ ⇒ **与基线一致 ⇒ 零回归** ✓。
> ⚠️ 判据 ✓：看**已完成套件数** ✓ 与**引擎本体 CPU 累积** ✓（**console 包装器** CPU 恒为 0 ✗ 不可作判据 ✓）；
> **不要**用总日志时间戳判停滞 ✗（套件之间不写日志 ✓）。

## 7. 两车战斗包的**两项几何修正**（证伪循环 ✓）
```powershell
# ① 先只装断言 ⇒ 预期在**两处**变红（炮盾高度 · 豹2 轮廓重合点）
# ② 落修正（炮盾下限在 if/else 之后统一施加 ✓；轮廓 5 mm 去重 ✓，<8 点即响亮拒收 ✓）
# ③ 重跑 ⇒ 预期全绿
```
**实测** ✓：修正前 **`[FAIL] ussr_t_80b: mantlet half-height 0.0540 encloses the bore 0.0625`** ✓ 与
**`[FAIL] germ_leopard_2a4: adjacent outline points are at least 5 mm apart (closest 0.00000)`** ✓；
修正后 **`MODERN_GEOMETRY_CHECKS_PASS`** ✓（T-80B `hh 0.0810` ✓ · 豹2 轮廓 **15 → 13** 点 ✓、最近间距 **0.11211** ✓），
层级探针 **`LayoutValidator` 4 → 0** ✓ / **7 → 2** ✓。

## 8. 独立可运行包（**当前受阻** ✗，见决策表 ④）
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$c\tests\build_release.ps1"
# 实测 ⇒ Build stopped at fresh_import; No verified release ZIP created
#        其 stdout 显示导入成功（[DONE] reimport ×2、0 条错误），但 RESULTS.json 的 exit_code=null
```
⇒ 属**发布工具链既存缺陷** ✓（PowerShell `Start-Process` 退出码陷阱 ✓）；**该脚本即构建发布流程** ✗ ⇒ **未改** ✓。
> 客户端包**本已存在** ✓（`backups/builds/PixelArmorClient.exe` ✓，预设 **`Windows Client`** ✓）；
> 缺的是 **`BUILD_MANIFEST.json`** ✓（**仅**由该脚本写出 ✓）⇒ **未手工伪造** ✗。

## 9. 一键复验脚本（建议顺序 ✓）
```
0 前置核对  →  1 流水线  →  2 几何自校验  →  3 层级探针  →  4 同域 9 套件
                                                              ↓
                            6 官方门禁（独占 ✓）  ←  5 运行证据 3 套件 + 真实对局
```
> **全部结论的原始日志** ✓ 见 `logs/WT-040-R1/` ✓（最新验收：`final-acceptance2-20260916-115149/` ✓；
> 旧验收已标 `SUPERSEDED` ✓）。**结论→证据**对照见 `WT-040-R1_EVIDENCE_TABLE.md` ✓。
