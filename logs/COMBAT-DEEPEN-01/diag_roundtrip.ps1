$c='E:\AIprogram\mcthunder-cont'
$g='E:\AIprogram\mcthunder\tools\godot\Godot_v4.7.2-stable_win64_console.exe'
$L="$c\logs\COMBAT-DEEPEN-01"
$p="$c\configs\vehicles\engineering\ussr_t_80b.json"
"=== baseline (untouched file) ==="
& $g --headless --path $c --fixed-fps 60 -s res://tests/run_modern_garage_checks.gd *> "$L\rt-base.log"
$o = Get-Content "$L\rt-base.log" -ErrorAction SilentlyContinue
"  run_modern_garage_checks exit=$LASTEXITCODE PASS=" + @($o|Select-String '^\[PASS\]').Count + " FAIL=" + @($o|Select-String '^\[FAIL\]').Count
"=== round trip the file UNCHANGED (ConvertTo-Json depth 12) ==="
$v = Get-Content $p -Raw -Encoding UTF8 | ConvertFrom-Json
[IO.File]::WriteAllText($p, ($v | ConvertTo-Json -Depth 12), (New-Object Text.UTF8Encoding($false)))
"  file bytes=" + (Get-Item $p).Length
& $g --headless --path $c --fixed-fps 60 -s res://tests/run_modern_garage_checks.gd *> "$L\rt-after.log"
$o2 = Get-Content "$L\rt-after.log" -ErrorAction SilentlyContinue
"  run_modern_garage_checks exit=$LASTEXITCODE PASS=" + @($o2|Select-String '^\[PASS\]').Count + " FAIL=" + @($o2|Select-String '^\[FAIL\]').Count
@($o2|Select-String '^\[FAIL\]') | Select-Object -First 3 | ForEach-Object { "      " + $_.Line.Trim().Substring(0,[Math]::Min(170,$_.Line.Trim().Length)) }
"=== revert ==="
git -C $c checkout -- configs/vehicles/engineering/ussr_t_80b.json
"  tracked changes=" + @(git -C $c status --porcelain -- scripts configs | Where-Object { $_ -notmatch '^\?\?' }).Count
