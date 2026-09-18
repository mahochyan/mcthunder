$c='E:\AIprogram\mcthunder-cont'
$g='E:\AIprogram\mcthunder\tools\godot\Godot_v4.7.2-stable_win64_console.exe'
$L="$c\logs\COMBAT-DEEPEN-01"

# (a) the two magic sixes become the invariant they were meant to express: the battle receives exactly the total edited.
$pv="$c\scripts\diagnostics\modern_garage_verifier.gd"
$tv = Get-Content $pv -Raw -Encoding UTF8
$a1 = 'var wanted: Dictionary = prep.loadouts[id].duplicate(true)'
$b1 = @'
var wanted: Dictionary = prep.loadouts[id].duplicate(true)
		# The total the player edited, rather than a constant: adding a round type changes the weapon's distribution, and what
		# this assertion has always been about is that the battle receives exactly what the player edited.
		var expected_total: int = 0
		for edited_count in wanted.counts.values(): expected_total += int(edited_count)
'@
$n1 = ([regex]::Matches($tv,[regex]::Escape($a1))).Count
$tv = $tv.Replace($a1,$b1)
$n2 = ([regex]::Matches($tv,'gunner\.rounds_remaining==6')).Count
$tv = $tv.Replace('battle.actor.gunner.rounds_remaining==6','battle.actor.gunner.rounds_remaining==expected_total')
[IO.File]::WriteAllText($pv, $tv, (New-Object Text.UTF8Encoding($false)))
"  expected_total_insert=$n1 ; magic_sixes_replaced=$n2"

# (b) build the engineering HE ONCE and land that same object
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
$fresh = Get-Content "$c\configs\vehicles\engineering\ussr_t_80b.json" -Raw -Encoding UTF8 | ConvertFrom-Json
$landed = Build-He $fresh
[IO.File]::WriteAllText("$c\configs\vehicles\engineering\ussr_t_80b.json", ($landed | ConvertTo-Json -Depth 12), (New-Object Text.UTF8Encoding($false)))
$chk = Get-Content "$c\configs\vehicles\engineering\ussr_t_80b.json" -Raw -Encoding UTF8 | ConvertFrom-Json
"  t80b shells=" + @($chk.shell_catalog.shells).Count + " compatible=" + (($chk.compatible_shells) -join '|') + " default=" + [string]$chk.shell_catalog.default

# (c) full-ish suites
$tp=0;$tf=0;$bad=@()
foreach ($s in 'run_modern_garage_checks','run_modern_armor_frame_checks','run_historical_checks','run_shell_checks','run_modern_equipment_checks','run_modern_support_checks','run_chemical_checks','run_fuze_checks','run_spall_checks','run_armor_checks') {
  & $g --headless --path $c --fixed-fps 60 -s ("res://tests/" + $s + ".gd") *> "$L\c108-$s.log"
  $o = Get-Content "$L\c108-$s.log" -ErrorAction SilentlyContinue
  $p=@($o|Select-String '^\[PASS\]').Count; $f=@($o|Select-String '^\[FAIL\]').Count
  $tp+=$p;$tf+=$f; if ($f -gt 0) { $bad+=$s }
  "  {0,-34} exit={1} PASS={2,4} FAIL={3}" -f $s,$LASTEXITCODE,$p,$f
  @($o|Select-String '^\[FAIL\]') | Select-Object -First 2 | ForEach-Object { "      " + $_.Line.Trim().Substring(0,[Math]::Min(170,$_.Line.Trim().Length)) }
}
"  TOTAL PASS=$tp FAIL=$tf bad=" + ($bad -join ',')
"=== FINAL STATE CHECK ==="
"  tracked changes=" + @(git -C $c status --porcelain -- scripts configs tests | Where-Object { $_ -notmatch '^\?\?' }).Count
@(git -C $c status --porcelain -- scripts configs tests | Where-Object { $_ -notmatch '^\?\?' }) | ForEach-Object { "    " + $_ }
