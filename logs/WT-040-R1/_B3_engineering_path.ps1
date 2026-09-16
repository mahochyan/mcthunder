$c = 'E:\AIprogram\mcthunder-cont'
$enc = New-Object System.Text.UTF8Encoding($false)
function Show($m) { Write-Output $m }
function Patch([string]$rel, [string]$old, [string]$new, [string]$label) {
    $p = Join-Path $c $rel
    $t = [System.IO.File]::ReadAllText($p, [System.Text.Encoding]::UTF8)
    $nl = if ($t.Contains("`r`n")) { "`r`n" } else { "`n" }
    $o = $old.Replace("`n", $nl); $n = $new.TrimEnd("`r","`n").Replace("`n", $nl)
    $cnt = ([regex]::Matches($t, [regex]::Escape($o))).Count
    if ($cnt -eq 1) { [System.IO.File]::WriteAllText($p, $t.Replace($o, $n), $enc); Show ("  OK   " + $label); return $true }
    Show ("  MISS " + $label + " (x" + $cnt + ")"); return $false
}

foreach ($f in @('scripts/content/vehicle_catalog.gd','scripts/garage/garage_service.gd','scripts/battle/team_range.gd','scripts/content/vehicle_readiness.gd')) {
    $g = & git -C $c show ("HEAD:" + $f)
    [System.IO.File]::WriteAllText((Join-Path $c $f), (($g -join "`r`n") + "`r`n"), $enc)
}
Show "restored 4 files from HEAD"

$all = $true

$r = Patch 'scripts/content/vehicle_catalog.gd' `
'const ENGINEERING_DIR := "res://configs/vehicles/engineering/"' @'
const ENGINEERING_DIR := "res://configs/vehicles/engineering/"
## WT-040-R1 (2026-09-17 ruling): the explicit vehicle scope. The curated historical roster keeps its contract,
## the engineering vehicles are a separate admitted set, and the training vehicle is a KNOWN third category that
## keeps its own training configuration. is_combat_vehicle is deliberately history-or-engineering only: the
## garage roster and the historical rotation must not treat the training hull as a combat type.
static func is_historical(id: String) -> bool: return id in IDS
static func is_engineering(id: String) -> bool: return id in ENGINEERING_IDS
static func is_combat_vehicle(id: String) -> bool: return is_historical(id) or is_engineering(id)
static func is_training(id: String) -> bool: return id == "player_tank"
static func is_known_vehicle(id: String) -> bool: return is_combat_vehicle(id) or is_training(id)
'@ 'catalog: scope statics'; $all = $r -and $all

$r = Patch 'scripts/garage/garage_service.gd' `
'	ready = catalog.load_all(definitions).ok' @'
	# WT-040-R1 (2026-09-17 ruling): load_all STAYS historical-only - that contract is asserted elsewhere - and
	# the engineering vehicles are admitted through their own explicit entry point. Both must succeed for the
	# garage to be ready, so the engineering vehicles reach the garage, its loadouts and the match path.
	ready = catalog.load_all(definitions).ok and catalog.load_engineering(definitions).ok
'@ 'garage: explicit engineering load'; $all = $r -and $all

$r = Patch 'scripts/garage/garage_service.gd' `
'	return ready and id in VehicleCatalog.IDS and catalog.packages.get(id,{}).get("ok",false) and definitions.vehicles.has(id)' @'
	# WT-040-R1: the roster is the curated historical set PLUS the explicitly admitted engineering vehicles.
	return ready and VehicleCatalog.is_combat_vehicle(id) and catalog.packages.get(id,{}).get("ok",false) and definitions.vehicles.has(id)
'@ 'garage: has_vehicle scope'; $all = $r -and $all

$r = Patch 'scripts/garage/garage_service.gd' `
'	for id in VehicleCatalog.IDS:
		if has_vehicle(id): ids.append(id)' @'
	# WT-040-R1: curated history first, then the explicitly admitted engineering vehicles, in a stable order.
	for id in VehicleCatalog.IDS + VehicleCatalog.ENGINEERING_IDS:
		if has_vehicle(id): ids.append(id)
