$c='E:\AIprogram\mcthunder-cont'
$p="$c\configs\shells\historical_loadouts.json"
$txt = Get-Content $p -Raw -Encoding UTF8
$anchor = "    }`r`n  },`r`n  `"vehicles`": {"
$entry = @'
    },
    "he_75_m3_eng": {
      "label": "CD07 engineering HE (75-mm M3 only)",
      "gun": "75-mm M3",
      "caliber_mm": 75,
      "effect_policy": "he_blast",
      "muzzle_velocity_mps": 463.0,
      "penetration_curve": [
        [0, 20],
        [500, 20],
        [1000, 20],
        [2000, 20]
      ],
      "source_refs": [
        "mcthunder_pipeline"
      ],
      "compatibility_status": "estimated",
      "muzzle_velocity_status": "game_rule",
      "curve_status": "game_rule",
      "effect_status": "game_rule",
      "historical_observations": "None claimed. This is an explicit CD07 engineering round, not a historical ammunition type, and no historical HE figure is asserted anywhere.",
      "estimate_reason": "WT-CD-007 implementation step two: one explicit engineering HE so the external blast channel can be driven on delivered content. Every number is a project design initial value, the low flat penetration curve exists only so the round stops outside instead of perforating, and the round is bound to the 75-mm M3 gun so only the vehicles carrying that weapon may use it.",
      "post_penetration_profile": {
        "version": "cd006-internal-burst-v1",
        "provenance": "game_rule",
        "reason": "CD07 project design initial value: the fragment channel of this engineering HE, declared through the same extended schema rather than a second one.",
        "count": 5,
        "cone_deg": 50,
        "range_m": 3.0,
        "budget_fraction": 0.20,
        "max_total_mm": 50,
        "min_residual_mm": 4,
        "fragment_impact_profile": {
          "version": "wt012-full-caliber-v1",
          "family": "fragment",
          "provenance": "game_rule",
          "reason": "CD07 project design initial value: the fragment channel's own material response for the engineering HE.",
          "normalization_deg": 0,
          "overmatch_ratio": 0,
          "ricochet_deg": 85,
          "material_coefficients": {"rolled": 1, "cast": 0.95}
        }
      },
      "fuze_policy": {
        "mode": "penetration_delay",
        "arming_thickness_mm": 5.0,
        "delay_s": 0.02,
        "provenance": "game_rule",
        "historical_value": null,
        "ruleset_id": "cd07-he-contact-delay-v1",
        "reason": "CD07 project design initial values for a contact HE with a short delay; no historical fuze figure is claimed."
      },
      "impact_profile": {
        "version": "wt012-full-caliber-v1",
        "family": "APHE",
        "normalization_deg": 2.0,
        "overmatch_ratio": 3.0,
        "ricochet_deg": 75.0,
        "material_coefficients": {"rolled": 1.0, "cast": 0.95},
        "provenance": "game_rule",
        "historical_value": null,
        "reason": "CD07 project design initial value: the engineering HE meets armour with its own game-rule response."
      }
    }
  },
  "vehicles": {
'@
$n = ([regex]::Matches($txt,[regex]::Escape($anchor))).Count
"  anchor_hits=$n"
if ($n -eq 1) { $txt = $txt.Replace($anchor,$entry) }
[IO.File]::WriteAllText($p, $txt, (New-Object Text.UTF8Encoding($false)))
$j = Get-Content $p -Raw -Encoding UTF8 | ConvertFrom-Json
"  json_ok ; shells=" + @($j.shells.PSObject.Properties).Count + " ; new_effect=" + [string]$j.shells.he_75_m3_eng.effect_policy + " ; gun=" + [string]$j.shells.he_75_m3_eng.gun
$g='E:\AIprogram\mcthunder\tools\godot\Godot_v4.7.2-stable_win64_console.exe'
$L="$c\logs\COMBAT-DEEPEN-01"
foreach ($s in 'run_historical_checks','run_shell_checks','run_chemical_content_checks') {
  & $g --headless --path $c --fixed-fps 60 -s ("res://tests/" + $s + ".gd") *> "$L\he2-$s.log"
  $o = Get-Content "$L\he2-$s.log" -ErrorAction SilentlyContinue
  "  {0,-30} exit={1} PASS={2,4} FAIL={3}" -f $s,$LASTEXITCODE,@($o|Select-String '^\[PASS\]').Count,@($o|Select-String '^\[FAIL\]').Count
  @($o|Select-String '^\[FAIL\]') | Select-Object -First 3 | ForEach-Object { "      " + $_.Line.Trim().Substring(0,[Math]::Min(170,$_.Line.Trim().Length)) }
}
