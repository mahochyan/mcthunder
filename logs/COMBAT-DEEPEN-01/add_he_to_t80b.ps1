$c='E:\AIprogram\mcthunder-cont'
$g='E:\AIprogram\mcthunder\tools\godot\Godot_v4.7.2-stable_win64_console.exe'
$L="$c\logs\COMBAT-DEEPEN-01"

# (a) allow the external blast effect in the impact-profile whitelist, so an HE can declare its own armour response.
$p0="$c\scripts\armor\armor_impact_profile.gd"
$t0 = Get-Content $p0 -Raw -Encoding UTF8
$a0 = 'if not fragment and effect not in ["kinetic","internal_burst"]:'
$b0 = 'if not fragment and effect not in ["kinetic","internal_burst","he_blast"]:'
$n0 = ([regex]::Matches($t0,[regex]::Escape($a0))).Count
$t0 = $t0.Replace($a0,$b0)
[IO.File]::WriteAllText($p0, $t0, (New-Object Text.UTF8Encoding($false)))
"  impact_whitelist_edit=$n0 ; he_blast_allowed=" + $t0.Contains('"internal_burst","he_blast"')

# (b) add ONE engineering HE to the T-80B catalogue by copying its APFSDS entry, changing only what must change.
$p1="$c\configs\vehicles\engineering\ussr_t_80b.json"
$v = Get-Content $p1 -Raw -Encoding UTF8 | ConvertFrom-Json
$src = $v.shell_catalog.shells | Where-Object { [string]$_.id -eq 'eng_125_apfsds_v1' } | Select-Object -First 1
$he = $src | ConvertTo-Json -Depth 12 | ConvertFrom-Json   # deep copy
$he.id = "eng_125_he_v1"
$he.label = "125mm engineering HE (project design values)"
$he.family = "HE"
$he.source_bullet_type = "he_tank"
$he.effect_policy = "he_blast"
$he.verification = "estimated"
$he.muzzle_velocity_mps = 700.0
$he.max_flight_time_s = 6.0
$he.gravity_scale = 1.0
$he.penetration_curve = @(@(0.0,30.0),@(500.0,30.0),@(1500.0,30.0),@(2500.0,30.0))
$he.impact_profile.family = "APHE"
# fragment channel of the HE: its own declared numbers
$he.post_penetration_profile.version = "cd006-internal-burst-v1"
$he.post_penetration_profile.count = 5
$he.post_penetration_profile.cone_deg = 50.0
$he.post_penetration_profile.range_m = 3.0
$he.post_penetration_profile.budget_fraction = 0.20
$he.post_penetration_profile.max_total_mm = 50.0
$he.post_penetration_profile.min_residual_mm = 4.0
$he.post_penetration_profile.reason = "CD07 project design initial value: the fragment channel of this engineering HE, declared through the same extended schema rather than a second one."
$he.fuze_policy = [pscustomobject]@{ mode="penetration_delay"; arming_thickness_mm=5.0; delay_s=0.02; provenance="game_rule"; historical_value=$null; ruleset_id="cd07-he-contact-delay-v1"; reason="CD07 project design initial values for a contact HE with a short delay; no historical fuze figure is claimed." }
# evidence block must stay consistent with the fields above, so it is updated field by field too.
$note = "project engineering rule cd07-eng-he-v1: a play-balance value for the CD07 engineering HE, not a claim about any historical round."
$ev = $he.evidence
$ev.identity.value.id = $he.id
$ev.identity.value.family = $he.family
$ev.identity.value.source_bullet_type = $he.source_bullet_type
$ev.effect.value = $he.effect_policy
$ev.ballistics.value.muzzle_velocity_mps = $he.muzzle_velocity_mps
$ev.ballistics.value.penetration_curve = $he.penetration_curve
$ev.ballistics.value.max_flight_time_s = $he.max_flight_time_s
$ev.ballistics.value.gravity_scale = $he.gravity_scale
$ev.post_penetration.value = $he.post_penetration_profile
$ev.impact.value.family = $he.impact_profile.family
foreach ($k in @('identity','effect','ballistics','post_penetration','impact')) { $ev.$k.note = $note; $ev.$k.location = "mcthunder project engineering rule set cd07-eng-he-v1 (authored in this repository)" }
$v.shell_catalog.shells = @($v.shell_catalog.shells) + @($he)
$v.compatible_shells = @($v.compatible_shells) + @($he.id)
[IO.File]::WriteAllText($p1, ($v | ConvertTo-Json -Depth 12), (New-Object Text.UTF8Encoding($false)))
$chk = Get-Content $p1 -Raw -Encoding UTF8 | ConvertFrom-Json
"  t80b shells=" + @($chk.shell_catalog.shells).Count + " ; compatible=" + (($chk.compatible_shells) -join '|') + " ; default=" + [string]$chk.shell_catalog.default
$leo = Get-Content "$c\configs\vehicles\engineering\germ_leopard_2a4.json" -Raw -Encoding UTF8 | ConvertFrom-Json
"  leopard shells=" + @($leo.shell_catalog.shells).Count + " ; compatible=" + (($leo.compatible_shells) -join '|')

# (c) gates
foreach ($s in 'run_historical_checks','run_shell_checks','run_modern_garage_checks','run_modern_armor_frame_checks') {
  & $g --headless --path $c --fixed-fps 60 -s ("res://tests/" + $s + ".gd") *> "$L\he3-$s.log"
  $o = Get-Content "$L\he3-$s.log" -ErrorAction SilentlyContinue
  "  {0,-32} exit={1} PASS={2,4} FAIL={3}" -f $s,$LASTEXITCODE,@($o|Select-String '^\[PASS\]').Count,@($o|Select-String '^\[FAIL\]').Count
  @($o|Select-String '^\[FAIL\]') | Select-Object -First 3 | ForEach-Object { "      " + $_.Line.Trim().Substring(0,[Math]::Min(170,$_.Line.Trim().Length)) }
}
