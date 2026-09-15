# WT-040-R1: one reproducible command for the whole modern-vehicle packet pipeline.
#
#   pwsh -File tests/run_modern_vehicle_pipeline.ps1
#
# It measures geometry from the two adapters, VERIFIES that measurement against the source models and
# against invariants, builds the cited facts, crew and modules drafts, and finishes by asking
# VehicleContentPipeline how many gaps remain. The gap count is the acceptance signal: it must never
# rise, and it falls exactly when real data is supplied and wired through.
#
# Nothing here writes into a config, registers a vehicle or admits anything: every output is a draft
# under logs/WT-040-R1/.
# NOTE: no ErrorActionPreference = 'Stop' here on purpose. Godot writes benign warnings to stderr
# (for example about an ignored project.godot under backups/), and PowerShell surfaces native stderr
# as an error record, which would abort the whole pipeline on a warning that is not a failure. The
# verdict is taken from the exit code plus a scan of the log for real SCRIPT ERROR / Parse Error lines.
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$godot = Join-Path $root 'tools\godot\Godot_v4.7.2-stable_win64_console.exe'
if (-not (Test-Path $godot)) {
	# the engine also lives beside the untouched source worktree
	$alt = 'E:\AIprogram\mcthunder\tools\godot\Godot_v4.7.2-stable_win64_console.exe'
	if (Test-Path $alt) { $godot = $alt } else { Write-Error "engine not found"; exit 1 }
}
$logs = Join-Path $root 'logs\WT-040-R1'
New-Item -ItemType Directory -Force -Path $logs | Out-Null
$adapterT = 'res://assets/vehicles/adapters/ussr_t_80b/vehicle_adapter.glb'
$adapterL = 'res://assets/vehicles/adapters/germ_leopard_2a4/vehicle_adapter.glb'
# source models are NOT named here on purpose - see the encoding note below; they come from the dossiers
$dossierT = 'res://assets/reference_data/candidates/ussr_t_80b.json'
$dossierL = 'res://assets/reference_data/candidates/germ_leopard_2a4.json'
$results = @()
function Step([string]$name, [string[]]$argv) {
	$log = Join-Path $logs ("pipeline-" + $name + ".log")
	& $godot @argv *> $log 2>&1
	$code = $LASTEXITCODE
	$scriptErr = (Select-String -Path $log -Pattern 'SCRIPT ERROR|Parse Error' -ErrorAction SilentlyContinue | Measure-Object).Count
	$ok = ($code -eq 0) -and ($scriptErr -eq 0)
	$script:results += [pscustomobject]@{ step = $name; exit = $code; script_errors = $scriptErr; ok = $ok }
	Write-Host ("  {0,-26} exit={1} errors={2} {3}" -f $name, $code, $scriptErr, $(if ($ok) { 'OK' } else { 'FAIL' }))
}
Write-Host "== modern vehicle packet pipeline =="
Step 'import'          @('--headless','--path',$root,'--import')
Step 'geometry'        @('--headless','--path',$root,'-s','res://tests/generate_modern_geometry.gd','--',("ussr_t_80b="+$adapterT),("germ_leopard_2a4="+$adapterL))
# The source models sit in Chinese-named folders outside the project; passing those paths through argv
# proved unreliable from a child process, so they are written to a repo-local UTF-8 file instead.
# NOTE: the source models live in Chinese-named folders outside the project. A Chinese literal in this
# script is NOT safe: Windows PowerShell reads a BOM-less .ps1 as ANSI and mangles it before the engine
# runs, which is exactly what broke the geometry check when the paths were passed from here. The check
# now reads each dossier's own model_candidates.glb_path as UTF-8 JSON instead, so facts must run first.
Step 'facts'           @('--headless','--path',$root,'-s','res://tests/build_modern_facts_draft.gd','--',("ussr_t_80b="+$dossierT),("germ_leopard_2a4="+$dossierL))
Step 'geometry_check'  @('--headless','--path',$root,'-s','res://tests/check_modern_geometry.gd','--','ussr_t_80b','germ_leopard_2a4')
Step 'crew'            @('--headless','--path',$root,'-s','res://tests/build_modern_crew_draft.gd')
Step 'modules'         @('--headless','--path',$root,'-s','res://tests/build_modern_modules_draft.gd')
Step 'armor'           @('--headless','--path',$root,'-s','res://tests/build_modern_armor_draft.gd')
# ORDER MATTERS: the evidence record copies each component, so it must be rebuilt after the component
# drafts change - vehicle_content_pipeline compares the packet against that record.
Step 'evidence'        @('--headless','--path',$root,'-s','res://tests/build_modern_evidence_record.gd')
Step 'gap_audit'       @('--headless','--path',$root,'-s','res://tests/check_modern_package_gaps.gd')
Write-Host "== gap count (the acceptance signal) =="
$audit = Join-Path $logs 'pipeline-gap_audit.log'
Select-String -Path $audit -Pattern '\[gaps\] =====|error count' -ErrorAction SilentlyContinue | ForEach-Object { Write-Host ("  " + $_.Line.Trim()) }
$failed = @($results | Where-Object { -not $_.ok })
Write-Host ("== steps: {0} ok, {1} failed ==" -f (@($results | Where-Object { $_.ok }).Count), $failed.Count)
if ($failed.Count -gt 0) { Write-Host 'MODERN_PIPELINE_FAIL'; exit 1 }
Write-Host 'MODERN_PIPELINE_OK'
