$c='E:\AIprogram\mcthunder-cont'
$g='E:\AIprogram\mcthunder\tools\godot\Godot_v4.7.2-stable_win64_console.exe'
$L="$c\logs\COMBAT-DEEPEN-01"
$tp=0;$tf=0;$bad=@()
foreach ($s in 'run_projectile_checks','run_shell_checks','run_fuze_checks','run_spall_checks','run_chemical_checks','run_armor_checks','run_damage_checks','run_modern_garage_checks','run_historical_checks','run_modern_armor_frame_checks','check_live_fire_respawn') {
  & $g --headless --path $c --fixed-fps 60 -s ("res://tests/" + $s + ".gd") *> "$L\cb-$s.log"
  $o = Get-Content "$L\cb-$s.log" -ErrorAction SilentlyContinue
  $p=@($o|Select-String '^\[PASS\]').Count; $f=@($o|Select-String '^\[FAIL\]').Count
  $tp+=$p;$tf+=$f; if ($f -gt 0) { $bad+=$s }
  "  {0,-34} exit={1} PASS={2,4} FAIL={3}" -f $s,$LASTEXITCODE,$p,$f
  @($o|Select-String '^\[FAIL\]') | Select-Object -First 2 | ForEach-Object { "      " + $_.Line.Trim().Substring(0,[Math]::Min(170,$_.Line.Trim().Length)) }
}
"  TOTAL PASS=$tp FAIL=$tf bad=" + ($bad -join ',')
"=== FINAL STATE CHECK ==="
"  tracked changes=" + @(git -C $c status --porcelain -- scripts configs tests | Where-Object { $_ -notmatch '^\?\?' }).Count
@(git -C $c status --porcelain -- scripts configs tests | Where-Object { $_ -notmatch '^\?\?' }) | ForEach-Object { "    " + $_ }
Remove-Item -Recurse -Force "$c\assets\vehicles\test_cd007_landed_*" -ErrorAction SilentlyContinue
if ($tf -eq 0) {
  git -C $c add scripts/projectiles/projectile_manager.gd tests/probe_cd007_he_runtime.gd logs/COMBAT-DEEPEN-01
  git -C $c -c user.name=mcthunder-agent -c user.email=agent@mcthunder.local commit -m "MCT-COMBAT-DEEPEN-01 CD07: the contact HE bursts on contact, and the gap measured two rounds ago is closed at its two located points. The stop branch can only record the surface it stopped on, because the contact handler holds neither the snapshot list nor the physics space; the caller turns that recording into a root event where both are in hand, and it does so through the existing internal burst emitter rather than a second damage path. The change is gated on the external blast policy alone, so every other effect keeps its behaviour word for word, and the measurement is direct: the same shot that previously ended as an armour stop with no burst at all now ends as an armour stop with a root event present, still meeting the armour exactly once with a stopped verdict. My two failed attempts at the edit are worth recording because both failed for the same reason: a here string's indentation did not match the file, and then a whitespace tolerant regular expression anchored with a dollar sign never matched because the raw text keeps carriage returns, so the anchors had to be unique plain substrings instead. Eleven suites are re-run as the old-behaviour control including the long live-fire respawn check, and the final state carries only the manager and the probe" 2>&1 | Select-Object -First 2
} else { "  NOT green, nothing committed" }
"  commits=" + (git -C $c rev-list --count main..HEAD)
git -C $c push origin work/combat-deepen-01 2>&1 | Select-Object -Last 1 | ForEach-Object { "  push: " + $_.ToString() }
$local = git -C $c rev-parse HEAD
$remote = ((& git -C $c ls-remote origin refs/heads/work/combat-deepen-01 2>$null) -split '\s+' | Select-Object -First 1)
"  remote_synced=" + ($remote -eq $local)
