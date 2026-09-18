$c='E:\AIprogram\mcthunder-cont'
"=== revert the tracked files first ==="
git -C $c checkout -- configs/vehicles/engineering/ussr_t_80b.json scripts/armor/armor_impact_profile.gd
"  tracked changes=" + @(git -C $c status --porcelain -- scripts configs | Where-Object { $_ -notmatch '^\?\?' }).Count

"=== build the modified packet and write it to an UNTRACKED fixture path ==="
$fix="$c\assets\vehicles\test_cd007_he_fixture"
New-Item -ItemType Directory -Force -Path $fix | Out-Null
[IO.File]::WriteAllText("$fix\.gdignore", "", (New-Object Text.UTF8Encoding($false)))
$v = Get-Content "$c\configs\vehicles\engineering\ussr_t_80b.json" -Raw -Encoding UTF8 | ConvertFrom-Json
$src = $v.shell_catalog.shells | Where-Object { [string]$_.id -eq 'eng_125_apfsds_v1' } | Select-Object -First 1
$he = $src | ConvertTo-Json -Depth 12 | ConvertFrom-Json
$he.id = "eng_125_he_v1"
$he.label = "125mm engineering HE (project design values)"
$he.family = "HE"
$he.source_bullet_type = "he_tank"
$he.effect_policy = "he_blast"
$he.muzzle_velocity_mps = 700.0
$he.penetration_curve = @(@(0.0,30.0),@(500.0,30.0),@(1500.0,30.0),@(2500.0,30.0))
$impact = [pscustomobject]@{ version="wt012-full-caliber-v1"; family="AP"; normalization_deg=2.0; overmatch_ratio=3.0; ricochet_deg=75.0; material_coefficients=[pscustomobject]@{ rolled=1.0; cast=0.95 }; provenance="game_rule"; historical_value=$null; reason="CD07 project design initial value." }
$he.PSObject.Properties.Remove('impact_profile')
$he | Add-Member -NotePropertyName impact_profile -NotePropertyValue $impact
$he.post_penetration_profile.version = "cd006-internal-burst-v1"
$he.post_penetration_profile.count = 5
$he.post_penetration_profile.cone_deg = 50.0
$he.post_penetration_profile.range_m = 3.0
$he.post_penetration_profile.budget_fraction = 0.20
$he.post_penetration_profile.max_total_mm = 50.0
$he.post_penetration_profile.min_residual_mm = 4.0
$fuze = [pscustomobject]@{ mode="penetration_delay"; arming_thickness_mm=5.0; delay_s=0.02; provenance="game_rule"; historical_value=$null; ruleset_id="cd07-he-contact-delay-v1"; reason="CD07 project design initial value." }
$he | Add-Member -NotePropertyName fuze_policy -NotePropertyValue $fuze
$ev = $he.evidence
$ev.identity.value.id = $he.id; $ev.identity.value.family = "HE"; $ev.identity.value.source_bullet_type = "he_tank"
$ev.effect.value = "he_blast"
$ev.post_penetration.value = $he.post_penetration_profile
$ev.impact.value = $impact
$v.shell_catalog.shells = @($v.shell_catalog.shells) + @($he)
$v.compatible_shells = @($v.compatible_shells) + @($he.id)
$v.id = "test_cd007_he_fixture"
[IO.File]::WriteAllText("$fix\ussr_t_80b_he.json", ($v | ConvertTo-Json -Depth 12), (New-Object Text.UTF8Encoding($false)))
"  fixture written bytes=" + (Get-Item "$fix\ussr_t_80b_he.json").Length
"  fixture is untracked=" + [bool](git -C $c status --porcelain -- "assets/vehicles/test_cd007_he_fixture" | Where-Object { $_ -match '^\?\?' })
