param([Parameter(Mandatory=$true)][string]$BlenderPath,[switch]$Verify)
$ErrorActionPreference='Stop'
$modelRoot=Split-Path -Parent $PSScriptRoot
if(-not (Test-Path -LiteralPath $BlenderPath -PathType Leaf)){throw "Blender executable not found: $BlenderPath"}
$blenderVersion=(& $BlenderPath --version | Select-Object -First 1)
if($blenderVersion -notmatch '5\.2\.1'){throw "Exact reproduction requires Blender 5.2.1; detected: $blenderVersion"}
$builder=Join-Path $modelRoot 'authoring/vehicles/build_textured_lowpoly.py'
& $BlenderPath --background --threads 4 --python-exit-code 1 --python $builder
if($LASTEXITCODE -ne 0){throw "Model generation failed: exit $LASTEXITCODE"}
$reporter=Join-Path $modelRoot 'authoring/vehicles/repro_report.py'
$report=Join-Path $modelRoot 'MODEL_REPRO_REPORT.json'
if($Verify){
    $baseline=Join-Path $modelRoot 'MODEL_BASELINE.json'
    if(-not (Test-Path -LiteralPath $baseline)){throw 'MODEL_BASELINE.json is required for -Verify'}
    & $BlenderPath --background --threads 4 --python-exit-code 1 --python $reporter -- $report $baseline
}else{
    & $BlenderPath --background --threads 4 --python-exit-code 1 --python $reporter -- $report
}
if($LASTEXITCODE -ne 0){throw "Reproduction verification failed: exit $LASTEXITCODE"}
Write-Output "REBUILD_MODELS_PASS: $report"