'@ 'garage: vehicle_ids scope'; $all = $r -and $all

$r = Patch 'scripts/content/vehicle_readiness.gd' `
'	return "res://configs/vehicles/historical/"+id+".json"' @'
	# WT-040-R1 (2026-09-17 ruling): the ledger could only see historical packets, so an admitted engineering
	# vehicle read as unknown_vehicle and was silently replaced. The engineering directory is now explicit; no
	# gate is widened - the packet still has to pass every downstream check.
	if id in VehicleCatalog.ENGINEERING_IDS: return VehicleCatalog.ENGINEERING_DIR+id+".json"
	return "res://configs/vehicles/historical/"+id+".json"
'@ 'readiness: packet path'; $all = $r -and $all

$r = Patch 'scripts/content/vehicle_readiness.gd' `
'	if mode not in ["training","normal"]: return {"ok":false,"code":"mode_restricted","reason":reason_text("mode_restricted")}
	if ModernModelMountAdapter.SPECS.has(id): return {"ok":false,"code":"preview_only","reason":reason_text("preview_only")}' @'
	if mode not in ["training","normal","engineering"]: return {"ok":false,"code":"mode_restricted","reason":reason_text("mode_restricted")}
	# WT-040-R1 (2026-09-17 ruling): preview_only is about PUBLIC release, not about what the internal engineering
	# battle entry may use. The code is still reported, but it only blocks the public modes; the explicit
	# engineering mode is the controlled internal entry the ruling allows. Nothing is removed and the release
	# gating is unchanged, because every other gate below still applies.
	if ModernModelMountAdapter.SPECS.has(id) and mode != "engineering":
		return {"ok":false,"code":"preview_only","reason":reason_text("preview_only")}
'@ 'readiness: engineering mode'; $all = $r -and $all

$r = Patch 'scripts/content/vehicle_readiness.gd' `
'	var fallback := "training" if mode != "normal" else mode
	for id in VehicleCatalog.IDS:' @'
	var fallback := "training" if mode != "normal" else mode
	# WT-040-R1: the fallback search covers the curated roster, plus the engineering set in the engineering mode,
	# so an internal engineering match can still field a vehicle - and if nothing qualifies the caller refuses.
	var pool: Array = VehicleCatalog.IDS.duplicate()
	if mode == "engineering": pool.append_array(VehicleCatalog.ENGINEERING_IDS)
	for id in pool:
'@ 'readiness: fallback pool'; $all = $r -and $all

$r = Patch 'scripts/battle/team_range.gd' `
'	var size: Vector3 = defs.get_vehicle(type_id).drive_collision_size if type_id in VehicleCatalog.IDS else Vector3(2.85,1.68,5.45)' @'
	# WT-040-R1 (2026-09-17 ruling): an admitted combat vehicle carries its own drive collision size. The
	# hard-coded training box is NOT a silent substitute; a missing definition refuses the spawn and says so.
	if not defs.vehicles.has(type_id):
		push_error("team spawn refused: no admitted definition for vehicle id: "+type_id)
		return null
	var size: Vector3 = defs.get_vehicle(type_id).drive_collision_size
'@ 'team: own collision size'; $all = $r -and $all

$r = Patch 'scripts/battle/team_range.gd' `
'	if selected_vehicle_id not in VehicleCatalog.IDS: return "player_tank"' @'
	# WT-040-R1 (2026-09-17 ruling): a vehicle that is neither curated history, an explicitly admitted engineering
	# vehicle, nor the known training hull is REFUSED. It is never silently replaced by player_tank. The training
	# hull stays known on purpose: it keeps its own training configuration below and is what training flows use.
	if not VehicleCatalog.is_known_vehicle(selected_vehicle_id):
		push_error("team match refused: selected vehicle is not a known vehicle: "+selected_vehicle_id)
		return ""
'@ 'team: refuse unknown selection'; $all = $r -and $all

$r = Patch 'scripts/battle/team_range.gd' `
'		requested = VehicleCatalog.IDS[(ids.find(id)%4+VehicleCatalog.IDS.find(selected_vehicle_id))%4]' @'
		# WT-040-R1: the four-vehicle rotation is a HISTORICAL roster affair. When the player has chosen an
		# engineering vehicle the whole team fields that type instead of being rotated into history.
		if VehicleCatalog.is_historical(selected_vehicle_id):
			requested = VehicleCatalog.IDS[(ids.find(id)%4+VehicleCatalog.IDS.find(selected_vehicle_id))%4]
		else:
			requested = selected_vehicle_id
