$c='E:\AIprogram\mcthunder-cont'
$g='E:\AIprogram\mcthunder\tools\godot\Godot_v4.7.2-stable_win64_console.exe'
$L="$c\logs\COMBAT-DEEPEN-01"
$tp=0;$tf=0;$bad=@()
foreach ($s in 'run_damage_checks','run_historical_checks','run_shell_checks','run_chemical_checks','run_armor_checks','run_fuze_checks','run_spall_checks','run_modern_garage_checks','run_modern_armor_frame_checks','run_modern_equipment_checks','check_live_fire_respawn') {
  & $g --headless --path $c --fixed-fps 60 -s ("res://tests/" + $s + ".gd") *> "$L\t2-$s.log"
  $o = Get-Content "$L\t2-$s.log" -ErrorAction SilentlyContinue
  $p=@($o|Select-String '^\[PASS\]').Count; $f=@($o|Select-String '^\[FAIL\]').Count
  $tp+=$p;$tf+=$f; if ($f -gt 0) { $bad+=$s }
  "  {0,-32} exit={1} PASS={2,4} FAIL={3}" -f $s,$LASTEXITCODE,$p,$f
  @($o|Select-String '^\[FAIL\]') | Select-Object -First 2 | ForEach-Object { "      " + $_.Line.Trim().Substring(0,[Math]::Min(170,$_.Line.Trim().Length)) }
}
"  TOTAL PASS=$tp FAIL=$tf bad=" + ($bad -join ',')
"=== FINAL STATE CHECK (uid files excluded deliberately) ==="
"  tracked (non-uid)=" + @(git -C $c status --porcelain | Where-Object { $_ -notmatch '^\?\?' }).Count
@(git -C $c status --porcelain | Where-Object { $_ -notmatch '^\?\?' }) | ForEach-Object { "    " + $_ }
if ($tf -eq 0) {
  git -C $c add scripts/damage/crew_damage_profile.gd scripts/defs/vehicle_runtime_state.gd tests/run_cd008_scene_checks.gd logs/COMBAT-DEEPEN-01
  git -C $c -c user.name=mcthunder-agent -c user.email=agent@mcthunder.local commit -m "MCT-COMBAT-DEEPEN-01 CD08: people and stations separate, and an incapacitated crew member no longer revives, so all four acceptance scenes read met with their expectations untouched. A person is now identified apart from the station they occupy, which removes the hazard recorded two rounds ago where one map was keyed by station id and read by person id; every existing reader already resolved the person through the assignments map, so nothing else had to learn a new key, and a station occupancy map keeps the two identities readable side by side. An incapacitated person can no longer be raised back to duty in the same life: the submission is refused by name, while recovery for lesser conditions remains a declared rule this version does not have rather than a silent behaviour. Two device faults of mine were corrected along the way and are worth recording: the scenes were still naming a person by a station id, and one leg was passing for the wrong reason because its submission was rejected before my guard existed. A guard anchor also silently missed on its first attempt because the real line is indented three tabs and I had written four, which is the same class of mistake as the earlier indentation losses, and it was caught because the guard's effect was measured rather than assumed. Eleven suites re-run including the long live-fire respawn check, and the import generated uid files that are deliberately left out of the commit" 2>&1 | Select-Object -First 2
} else { "  NOT green, nothing committed" }
"  commits=" + (git -C $c rev-list --count main..HEAD)
git -C $c push origin work/combat-deepen-01 2>&1 | Select-Object -Last 1 | ForEach-Object { "  push: " + $_.ToString() }
$remote = ((& git -C $c ls-remote origin refs/heads/work/combat-deepen-01 2>$null) -split '\s+' | Select-Object -First 1)
"  remote_synced=" + ($remote -eq (git -C $c rev-parse HEAD))
