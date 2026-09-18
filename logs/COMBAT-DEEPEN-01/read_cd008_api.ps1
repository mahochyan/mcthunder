$c='E:\AIprogram\mcthunder-cont'
'=== CrewRoster: assign and friends (relief entry point) ==='
@(Get-ChildItem "$c\scripts" -Recurse -File -Filter '*crew_roster*.gd' | ForEach-Object { $_.FullName }) | ForEach-Object { '  file: ' + $_ }
$cr = @(Get-ChildItem "$c\scripts" -Recurse -File -Filter '*crew_roster*.gd' | Select-Object -First 1)
if ($cr) { Select-String -Path $cr.FullName -Pattern 'static func|func ' -Encoding UTF8 | ForEach-Object { '  L' + $_.LineNumber + ': ' + $_.Line.Trim().Substring(0,[Math]::Min(130,$_.Line.Trim().Length)) } }
'=== VehicleRuntimeState public crew API ==='
@(Select-String -Path "$c\scripts\defs\vehicle_runtime_state.gd" -Pattern '^func |^static func ' -Encoding UTF8) | ForEach-Object { '  L' + $_.LineNumber + ': ' + $_.Line.Trim().Substring(0,[Math]::Min(130,$_.Line.Trim().Length)) }
'=== how a crew hit is submitted (damage commit path) ==='
@(Select-String -Path "$c\scripts\damage\damage_resolver.gd" -Pattern '^static func |^func |kind == "crew"|station_roles|people' -Encoding UTF8) | ForEach-Object { '  L' + $_.LineNumber + ': ' + $_.Line.Trim().Substring(0,[Math]::Min(140,$_.Line.Trim().Length)) }
'=== who commits the resolver result into state ==='
@(git -C $c grep -rn 'DamageResolver.next_contact\|commit_damage_event\|_commit_damage_event' -- scripts/damage scripts/projectiles 2>&1 | Select-Object -First 8) | ForEach-Object { '  ' + ("$_").Substring(0,[Math]::Min(170,("$_").Length)) }