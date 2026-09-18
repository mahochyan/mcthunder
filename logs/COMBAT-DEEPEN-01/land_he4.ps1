$c='E:\AIprogram\mcthunder-cont'
$g='E:\AIprogram\mcthunder\tools\godot\Godot_v4.7.2-stable_win64_console.exe'
$L="$c\logs\COMBAT-DEEPEN-01"
$fix="$c\assets\vehicles\test_cd007_he_fixture"
New-Item -ItemType Directory -Force -Path $fix | Out-Null
[IO.File]::WriteAllText("$fix\.gdignore","",(New-Object Text.UTF8Encoding($false)))

# (1) shell-level whitelists: the effect is supported, and like the other terminal effects it needs armour resolution.
$p1="$c\scripts\defs\shell_definition.gd"
$t1 = Get-Content $p1 -Raw -Encoding UTF8
$a1 = 'if effect_policy not in ["kinetic","internal_burst","long_rod","chemical"]: errors.append("effect_policy: unsupported")'
$b1 = 'if effect_policy not in ["kinetic","internal_burst","long_rod","chemical","he_blast"]: errors.append("effect_policy: unsupported")'
$n1 = ([regex]::Matches($t1,[regex]::Escape($a1))).Count
$t1 = $t1.Replace($a1,$b1)
$a2 = 'if effect_policy in ["internal_burst","long_rod","chemical"] and armor_policy != "resolve":'
$b2 = 'if effect_policy in ["internal_burst","long_rod","chemical","he_blast"] and armor_policy != "resolve":'
$n2 = ([regex]::Matches($t1,[regex]::Escape($a2))).Count
$t1 = $t1.Replace($a2,$b2)
[IO.File]::WriteAllText($p1, $t1, (New-Object Text.UTF8Encoding($false)))
"  shell_whitelist=$n1 ; terminal_effects=$n2"

# (2) impact-profile whitelist
$p0="$c\scripts\armor\armor_impact_profile.gd"
$t0 = Get-Content $p0 -Raw -Encoding UTF8
$a0 = 'if not fragment and effect not in ["kinetic","internal_burst"]:'
$b0 = 'if not fragment and effect not in ["kinetic","internal_burst","he_blast"]:'
$n0 = ([regex]::Matches($t0,[regex]::Escape($a0))).Count
$t0 = $t0.Replace($a0,$b0)
[IO.File]::WriteAllText($p0, $t0, (New-Object Text.UTF8Encoding($false)))
"  impact_whitelist=$n0"

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

$real = Get-Content "$c\configs\vehicles\engineering\ussr_t_80b.json" -Raw -Encoding UTF8 | ConvertFrom-Json
[IO.File]::WriteAllText("$fix\ussr_t_80b_he.json", ((Build-He $real) | ConvertTo-Json -Depth 12), (New-Object Text.UTF8Encoding($false)))
$j = Start-Job -ScriptBlock { param($g,$c,$L) & $g --headless --path $c --fixed-fps 60 -s res://tests/probe_cd007_he_admission.gd *> "$L\hadm6.log" } -ArgumentList $g,$c,$L
$d = Wait-Job $j -Timeout 300; if (-not $d) { Stop-Job $j }; Remove-Job $j
$log = Get-Content "$L\hadm6.log" -Encoding UTF8 -ErrorAction SilentlyContinue
"=== diagnostic ==="
$log | Select-String 'CD07 HE diagnostic' | ForEach-Object { "  " + $_.Line.Trim().Substring(0,[Math]::Min(200,$_.Line.Trim().Length)) }
if ([bool]($log | Select-String 'VehicleShellCatalog.build ok=true')) {
  "=== clean, landing ==="
  [IO.File]::WriteAllText("$c\configs\vehicles\engineering\ussr_t_80b.json", ((Build-He $real) | ConvertTo-Json -Depth 12), (New-Object Text.UTF8Encoding($false)))
  $chk = Get-Content "$c\configs\vehicles\engineering\ussr_t_80b.json" -Raw -Encoding UTF8 | ConvertFrom-Json
  "  t80b shells=" + @($chk.shell_catalog.shells).Count + " compatible=" + (($chk.compatible_shells) -join '|') + " default=" + [string]$chk.shell_catalog.default
  foreach ($s in 'run_modern_garage_checks','run_modern_armor_frame_checks','run_shell_checks','run_historical_checks') {
    & $g --headless --path $c --fixed-fps 60 -s ("res://tests/" + $s + ".gd") *> "$L\he8-$s.log"
    $o = Get-Content "$L\he8-$s.log" -ErrorAction SilentlyContinue
    "  {0,-32} exit={1} PASS={2,4} FAIL={3}" -f $s,$LASTEXITCODE,@($o|Select-String '^\[PASS\]').Count,@($o|Select-String '^\[FAIL\]').Count
    @($o|Select-String '^\[FAIL\]') | Select-Object -First 3 | ForEach-Object { "      " + $_.Line.Trim().Substring(0,[Math]::Min(175,$_.Line.Trim().Length)) }
  }
} else { "  still not clean" }
