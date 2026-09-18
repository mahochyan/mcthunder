$c='E:\AIprogram\mcthunder-cont'
$g='E:\AIprogram\mcthunder\tools\godot\Godot_v4.7.2-stable_win64_console.exe'
$L="$c\logs\COMBAT-DEEPEN-01"
$tp=0;$tf=0;$bad=@()
foreach ($s in 'run_projectile_checks','run_shell_checks','run_fuze_checks','run_spall_checks','run_chemical_checks','run_armor_checks','run_damage_checks','run_modern_garage_checks','run_historical_checks','run_modern_armor_frame_checks','run_modern_equipment_checks','check_live_fire_respawn') {
  & $g --headless --path $c --fixed-fps 60 -s ("res://tests/" + $s + ".gd") *> "$L\wb-$s.log"
  $o = Get-Content "$L\wb-$s.log" -ErrorAction SilentlyContinue
  $p=@($o|Select-String '^\[PASS\]').Count; $f=@($o|Select-String '^\[FAIL\]').Count
  $tp+=$p;$tf+=$f; if ($f -gt 0) { $bad+=$s }
  "  {0,-34} exit={1} PASS={2,4} FAIL={3}" -f $s,$LASTEXITCODE,$p,$f
  @($o|Select-String '^\[FAIL\]') | Select-Object -First 2 | ForEach-Object { "      " + $_.Line.Trim().Substring(0,[Math]::Min(170,$_.Line.Trim().Length)) }
}
"  TOTAL PASS=$tp FAIL=$tf bad=" + ($bad -join ',')
"=== FINAL STATE CHECK ==="
"  tracked changes=" + @(git -C $c status --porcelain -- scripts configs tests | Where-Object { $_ -notmatch '^\?\?' }).Count
@(git -C $c status --porcelain -- scripts configs tests | Where-Object { $_ -notmatch '^\?\?' }) | ForEach-Object { "    " + $_ }
Remove-Item -Recurse -Force "$c\assets\vehicles\test_cd007_world_*" -ErrorAction SilentlyContinue
if ($tf -eq 0) {
  git -C $c add scripts/projectiles/projectile_manager.gd tests/probe_cd007_world_burst.gd logs/COMBAT-DEEPEN-01
  git -C $c -c user.name=mcthunder-agent -c user.email=agent@mcthunder.local commit -m "MCT-COMBAT-DEEPEN-01 CD07 design point three, second half: an external HE detonates on a WORLD contact, and two real gaps it exposed are closed. Firing the round at a box on the world layer now ends in a detonation with the same three channels as an armour contact - fragment, blast and overpressure - and the pressure verdict is honestly false, with the recorded reason saying that a closed compartment with no breach and no declared opening gives the pressure no path in, so nothing is invented where there is nothing to be inside. The first gap is that the external verdict was only written for a fuzed burst, so a contact HE, which carries no fuze, never recorded whether its explosion was outside the hull; that line now runs for every burst. The second is a judgment of mine rather than a defect: I required the terminal reason to say the world contact, but the emitter owns the terminal and calls it an internal burst, so the honest fix was to record the contact kind ON the burst, which is a stronger statement than the constant I first wrote and is not a relaxation. Twelve suites re-run as the old-behaviour control including the long live-fire respawn check, and the final state carries only the manager and the new probe" 2>&1 | Select-Object -First 2
} else { "  NOT green, nothing committed" }
"  commits=" + (git -C $c rev-list --count main..HEAD)
git -C $c push origin work/combat-deepen-01 2>&1 | Select-Object -Last 1 | ForEach-Object { "  push: " + $_.ToString() }
$local = git -C $c rev-parse HEAD
$remote = ((& git -C $c ls-remote origin refs/heads/work/combat-deepen-01 2>$null) -split '\s+' | Select-Object -First 1)
"  remote_synced=" + ($remote -eq $local)
