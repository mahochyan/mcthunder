param([string]$Tag=(Get-Date -Format 'yyyyMMdd-HHmmss'))
$ErrorActionPreference='Stop'
if($Tag -notmatch '^[A-Za-z0-9_-]+$'){throw 'Tag may contain only letters, numbers, underscores and hyphens'}
$modelRoot=Split-Path -Parent $PSScriptRoot
$bundle=Join-Path $modelRoot "deliverables/tank-model-workflow-$Tag"
if(Test-Path -LiteralPath $bundle){throw "Use a new tag; destination already exists: $bundle"}
New-Item -ItemType Directory -Path $bundle -Force | Out-Null
$fixed=@('authoring/REBUILD_MODELS.ps1','authoring/vehicles/build_textured_lowpoly.py','authoring/vehicles/style_metadata.py','authoring/vehicles/repro_report.py','authoring/vehicles/export_current.py','authoring/vehicles/README.md','authoring/poly_budget/build_preview.py','authoring/poly_budget/texture_preview.py','authoring/poly_budget/ATLAS_PROMPT.txt','assets/art_palette.json','assets/vehicles/textures/vehicle_concept_atlas_v1.png')
$models=@('us_m4a3_75w_vvss_1944','us_m24_m6_t85e1_1951','us_m26_m3_1945','us_m36_m4a1_1945')
foreach($id in $models){$fixed+=@("authoring/vehicles/seeds/$id.json","authoring/vehicles/$id.blend","assets/vehicles/$id.glb","assets/vehicles/$id.manifest.json")}
foreach($relative in $fixed){
    $target=Join-Path $bundle $relative
    New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $modelRoot $relative) -Destination $target
}
Copy-Item -LiteralPath (Join-Path $modelRoot 'docs/TANK_MODEL_WORKFLOW.md') -Destination (Join-Path $bundle 'README.md')
Copy-Item -LiteralPath (Join-Path $modelRoot 'authoring/vehicles/MODEL_BASELINE.json') -Destination (Join-Path $bundle 'MODEL_BASELINE.json')
$integration=@('scripts/content/historical_vehicle_model.gd','scripts/art/vehicle_atlas.gd','scripts/art/historical_track_motion.gd','assets/shaders/vehicle_tracks.gdshader','scripts/art/geometry_overlay.gd','scripts/art/asset_budget_report.gd','tests/run_blender_asset_checks.gd','tests/run_art_checks.gd')
foreach($relative in $integration){
    $target=Join-Path $bundle "integration_reference/$relative"
    New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $modelRoot $relative) -Destination $target
}
$reference=Join-Path $bundle 'reference'
New-Item -ItemType Directory -Path $reference -Force | Out-Null
foreach($file in @('ChatGPT Image 2026年9月9日 11_14_01 (1).png','ChatGPT Image 2026年9月9日 11_14_02 (2).png','ChatGPT Image 2026年9月9日 11_14_03 (3).png','ChatGPT Image 2026年9月9日 11_14_04 (4).png')){
    $source=Join-Path 'C:/Users/lapyin/Downloads' $file
    if(Test-Path -LiteralPath $source){Copy-Item -LiteralPath $source -Destination $reference}
}
foreach($view in @('hero','side','rear')){
    Copy-Item -LiteralPath (Join-Path $modelRoot "authoring/poly_budget/textured/m4_textured_$view.png") -Destination (Join-Path $reference "M4_design_preview_1051_triangles_$view.png")
}
$files=@(Get-ChildItem -LiteralPath $bundle -File -Recurse | Sort-Object FullName | ForEach-Object {
    [ordered]@{path=[IO.Path]::GetRelativePath($bundle,$_.FullName).Replace('\','/');bytes=$_.Length;sha256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()}
})
[ordered]@{bundle='tank-model-workflow';version='1.0';source_sha=(& git -C $modelRoot rev-parse HEAD).Trim();source_has_uncommitted_changes=[bool](& git -C $modelRoot status --porcelain --untracked-files=no);files=$files} | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $bundle 'PACKAGE_FILES.json') -Encoding utf8
Write-Output "MODEL_WORKFLOW_FOLDER=$bundle"
