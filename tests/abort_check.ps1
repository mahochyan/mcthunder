# 003-R2锛氬惎鍔ㄥけ璐ュ彈鎺х煭璺獙鏀讹紙闅旂鍓湰妯″紡锛孏PT 澶嶅 3d410a6 鍚庤姹傦級銆?# 鐢ㄦ硶锛堝伐绋嬫牴锛夛細powershell -ExecutionPolicy Bypass -File tests\abort_check.ps1
#
# 娴佺▼锛堝師宸ョ▼鍙锛岀粷涓嶅師鍦版敼鍐?鑷姩鎭㈠瑕嗙洊锛夛細
#   1. 瑕佹眰琚祴鍊欓€夊凡鎻愪氦锛堝伐浣滃尯骞插噣锛夛紝鍙?HEAD 涓鸿娴?SHA
#   2. git archive 瀵煎嚭璇ユ彁浜ゅ埌宸ョ▼澶栧敮涓€涓存椂鐩綍
#   3. 鍓湰鍐?--import + --quit-after 10 纭姝ｅ父鍊欓€夊彲鍚姩
#   4. 浠呬慨鏀瑰壇鏈?configs锛坴erified 鏃犲疄璐ㄦ潵婧?鈫?validate 蹇呮嫆锛?#   5. 瀛愯繘绋嬩互鍓湰涓?--path 鍚姩鐪熷疄涓诲満鏅紙甯﹁秴鏃讹紝瀹屾暣淇濆瓨 stdout/stderr/閫€鍑虹爜锛?#   6. PASS 鍒ゆ嵁锛氶潪闆堕€€鍑?+ 杈撳嚭鍚?003-R2 ABORT + 鏃犳剰澶?SCRIPT ERROR锛?#      瓒呮椂 / 缂哄紩鎿?/ 鎰忓鑴氭湰寮傚父涓€寰?FAIL
#   7. 鍘熷伐绋嬪彧璇绘牳瀵癸紙鍓嶅悗 git status 涓€鑷达級锛涘彂鐜?user:// 鏃у浠藉彧鎶ュ憡涓嶈鐩?# 娉細鍙敤 cmdlet 涓庡疄渚嬫柟娉曪紝涓嶇敤 .NET 闈欐€佽皟鐢紙鍙楅檺妯″紡鍏煎锛夛紱
#     閰嶇疆鍐呭涓虹函 ASCII锛宎scii 鍐欏嚭鏃?BOM銆?
$ErrorActionPreference = 'Stop'
$testsDir = $PSScriptRoot
$root = Split-Path $testsDir
$godot = Join-Path $root 'tools\godot\Godot_v4.7.2-stable_win64_console.exe'
$fail = @()

function Note($m) { Write-Host "[abort-check] $m" }

# 0) 寮曟搸瀛樺湪锛堢己澶?= FAIL锛屼笉鏄烦杩囷級
if (-not (Test-Path $godot)) { Note "FAIL: godot exe not found at $godot"; exit 1 }

# 1) 琚祴鍊欓€夊繀椤诲凡鎻愪氦锛堝伐浣滃尯骞插噣鈥斺€斿惁鍒欐祴鐨勪笉鏄彁浜ゅ唴瀹癸級
$stBefore = git -C $root status --porcelain
if ($stBefore) { Note "FAIL: working tree not clean; commit the candidate first:"; $stBefore | ForEach-Object { Note "  $_" }; exit 1 }
$sha = (git -C $root rev-parse HEAD).Trim()
Note "testing committed candidate $sha"

# 2) user:// 閬楃暀澶囦唤锛氬彧鎶ュ憡锛屼笉鑷姩瑕嗙洊褰撳墠閰嶇疆
$projName = (Select-String -Path (Join-Path $root 'project.godot') -Pattern 'config/name="(.+)"').Matches[0].Groups[1].Value
$legacyBak = Join-Path $env:APPDATA "Godot\app_userdata\$projName\abort_check_backup.tres"
if (Test-Path $legacyBak) { Note "NOTICE: legacy user:// backup found (left by old in-place test), reported only, NOT auto-restored: $legacyBak" }