'@ 'team: no historical rotation for engineering'; $all = $r -and $all

$r = Patch 'scripts/battle/team_range.gd' `
'	var fallback := VehicleReadiness.first_eligible([requested,selected_vehicle_id],"training",{},catalog)
	push_warning("vehicle readiness fallback slot=%s requested=%s code=%s" % [id,requested,checked.code])
	return str(fallback.get("id","player_tank")) if fallback.ok else "player_tank"' @'
	var gate_mode := "engineering" if VehicleCatalog.is_engineering(selected_vehicle_id) else "training"
	var fallback := VehicleReadiness.first_eligible([requested,selected_vehicle_id],gate_mode,{},catalog)
	if fallback.ok:
		push_warning("vehicle readiness fallback slot=%s requested=%s code=%s" % [id,requested,checked.code])
		return str(fallback.get("id",""))
	push_error("team match refused: no admitted combat vehicle for slot %s (requested %s, code %s)" % [id,requested,checked.code])
	return ""
'@ 'team: refuse instead of player_tank'; $all = $r -and $all

$r = Patch 'scripts/battle/team_range.gd' `
'	if vehicle.definition.id not in VehicleCatalog.IDS: M4EngineeringProfile.apply(vehicle)' @'
	# WT-040-R1 (2026-09-17 ruling): the training profile belongs to the training vehicle only. An engineering
	# vehicle keeps its own admitted configuration, and anything that is not a known vehicle is refused rather
	# than quietly given training armour.
	var combat_id := vehicle.definition.id
	if combat_id == "player_tank":
		M4EngineeringProfile.apply(vehicle)
	elif not VehicleCatalog.is_known_vehicle(combat_id):
		push_error("vehicle configuration refused: not a known vehicle: "+combat_id)
		return
'@ 'team: no training profile for engineering'; $all = $r -and $all

