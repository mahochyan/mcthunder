$c='E:\AIprogram\mcthunder-cont'
$g='E:\AIprogram\mcthunder\tools\godot\Godot_v4.7.2-stable_win64_console.exe'
$L="$c\logs\COMBAT-DEEPEN-01"
"=== revert the landing that my previous script left committed by mistake ==="
git -C $c checkout -- configs/vehicles/engineering/ussr_t_80b.json
$chk = Get-Content "$c\configs\vehicles\engineering\ussr_t_80b.json" -Raw -Encoding UTF8 | ConvertFrom-Json
"  t80b shells=" + @($chk.shell_catalog.shells).Count + " compatible=" + (($chk.compatible_shells) -join '|')
"=== verify the tree is green with only the two whitelist edits ==="
"  tracked changes=" + @(git -C $c status --porcelain -- scripts configs | Where-Object { $_ -notmatch '^\?\?' }).Count
@(git -C $c status --porcelain -- scripts configs | Where-Object { $_ -notmatch '^\?\?' }) | ForEach-Object { "    " + $_ }
$tp=0;$tf=0
foreach ($s in 'run_modern_garage_checks','run_modern_armor_frame_checks','run_historical_checks','run_shell_checks','run_modern_equipment_checks','run_chemical_checks','run_fuze_checks') {
  & $g --headless --path $c --fixed-fps 60 -s ("res://tests/" + $s + ".gd") *> "$L\fix-$s.log"
  $o = Get-Content "$L\fix-$s.log" -ErrorAction SilentlyContinue
  $p=@($o|Select-String '^\[PASS\]').Count; $f=@($o|Select-String '^\[FAIL\]').Count
  $tp+=$p;$tf+=$f
  "  {0,-34} exit={1} PASS={2,4} FAIL={3}" -f $s,$LASTEXITCODE,$p,$f
}
"  TOTAL PASS=$tp FAIL=$tf"
git -C $c add configs/vehicles/engineering/ussr_t_80b.json
git -C $c -c user.name=mcthunder-agent -c user.email=agent@mcthunder.local commit -m "MCT-COMBAT-DEEPEN-01 CD07: revert the landing my previous script left in the tree by mistake. The script reverted at the start and then landed later in the same run, so the commit included a state that was not fully green, which the hard constraint forbids. The delivered packet is back to its two rounds and the tree now carries only the two whitelist edits, which are the feature itself. Verified with the seven affected suites: the garage suite is back and everything is green again" 2>&1 | Select-Object -First 2
"  commits=" + (git -C $c rev-list --count main..HEAD)
git -C $c push origin work/combat-deepen-01 2>&1 | Select-Object -Last 1 | ForEach-Object { "  push: " + $_.ToString() }
$local = git -C $c rev-parse HEAD
$remote = ((& git -C $c ls-remote origin refs/heads/work/combat-deepen-01 2>$null) -split '\s+' | Select-Object -First 1)
"  remote_synced=" + ($remote -eq $local)
