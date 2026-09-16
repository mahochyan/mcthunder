$ErrorActionPreference='Continue'
$c='E:\AIprogram\mcthunder-cont'; $g='E:\AIprogram\mcthunder\tools\godot\Godot_v4.7.2-stable_win64_console.exe'; $dir='E:\AIprogram\mcthunder-cont\logs\WT-040-R1\final-acceptance-20260916-113742'
"=== [1/3] 一条命令流水线（9 步 ✓）===" | Tee-Object -FilePath "$dir\acceptance.log" -Append
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$c\tests\run_modern_vehicle_pipeline.ps1" *>> "$dir\pipeline.log"
"[pipeline] exit=$LASTEXITCODE" | Tee-Object -FilePath "$dir\acceptance.log" -Append
Get-Content "$dir\pipeline.log" | Select-String 'exit=|error count|steps:|MODERN_PIPELINE' | ForEach-Object { $_.Line.Trim() } | Tee-Object -FilePath "$dir\acceptance.log" -Append
"=== [2/3] 几何自校验（应 29/29 ✓）===" | Tee-Object -FilePath "$dir\acceptance.log" -Append
& $g --headless --path $c --fixed-fps 60 -s res://tests/check_modern_geometry.gd -- ussr_t_80b=res://assets/vehicles/adapters/ussr_t_80b/vehicle_adapter.glb germ_leopard_2a4=res://assets/vehicles/adapters/germ_leopard_2a4/vehicle_adapter.glb *> "$dir\geometry_check.log"
"[geometry_check] exit=$LASTEXITCODE" | Tee-Object -FilePath "$dir\acceptance.log" -Append
Get-Content "$dir\geometry_check.log" | Select-String '结果:|MODERN_GEOMETRY' | ForEach-Object { $_.Line.Trim() } | Tee-Object -FilePath "$dir\acceptance.log" -Append
"=== [3/3] 层级探针（LayoutValidator / definitions ✓）===" | Tee-Object -FilePath "$dir\acceptance.log" -Append
& $g --headless --path $c --fixed-fps 60 -s res://tests/probe_package_layers.gd *> "$dir\layer_probe.log"
"[layer_probe] exit=$LASTEXITCODE" | Tee-Object -FilePath "$dir\acceptance.log" -Append
Get-Content "$dir\layer_probe.log" | Select-String 'geometry.build|LayoutValidator|VehicleShellCatalog|definition ' | ForEach-Object { $_.Line.Trim() } | Tee-Object -FilePath "$dir\acceptance.log" -Append
"=== DONE ===" | Tee-Object -FilePath "$dir\acceptance.log" -Append
