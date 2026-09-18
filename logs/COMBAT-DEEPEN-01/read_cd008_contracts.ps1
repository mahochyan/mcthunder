$c='E:\AIprogram\mcthunder-cont'
'=== damage_resolver.gd : how a crew hit is resolved ==='
@(Select-String -Path "$c\scripts\damage\damage_resolver.gd" -Pattern 'alive|crew|station|role|person|injur|wound|condition|incap' -Encoding UTF8 | Select-Object -First 20) | ForEach-Object { '  L' + $_.LineNumber + ': ' + $_.Line.Trim().Substring(0,[Math]::Min(150,$_.Line.Trim().Length)) }
'=== vehicle_runtime_state.gd : crew fields and identity ==='
@(Select-String -Path "$c\scripts\defs\vehicle_runtime_state.gd" -Pattern 'alive|crew|station|role|person|injur|wound|condition|class Crew|class Station' -Encoding UTF8 | Select-Object -First 22) | ForEach-Object { '  L' + $_.LineNumber + ': ' + $_.Line.Trim().Substring(0,[Math]::Min(150,$_.Line.Trim().Length)) }
'=== vehicle_capabilities.gd : what availability is derived from ==='
@(Select-String -Path "$c\scripts\damage\vehicle_capabilities.gd" -Pattern 'alive|crew|station|role|person|injur|drive|fire|load' -Encoding UTF8 | Select-Object -First 18) | ForEach-Object { '  L' + $_.LineNumber + ': ' + $_.Line.Trim().Substring(0,[Math]::Min(150,$_.Line.Trim().Length)) }
'=== vehicle_recovery.gd : what recovery exists today ==='
@(Select-String -Path "$c\scripts\damage\vehicle_recovery.gd" -Pattern 'alive|crew|station|recover|revive|injur|wound' -Encoding UTF8 | Select-Object -First 18) | ForEach-Object { '  L' + $_.LineNumber + ': ' + $_.Line.Trim().Substring(0,[Math]::Min(150,$_.Line.Trim().Length)) }
