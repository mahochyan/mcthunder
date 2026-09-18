$c='E:\AIprogram\mcthunder-cont'
$g='E:\AIprogram\mcthunder\tools\godot\Godot_v4.7.2-stable_win64_console.exe'
$L="$c\logs\COMBAT-DEEPEN-01"
$tp=0;$tf=0;$bad=@()
foreach ($s in 'run_projectile_checks','run_shell_checks','run_fuze_checks','run_spall_checks','run_chemical_checks','run_armor_checks','run_damage_checks','run_modern_garage_checks','run_historical_checks') {
  & $g --headless --path $c --fixed-fps 60 -s ("res://tests/" + $s + ".gd") *> "$L$([char]92)wf-$s.log"
  $o = Get-Content "$L\wf-$s.log" -ErrorAction SilentlyContinue
  $p=@($o|Select-String '^\[PASS\]').Count; $f=@($o|Select-String '^\[FAIL\]').Count
  $tp+=$p;$tf+=$f; if ($f -gt 0) { $bad+=$s }
  "  {0,-32} exit={1} PASS={2,4} FAIL={3}" -f $s,$LASTEXITCODE,$p,$f
  @($o|Select-String '^\[FAIL\]') | Select-Object -First 2 | ForEach-Object { "      " + $_.Line.Trim().Substring(0,[Math]::Min(170,$_.Line.Trim().Length)) }
}
"  TOTAL PASS=$tp FAIL=$tf bad=" + ($bad -join ',')
"=== FINAL STATE CHECK ==="
"  tracked changes=" + @(git -C $c status --porcelain -- scripts configs tests | Where-Object { $_ -notmatch '^\?\?' }).Count
@(git -C $c status --porcelain -- scripts configs tests | Where-Object { $_ -notmatch '^\?\?' }) | ForEach-Object { "    " + $_ }
Remove-Item -Recurse -Force "$c\assets\vehicles\test_cd007_occl_*" -ErrorAction SilentlyContinue
if ($tf -eq 0) {
  git -C $c add scripts/projectiles/fragment_system.gd tests/probe_cd007_wall_occlusion.gd logs/COMBAT-DEEPEN-01
  git -C $c -c user.name=mcthunder-agent -c user.email=agent@mcthunder.local commit -m "MCT-COMBAT-DEEPEN-01 CD07-T04: the external blast is admitted to the multi-target fragment path, which is necessary but measured NOT sufficient, and the tree stays green. Four gated changes were made in the fragment system: an external blast is recognised as an outside explosion so it takes the same eligibility route as a delayed one, the left-target guard no longer applies to it, its travel cap is unbounded rather than computed from a target it does not have, and its candidate set is every supplied snapshot because it is inside none of them. Every one of those is gated on the external blast policy alone. The measurement is blunt: the occlusion probe still records zero damage records and both targets unchanged, so these changes fixed a real assumption but did not yet make fragments strike anything, and the single-run contrast still cannot distinguish an occluded target from nothing happening. Rather than keep editing on a hunch, which is the mistake I recorded as a rule after three regression rounds earlier, the remaining link will be found by instrumenting the fragment loop to report each fragment's direction, eligibility size, query result and terminal reason. Nine suites re-run and the tree carries only the fragment system and the probe" 2>&1 | Select-Object -First 2
} else { "  NOT green: reverting the fragment system changes" ; git -C $c checkout -- scripts/projectiles/fragment_system.gd ; "  reverted; tracked changes=" + @(git -C $c status --porcelain -- scripts configs tests | Where-Object { $_ -notmatch '^\?\?' }).Count }
"  commits=" + (git -C $c rev-list --count main..HEAD)
git -C $c push origin work/combat-deepen-01 2>&1 | Select-Object -Last 1 | ForEach-Object { "  push: " + $_.ToString() }
$local = git -C $c rev-parse HEAD
$remote = ((& git -C $c ls-remote origin refs/heads/work/combat-deepen-01 2>$null) -split '\s+' | Select-Object -First 1)
"  remote_synced=" + ($remote -eq $local)
