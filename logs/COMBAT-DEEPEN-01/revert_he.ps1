$c='E:\AIprogram\mcthunder-cont'
$g='E:\AIprogram\mcthunder\tools\godot\Godot_v4.7.2-stable_win64_console.exe'
$L="$c\logs\COMBAT-DEEPEN-01"
"=== revert to the last runnable state ==="
git -C $c checkout -- configs/vehicles/engineering/ussr_t_80b.json scripts/armor/armor_impact_profile.gd
"  tracked changes now=" + @(git -C $c status --porcelain -- scripts configs | Where-Object { $_ -notmatch '^\?\?' }).Count
"=== verify the three suites are green again ==="
$tp=0;$tf=0
foreach ($s in 'run_historical_checks','run_modern_garage_checks','run_modern_armor_frame_checks','run_shell_checks') {
  & $g --headless --path $c --fixed-fps 60 -s ("res://tests/" + $s + ".gd") *> "$L\rev-$s.log"
  $o = Get-Content "$L\rev-$s.log" -ErrorAction SilentlyContinue
  $p=@($o|Select-String '^\[PASS\]').Count; $f=@($o|Select-String '^\[FAIL\]').Count
  $tp+=$p;$tf+=$f
  "  {0,-32} exit={1} PASS={2,4} FAIL={3}" -f $s,$LASTEXITCODE,$p,$f
}
"  TOTAL PASS=$tp FAIL=$tf"