# 3) 瀵煎嚭宸叉彁浜ゅ€欓€夊埌宸ョ▼澶栦复鏃剁洰褰?Note "TEMP=[$env:TEMP]"; $tmp = "$env:TEMP\mcthunder-abort-" + (Get-Random -Maximum 999999999); Note "tmp=[$tmp]"
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
$zip = Join-Path $tmp 'source.zip'
git -C $root archive --format=zip --output=$zip $sha
if ($LASTEXITCODE -ne 0) { Note "FAIL: git archive failed"; exit 1 }
Expand-Archive -Path $zip -DestinationPath (Join-Path $tmp 'project') -Force
$proj = Join-Path $tmp 'project'
Note "exported to $proj"

# 4) 鍓湰姝ｅ父鍊欓€夊彲鍚姩纭
& $godot --headless --path $proj --import 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) { Note "FAIL: import failed on clean copy"; exit 1 }
& $godot --headless --path $proj --quit-after 10 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) { Note "FAIL: clean copy did not boot normally"; exit 1 }
Note "clean copy boots normally (--quit-after 10 exit=0)"

# 5) 浠呬慨鏀瑰壇鏈厤缃細verified 鏃犲疄璐ㄦ潵婧?鈫?validate 蹇呮嫆锛坅scii 鍐欏嚭鏃?BOM锛?$cfg = Join-Path $proj 'configs\player_tank_vehicle.tres'
$orig = Get-Content $cfg -Raw
if (-not $orig.Contains('verification = "unknown"')) { Note "FAIL: marker not found in copy config"; exit 1 }
$bad = $orig.Replace('verification = "unknown"', 'verification = "verified"')
Set-Content -Path $cfg -Value $bad -Encoding ascii -NoNewline
Note "bad config injected into COPY only"

# 6) 瀛愯繘绋嬩互鍓湰涓?--path 鍚姩鐪熷疄涓诲満鏅紙甯﹁秴鏃讹紝瀹屾暣杈撳嚭锛?$so = Join-Path $tmp 'stdout.log'; $se = Join-Path $tmp 'stderr.log'
$p = Start-Process -FilePath $godot -ArgumentList @('--headless', '--path', $proj) -RedirectStandardOutput $so -RedirectStandardError $se -PassThru -NoNewWindow
if (-not $p.WaitForExit(60000)) { $p.Kill(); Note "FAIL: subprocess TIMEOUT (not a pass)"; Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue; exit 1 }
$code = $p.ExitCode
$full = ''
if (Test-Path $so) { $full += Get-Content $so -Raw }
if (Test-Path $se) { $full += Get-Content $se -Raw }
$aborted = $full.Contains('003-R2 ABORT')
$scriptErr = $full.Contains('SCRIPT ERROR')
Note "subprocess exit=$code abort_log=$aborted unexpected_script_error=$scriptErr"

# 7) 鍘熷伐绋嬪彧璇绘牳瀵癸紙鍓嶅悗涓€鑷达紱鍙樺寲鍒欐姤鍛婏紝缁濅笉鑷姩鎭㈠瑕嗙洊锛?$stAfter = git -C $root status --porcelain
if ($stAfter) { Note "FAIL: original working tree changed during test (report only, NOT auto-restored):"; $stAfter | ForEach-Object { Note "  $_" }; $fail += 'original tree changed' }
Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue

# 鍒ゅ畾
if (($code -ne 0) -and $aborted -and (-not $scriptErr) -and ($fail.Count -eq 0)) {
	Note "PASS: copy-only bad config -> real main scene aborts with nonzero exit; original tree untouched"
	exit 0
} else {
	Note "FAIL"
	exit 1
}