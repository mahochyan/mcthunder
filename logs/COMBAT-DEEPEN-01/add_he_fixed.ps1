$c='E:\AIprogram\mcthunder-cont'
$g='E:\AIprogram\mcthunder\tools\godot\Godot_v4.7.2-stable_win64_console.exe'
$L="$c\logs\COMBAT-DEEPEN-01"

# (a) allow the external blast effect in the impact-profile whitelist
$p0="$c\scripts\armor\armor_impact_profile.gd"
$t0 = Get-Content $p0 -Raw -Encoding UTF8
$a0 = 'if not fragment and effect not in ["kinetic","internal_burst"]:'
$b0 = 'if not fragment and effect not in ["kinetic","internal_burst","he_blast"]:'
$n0 = ([regex]::Matches($t0,[regex]::Escape($a0))).Count
$t0 = $t0.Replace($a0,$b0)
[IO.File]::WriteAllText($p0, $t0, (New-Object Text.UTF8Encoding($false)))
"  impact_whitelist_edit=$n0"

# (b) add ONE engineering HE, built with a FULL-CALIBRE impact profile (the long-rod curve of the template was wrong for it)
$p1="$c\configs\vehicles\engineering\ussr_t_80b.json"
$v = Get-Content $p1 -Raw -Encoding UTF8 | ConvertFrom-Json
$src = $v.shell_catalog.shells | Where-Object { [string]$_.id -eq 'eng_125_apfsds_v1' } | Select-Object -First 1
$he = $src | ConvertTo-Json -Depth 12 | ConvertFrom-Json
$he.id = "eng_125_he_v1"
$he.label = "125mm engineering HE (project design values)"
$he.family = "HE"
$he.source_bullet_type = "he_tank"
$he.effect_policy = "he_blast"
$he.verification = "estimated"
$he.historical_verified = $false
$he.muzzle_velocity_mps = 700.0
$he.max_flight_time_s = 6.0
$he.gravity_scale = 1.0
$he.penetration_curve = @(@(0.0,30.0),@(500.0,30.0),@(1500.0,30.0),@(2500.0,30.0))
# the impact profile must be a full-calibre one for this effect, not the long-rod curve the template carried
$impact = [pscustomobject]@{
  version="wt012-full-caliber-v1"; family="AP"; normalization_deg=2.0; overmatch_ratio=3.0; ricochet_deg=75.0;
  material_coefficients=[pscustomobject]@{ rolled=1.0; cast=0.95 }; provenance="game_rule"; historical_value=$null;
  reason="CD07 project design initial value: the engineering HE meets armour with its own full-calibre game-rule response."
}
$he.PSObject.Properties.Remove('impact_profile')
$he | Add-Member -NotePropertyName impact_profile -NotePropertyValue $impact
$he.post_penetration_profile.version = "cd006-internal-burst-v1"
$he.post_penetration_profile.count = 5
$he.post_penetration_profile.cone_deg = 50.0
$he.post_penetration_profile.range_m = 3.0
$he.post_penetration_profile.budget_fraction = 0.20
$he.post_penetration_profile.max_total_mm = 50.0
$he.post_penetration_profile.min_residual_mm = 4.0
$he.post_penetration_profile.reason = "CD07 project design initial value: the fragment channel of this engineering HE."
$fuze = [pscustomobject]@{ mode="penetration_delay"; arming_thickness_mm=5.0; delay_s=0.02; provenance="game_rule"; historical_value=$null; ruleset_id="cd07-he-contact-delay-v1"; reason="CD07 project design initial values for a contact HE with a short delay; no historical fuze figure is claimed." }
$he | Add-Member -NotePropertyName fuze_policy -NotePropertyValue $fuze
$note = "project engineering rule cd07-eng-he-v1: a play-balance value for the CD07 engineering HE, not a claim about any historical round."
$loc = "mcthunder project engineering rule set cd07-eng-he-v1 (authored in this repository)"
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
$ev.impact.value = $impact
foreach ($k in @('identity','effect','ballistics','post_penetration','impact')) { $ev.$k.note = $note; $ev.$k.location = $loc }
$v.shell_catalog.shells = @($v.shell_catalog.shells) + @($he)
$v.compatible_shells = @($v.compatible_shells) + @($he.id)
[IO.File]::WriteAllText($p1, ($v | ConvertTo-Json -Depth 12), (New-Object Text.UTF8Encoding($false)))
$chk = Get-Content $p1 -Raw -Encoding UTF8 | ConvertFrom-Json
"  t80b shells=" + @($chk.shell_catalog.shells).Count + " ; compatible=" + (($chk.compatible_shells) -join '|')
"  he has fuze=" + ($chk.shell_catalog.shells | Where-Object { $_.id -eq 'eng_125_he_v1' } | ForEach-Object { [bool]($_.PSObject.Properties.Name -contains 'fuze_policy') })

# (c) gates
foreach ($s in 'run_modern_garage_checks','run_modern_armor_frame_checks','run_shell_checks','run_historical_checks') {
  & $g --headless --path $c --fixed-fps 60 -s ("res://tests/" + $s + ".gd") *> "$L\he4-$s.log"
  $o = Get-Content "$L\he4-$s.log" -ErrorAction SilentlyContinue
  "  {0,-32} exit={1} PASS={2,4} FAIL={3}" -f $s,$LASTEXITCODE,@($o|Select-String '^\[PASS\]').Count,@($o|Select-String '^\[FAIL\]').Count
  @($o|Select-String '^\[FAIL\]') | Select-Object -First 4 | ForEach-Object { "      " + $_.Line.Trim().Substring(0,[Math]::Min(180,$_.Line.Trim().Length)) }
}
