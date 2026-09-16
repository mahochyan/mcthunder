$c = 'E:\AIprogram\mcthunder-cont'
$enc = New-Object System.Text.UTF8Encoding($false)
function Patch([string]$rel, $pairs) {
    $p = Join-Path $c $rel
    $t = [System.IO.File]::ReadAllText($p, [System.Text.Encoding]::UTF8)
    Write-Output ("=== " + $rel)
    $total = 0
    foreach ($pair in $pairs) {
        $cnt = ([regex]::Matches($t, [regex]::Escape($pair[0]))).Count
        if ($cnt -gt 0) { $t = $t.Replace($pair[0], $pair[1]); $total += $cnt }
        $label = $pair[0]; if ($label.Length -gt 58) { $label = $label.Substring(0, 58) }
        Write-Output ("  x{0}  {1}" -f $cnt, $label)
    }
    [System.IO.File]::WriteAllText($p, $t, $enc)
    Write-Output ("  total replacements = " + $total)
}

Patch 'tests/build_modern_facts_draft.gd' @(
    @('"value": float(eng["reload_time"]), "status": "design", "origin": rule_note, "source_refs": [],',
      '"value": float(eng["reload_time"]), "status": "design", "origin": "game_rule", "source_refs": ["mcthunder_pipeline"],'),
    @('"value": float(eng["pitch_min"]), "status": "design", "origin": rule_note, "source_refs": [],',
      '"value": float(eng["pitch_min"]), "status": "design", "origin": "game_rule", "source_refs": ["mcthunder_pipeline"],'),
    @('"value": float(eng["pitch_max"]), "status": "design", "origin": rule_note, "source_refs": [],',
      '"value": float(eng["pitch_max"]), "status": "design", "origin": "game_rule", "source_refs": ["mcthunder_pipeline"],'),
    @('"value": eng["penetration_curve"], "status": "design", "origin": rule_note, "source_refs": [],',
      '"value": eng["penetration_curve"], "status": "design", "origin": "game_rule", "source_refs": ["mcthunder_pipeline"],'),
    @('"value": dims[key], "status": dims["status"], "origin": "project engineering measurement/rule %s" % ENG_RULES,',
      '"value": dims[key], "status": "design" if str(dims["status"]) == "design" else "estimated", "origin": "game_rule",'),
    @('"source_refs": [], "location": str(dims["why"]),',
      '"source_refs": ["mcthunder_pipeline"], "location": str(dims["why"]),'),
    @('"status": "reference"', '"status": "estimated"')
)

Patch 'tests/check_modern_package_gaps.gd' @(
    @('			"sources": {},',
      "			""sources"": {""wt-2.57.1.137"": {""origin"":""warthunder_reference"",""title"":""War Thunder reference summary"",""applies_to_identity_ids"":[id]},""mcthunder_pipeline"": {""origin"":""game_rule"",""title"":""mcthunder project pipeline"",""applies_to_identity_ids"":[id]}}," + "`r`n" + "			""admission"": ""engineering_candidate"",")
)
Write-Output '=== done ==='
