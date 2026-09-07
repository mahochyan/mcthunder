# 003-R2：启动失败受控短路验收（隔离副本模式，GPT 复审 3d410a6 后要求）。
# 用法（工程根）：powershell -ExecutionPolicy Bypass -File tests\abort_check.ps1
#
# 流程（原工程只读，绝不原地改写/自动恢复覆盖）：
#   1. 要求被测候选已提交（工作区干净），取 HEAD 为被测 SHA
#   2. git archive 导出该提交到工程外唯一临时目录
#   3. 副本内 --import + --quit-after 10 确认正常候选可启动
#   4. 仅修改副本 configs（verified 无实质来源 → validate 必拒）
#   5. 子进程以副本为 --path 启动真实主场景（带超时，完整保存 stdout/stderr/退出码）
#   6. PASS 判据：非零退出 + 输出含 003-R2 ABORT + 无意外 SCRIPT ERROR；
#      超时 / 缺引擎 / 意外脚本异常一律 FAIL
#   7. 原工程只读核对（前后 git status 一致）；发现 user:// 旧备份只报告不覆盖
# 注：只用 cmdlet 与实例方法，不用 .NET 静态调用（受限模式兼容）；
#     配置内容为纯 ASCII，ascii 写出无 BOM。

$ErrorActionPreference = 'Stop'
$testsDir = $PSScriptRoot
$root = Split-Path $testsDir
$godot = Join-Path $root 'tools\godot\Godot_v4.7.2-stable_win64_console.exe'
$fail = @()

function Note($m) { Write-Host "[abort-check] $m" }

# 0) 引擎存在（缺失 = FAIL，不是跳过）
if (-not (Test-Path $godot)) { Note "FAIL: godot exe not found at $godot"; exit 1 }

# 1) 被测候选必须已提交（工作区干净——否则测的不是提交内容）
$stBefore = git -C $root status --porcelain
if ($stBefore) { Note "FAIL: working tree not clean; commit the candidate first:"; $stBefore | ForEach-Object { Note "  $_" }; exit 1 }
$sha = (git -C $root rev-parse HEAD).Trim()
Note "testing committed candidate $sha"

# 2) user:// 遗留备份：只报告，不自动覆盖当前配置
$projName = (Select-String -Path (Join-Path $root 'project.godot') -Pattern 'config/name="(.+)"').Matches[0].Groups[1].Value
$legacyBak = Join-Path $env:APPDATA "Godot\app_userdata\$projName\abort_check_backup.tres"
if (Test-Path $legacyBak) { Note "NOTICE: legacy user:// backup found (left by old in-place test), reported only, NOT auto-restored: $legacyBak" }

# 3) 导出已提交候选到工程外临时目录
Note "TEMP=[$env:TEMP]"
$tmp = "$env:TEMP\mcthunder-abort-" + (Get-Random -Maximum 999999999)
Note "tmp=[$tmp]"
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
$zip = Join-Path $tmp 'source.zip'
git -C $root archive --format=zip --output=$zip $sha
if ($LASTEXITCODE -ne 0) { Note "FAIL: git archive failed"; exit 1 }
Expand-Archive -Path $zip -DestinationPath (Join-Path $tmp 'project') -Force
$proj = Join-Path $tmp 'project'
Note "exported to $proj"

# 4) 副本正常候选可启动确认
& $godot --headless --path $proj --import 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) { Note "FAIL: import failed on clean copy"; exit 1 }
& $godot --headless --path $proj --quit-after 10 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) { Note "FAIL: clean copy did not boot normally"; exit 1 }
Note "clean copy boots normally (--quit-after 10 exit=0)"

# 5) 仅修改副本配置：verified 无实质来源 → validate 必拒（ascii 写出无 BOM）
$cfg = Join-Path $proj 'configs\player_tank_vehicle.tres'
if ([string]::IsNullOrEmpty($cfg)) { Note "FAIL: cfg path is null (proj=[$proj])"; exit 1 }
if (-not (Test-Path -LiteralPath $cfg)) { Note "FAIL: cfg missing in copy (cfg=[$cfg])"; exit 1 }
Note "cfg=[$cfg]"
$orig = Get-Content -LiteralPath $cfg -Raw
if (-not $orig.Contains('verification = "unknown"')) { Note "FAIL: marker not found in copy config"; exit 1 }
$bad = $orig.Replace('verification = "unknown"', 'verification = "verified"')
Set-Content -Path $cfg -Value $bad -Encoding ascii -NoNewline
Note "bad config injected into COPY only"

# 6) 子进程以副本为 --path 启动真实主场景（带超时，完整输出）
$so = Join-Path $tmp 'stdout.log'; $se = Join-Path $tmp 'stderr.log'
$p = Start-Process -FilePath $godot -ArgumentList @('--headless', '--path', $proj) -RedirectStandardOutput $so -RedirectStandardError $se -PassThru -NoNewWindow
if (-not $p.WaitForExit(60000)) { $p.Kill(); Note "FAIL: subprocess TIMEOUT (not a pass)"; Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue; exit 1 }
$code = $p.ExitCode
$full = ''
if (Test-Path $so) { $full += Get-Content $so -Raw }
if (Test-Path $se) { $full += Get-Content $se -Raw }
$aborted = $full.Contains('003-R2 ABORT')
$scriptErr = $full.Contains('SCRIPT ERROR')
Note "subprocess exit=$code abort_log=$aborted unexpected_script_error=$scriptErr"

# 7) 原工程只读核对（前后一致；变化则报告，绝不自动恢复覆盖）
$stAfter = git -C $root status --porcelain
if ($stAfter) { Note "FAIL: original working tree changed during test (report only, NOT auto-restored):"; $stAfter | ForEach-Object { Note "  $_" }; $fail += 'original tree changed' }
Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue

# 判定
if (($code -ne 0) -and $aborted -and (-not $scriptErr) -and ($fail.Count -eq 0)) {
	Note "PASS: copy-only bad config -> real main scene aborts with nonzero exit; original tree untouched"
	exit 0
} else {
	Note "FAIL"
	exit 1
}