$r = Patch 'scripts/battle/team_range.gd' `
'	if vehicle.definition.id not in VehicleCatalog.IDS:
		vehicle.gunner.shell.id = "team_ap120"
		vehicle.gunner.shell.armor_policy = "resolve"
		vehicle.gunner.shell.penetration_curve = PackedVector2Array([Vector2(0,120),Vector2(200,120)])' @'
	# WT-040-R1 (2026-09-17 ruling): the training round, its policy and its flat curve belong to the training
	# vehicle only; an engineering vehicle keeps the round its own admitted loadout installed.
	if combat_id == "player_tank":
		vehicle.gunner.shell.id = "team_ap120"
		vehicle.gunner.shell.armor_policy = "resolve"
		vehicle.gunner.shell.penetration_curve = PackedVector2Array([Vector2(0,120),Vector2(200,120)])
'@ 'team: training round only'; $all = $r -and $all

if (-not $all) { Show "PATCH ANCHORS MISSED - aborting without running anything"; exit 1 }
Show "all 12 patches applied"

$g = 'E:\AIprogram\mcthunder\tools\godot\Godot_v4.7.2-stable_win64_console.exe'
$perrTotal = 0
foreach ($f in @('scripts/content/vehicle_catalog.gd','scripts/garage/garage_service.gd','scripts/battle/team_range.gd','scripts/content/vehicle_readiness.gd')) {
    & $g --headless --path $c --check-only --script ('res://' + $f.Replace('\','/')) *> (Join-Path $c 'logs\WT-040-R1\chkB.log') 2>&1 | Out-Null
    $n = @(Get-Content (Join-Path $c 'logs\WT-040-R1\chkB.log') | Select-String 'Parse Error|Compile Error').Count
    Show ("  parse " + $f + " errors=" + $n); $perrTotal += $n
}
if ($perrTotal -gt 0) { Show "PARSE ERRORS - aborting"; exit 1 }

$lg = Join-Path $c 'logs\WT-040-R1\devtree-player-flow13.log'
Show "guard 1/3: player flow flank checks"
& $g --path $c --resolution 1280x720 -- --verify-player-flow *> $lg
$flank = @(Get-Content $lg | Select-String '^\[PASS\] normal keyboard and mouse session completes flank challenge|^\[PASS\] result backed by actual side penetration').Count
Show ("  flank pass lines=" + $flank)
foreach ($suite in @('run_garage_checks','run_team_checks')) {
    $sl = Join-Path $c ('logs\WT-040-R1\B2-guard-' + $suite + '.log')
    Show ("guard: " + $suite)
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $c 'tests\run_suite_checks.ps1') -Suites $suite *> $sl
    Get-Content $sl | Select-String ($suite + ':') | ForEach-Object { Show ("  " + $_.Line.Trim()) }
}
$garageOk = ((Get-Content (Join-Path $c 'logs\WT-040-R1\B2-guard-run_garage_checks.log') -Raw) -match 'run_garage_checks: checks=\d+[^=]*passed=True')
$teamOk = ((Get-Content (Join-Path $c 'logs\WT-040-R1\B2-guard-run_team_checks.log') -Raw) -match 'run_team_checks: checks=\d+[^=]*passed=True')
Show ("garageOk=" + $garageOk + " teamOk=" + $teamOk + " flank=" + $flank)
if ($flank -lt 2 -or -not $garageOk -or -not $teamOk) { Show "DEV-TREE GUARD FAILED - not committing, not rebuilding"; exit 1 }

git -C $c add scripts tests logs/WT-040-R1
git -C $c -c user.name=mcthunder-agent -c user.email=agent@mcthunder.local commit -m "Make the engineering vehicles reach the same controlled battle path as the historical ones, and refuse only what is genuinely unknown instead of silently substituting a training vehicle. load_all keeps its historical-only contract and GarageService now explicitly calls load_engineering as well, so both sets are ready and the vehicle list, the loadout lookup and the match path all see them. The silent substitutions are removed: an unknown selection is refused rather than becoming player_tank, the four-vehicle rotation applies only to historical selections, an engineering vehicle is not rotated into history, an unadmitted slot refuses instead of falling back to player_tank, the training profile and the team_ap120 round with its policy and flat curve are applied to the training vehicle alone, and a spawn uses the admitted definition's own drive collision size instead of a hard-coded training box. Two more historical-only assumptions were found in the readiness ledger, which is what actually gates the battlefield: it read packets only from the historical directory, so an admitted engineering vehicle came back as unknown_vehicle, and it marked every modern-mounted hull preview_only, which is a PUBLIC release judgement rather than a restriction on the controlled internal engineering entry. The ledger now reads the engineering directory explicitly and gains an explicit engineering mode in which the preview mark is still reported but does not block, while every other gate continues to apply and release gating is untouched. The training hull is a known third category: the first attempt refused it and run_team_checks dropped from 67 checks to 35 with eighteen script errors because no actor could spawn, which the dev-tree guard caught before anything was committed" 2>&1 | Select-Object -First 2
Show ("commits=" + (git -C $c rev-list --count a1bac406..HEAD))
git -C $c push origin work/continuation-20260913 2>&1 | Select-Object -Last 1 | ForEach-Object { Show ("push: " + $_.ToString()) }
git -C $c diff --quiet HEAD; Show ("clean-check exit=" + $LASTEXITCODE)

Show "=== candidate build ==="
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $c 'tests\build_release.ps1') -Candidate
Show ("build exit=" + $LASTEXITCODE)
