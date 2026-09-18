$c='E:\AIprogram\mcthunder-cont'
$g='E:\AIprogram\mcthunder\tools\godot\Godot_v4.7.2-stable_win64_console.exe'
$L="$c\logs\COMBAT-DEEPEN-01"
"=== revert the broken landing first ==="
git -C $c checkout -- configs/vehicles/engineering/ussr_t_80b.json
"  tracked changes=" + @(git -C $c status --porcelain -- scripts configs | Where-Object { $_ -notmatch '^\?\?' }).Count

function Build-He($v) {
  $src = $v.shell_catalog.shells | Where-Object { [string]$_.id -eq 'eng_125_apfsds_v1' } | Select-Object -First 1
  $he = $src | ConvertTo-Json -Depth 12 | ConvertFrom-Json
  $he.id = "eng_125_he_v1"; $he.label = "125mm engineering HE (project design values)"
  $he.family = "HE"; $he.source_bullet_type = "he_tank"; $he.effect_policy = "he_blast"
  $he.muzzle_velocity_mps = 700.0; $he.max_flight_time_s = 6.0; $he.gravity_scale = 1.0
  $he.penetration_curve = @(@(0.0,30.0),@(500.0,30.0),@(1500.0,30.0),@(2500.0,30.0))
  $impact = [pscustomobject]@{ version="wt012-full-caliber-v1"; family="AP"; normalization_deg=2.0; overmatch_ratio=3.0; ricochet_deg=75.0;
    material_coefficients=[pscustomobject]@{ rolled=1.0; cast=0.95 }; provenance="game_rule"; historical_value=$null;
    reason="CD07 project design initial value: the engineering HE meets armour with its own full-calibre game-rule response." }
  $he.PSObject.Properties.Remove('impact_profile')
  $he | Add-Member -NotePropertyName impact_profile -NotePropertyValue $impact
  $prof = $he.post_penetration_profile
  $prof.version = "cd006-internal-burst-v1"; $prof.count = 5; $prof.cone_deg = 50.0; $prof.range_m = 3.0
  $prof.budget_fraction = 0.20; $prof.max_total_mm = 50.0; $prof.min_residual_mm = 4.0
  $prof.reason = "CD07 project design initial value: the fragment channel of this engineering HE."
  $note = "project engineering rule cd07-eng-he-v1: a play-balance value for the CD07 engineering HE, not a claim about any historical round."
  $loc = "mcthunder project engineering rule set cd07-eng-he-v1 (authored in this repository)"
  $ev = $he.evidence
  $ev.identity.value.id = $he.id; $ev.identity.value.family = $he.family
  $ev.identity.value.source_bullet_type = $he.source_bullet_type
  $ev.identity.value.caliber_mm = $he.caliber_mm; $ev.identity.value.gun = $he.gun
  $ev.effect.value = $he.effect_policy
  $ev.ballistics.value.muzzle_velocity_mps = $he.muzzle_velocity_mps
  $ev.ballistics.value.penetration_curve = $he.penetration_curve
  $ev.ballistics.value.max_flight_time_s = $he.max_flight_time_s
  $ev.ballistics.value.gravity_scale = $he.gravity_scale
  $ev.post_penetration.value = $prof; $ev.impact.value = $impact
  foreach ($k in @('identity','effect','ballistics','post_penetration','impact')) { $ev.$k.note = $note; $ev.$k.location = $loc }
  $v.shell_catalog.shells = @($v.shell_catalog.shells) + @($he)
  $v.compatible_shells = @($v.compatible_shells) + @($he.id)
  return $v
}

# read fresh, build ONCE, land that same object
$v = Get-Content "$c\configs\vehicles\engineering\ussr_t_80b.json" -Raw -Encoding UTF8 | ConvertFrom-Json
$landed = Build-He $v
[IO.File]::WriteAllText("$c\configs\vehicles\engineering\ussr_t_80b.json", ($landed | ConvertTo-Json -Depth 12), (New-Object Text.UTF8Encoding($false)))
$chk = Get-Content "$c\configs\vehicles\engineering\ussr_t_80b.json" -Raw -Encoding UTF8 | ConvertFrom-Json
"  t80b shells=" + @($chk.shell_catalog.shells).Count + " compatible=" + (($chk.compatible_shells) -join '|') + " default=" + [string]$chk.shell_catalog.default
"  ids=" + ((@($chk.shell_catalog.shells) | ForEach-Object { [string]$_.id }) -join ',')
$leo = Get-Content "$c\configs\vehicles\engineering\germ_leopard_2a4.json" -Raw -Encoding UTF8 | ConvertFrom-Json
"  leopard shells=" + @($leo.shell_catalog.shells).Count + " compatible=" + (($leo.compatible_shells) -join '|')
foreach ($s in 'run_modern_garage_checks','run_modern_armor_frame_checks','run_shell_checks','run_historical_checks','run_modern_equipment_checks') {
  & $g --headless --path $c --fixed-fps 60 -s ("res://tests/" + $s + ".gd") *> "$L\he9-$s.log"
  $o = Get-Content "$L\he9-$s.log" -ErrorAction SilentlyContinue
  "  {0,-34} exit={1} PASS={2,4} FAIL={3}" -f $s,$LASTEXITCODE,@($o|Select-String '^\[PASS\]').Count,@($o|Select-String '^\[FAIL\]').Count
  @($o|Select-String '^\[FAIL\]') | Select-Object -First 3 | ForEach-Object { "      " + $_.Line.Trim().Substring(0,[Math]::Min(175,$_.Line.Trim().Length)) }
}
