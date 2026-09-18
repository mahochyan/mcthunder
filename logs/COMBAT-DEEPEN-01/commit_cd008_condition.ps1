$c='E:\AIprogram\mcthunder-cont'
$g='E:\AIprogram\mcthunder\tools\godot\Godot_v4.7.2-stable_win64_console.exe'
$L="$c\logs\COMBAT-DEEPEN-01"
$tp=0;$tf=0;$bad=@()
foreach ($s in 'run_damage_checks','run_historical_checks','run_shell_checks','run_chemical_checks','run_armor_checks','run_fuze_checks','run_spall_checks','run_modern_garage_checks','run_modern_armor_frame_checks','check_live_fire_respawn') {
  & $g --headless --path $c --fixed-fps 60 -s ("res://tests/" + $s + ".gd") *> "$L\cc-$s.log"
  $o = Get-Content "$L\cc-$s.log" -ErrorAction SilentlyContinue
  $p=@($o|Select-String '^\[PASS\]').Count; $f=@($o|Select-String '^\[FAIL\]').Count
  $tp+=$p;$tf+=$f; if ($f -gt 0) { $bad+=$s }
  "  {0,-32} exit={1} PASS={2,4} FAIL={3}" -f $s,$LASTEXITCODE,$p,$f
  @($o|Select-String '^\[FAIL\]') | Select-Object -First 2 | ForEach-Object { "      " + $_.Line.Trim().Substring(0,[Math]::Min(170,$_.Line.Trim().Length)) }
}
"  TOTAL PASS=$tp FAIL=$tf bad=" + ($bad -join ',')
"=== FINAL STATE CHECK ==="
"  tracked changes (non-uid)=" + @(git -C $c status --porcelain | Where-Object { $_ -notmatch '^\?\?.*\.uid$' -and $_ -notmatch '^\?\?' }).Count
@(git -C $c status --porcelain | Where-Object { $_ -notmatch '^\?\?.*\.uid$' -and $_ -notmatch '^\?\?' }) | ForEach-Object { "    " + $_ }
if ($tf -eq 0) {
  git -C $c add scripts/damage/crew_damage_profile.gd scripts/defs/vehicle_runtime_state.gd docs/wt/continuation/COMBAT_DEEPEN01_CD008_EVIDENCE.md logs/COMBAT-DEEPEN-01
  git -C $c -c user.name=mcthunder-agent -c user.email=agent@mcthunder.local commit -m "MCT-COMBAT-DEEPEN-01 CD08 implementation, first piece: a versioned crew condition beside the legacy boolean, and two acceptance legs turn to met without their expectations being touched. The new profile declares its version, keeps alive present and derived so anything that already reads it sees exactly what it saw, states its severity thresholds as project design initial values rather than external truth, and separates availability from condition so that no unconfirmed middle penalty is switched on - in this version only incapacitation removes a person from duty. The legacy reader keeps working: a record without a condition falls back to the boolean. A record written before this order migrates under a named version with its rollback kept beside it, which is the sixth case, and the state records the migration so the change is auditable. The measured outcome is that the graded condition now exists as product state and the migration reports its version, entries and rollback, with the scenes reading met for those two legs while the expectations stay exactly as they were written. Two legs remain honestly not met: the person key is still the station key, and an incapacitated crew member still revives under a lawful recovery submission. Ten suites re-run including the long live-fire respawn check, and the import generated untracked uid files which are deliberately left out of the commit" 2>&1 | Select-Object -First 2
} else { "  NOT green, nothing committed" }
"  commits=" + (git -C $c rev-list --count main..HEAD)
git -C $c push origin work/combat-deepen-01 2>&1 | Select-Object -Last 1 | ForEach-Object { "  push: " + $_.ToString() }
$remote = ((& git -C $c ls-remote origin refs/heads/work/combat-deepen-01 2>$null) -split '\s+' | Select-Object -First 1)
"  remote_synced=" + ($remote -eq (git -C $c rev-parse HEAD))
