$c='E:\AIprogram\mcthunder-cont'
$T=[char]9
$p="$c\scripts\defs\vehicle_runtime_state.gd"
$txt = Get-Content $p -Raw -Encoding UTF8

# (T02) a person identity distinct from the station: every reader already goes through crew_assignments, so this is safe.
$a1 = $T+$T+'crew_states[station.id] = CrewDamageProfile.fresh_person(station.role)' + "`r`n" + `
  $T+$T+'crew_assignments[station.role] = station.id'
$b1 = $T+$T+'# CD08-T02: a person is identified apart from the station they occupy. The role stays the bridge between them, and' + "`r`n" + `
  $T+$T+'# every reader already resolves the person through crew_assignments, so nothing needs to know the new key.' + "`r`n" + `
  $T+$T+'var person_id := CrewDamageProfile.person_id_for(station)' + "`r`n" + `
  $T+$T+'crew_states[person_id] = CrewDamageProfile.fresh_person(station.role)' + "`r`n" + `
  $T+$T+'crew_assignments[station.role] = person_id' + "`r`n" + `
  $T+$T+'station_occupancy[station.id] = person_id'
$n1 = ([regex]::Matches($txt,[regex]::Escape($a1))).Count
$txt = $txt.Replace($a1,$b1)

# (T04) an incapacitated person does not revive within the same life; refusal is named rather than silent.
$a2 = '				crew_states[person] = after.duplicate(true)'
$b2 = $T+$T+$T+'# CD08-T04: an incapacitated person does not come back in this life. Recovery for lesser conditions is a declared' + "`r`n" + `
  $T+$T+$T+'# rule that this version does not have, so raising anyone out of incapacitation is refused by name.' + "`r`n" + `
  $T+$T+$T+'var was_incapacitated := CrewDamageProfile.is_incapacitated(str((crew_states[person] as Dictionary).get("condition","")))' + "`r`n" + `
  $T+$T+$T+'var now_available := bool(after.get("alive",false)) and CrewDamageProfile.is_available(str(after.get("condition",CrewDamageProfile.CONDITION_HEALTHY)))' + "`r`n" + `
  $T+$T+$T+'if was_incapacitated and now_available:' + "`r`n" + `
  $T+$T+$T+$T+'return {"ok":false,"reason":"incapacitated_in_this_life"}' + "`r`n" + `
  $T+$T+$T+'crew_states[person] = after.duplicate(true)'
$n2 = ([regex]::Matches($txt,[regex]::Escape($a2))).Count
$txt = $txt.Replace($a2,$b2)

# (T02 support) the station occupancy map, kept separate from the role bridge
$a3 = 'var station_roles: Dictionary = {}'
$b3 = 'var station_roles: Dictionary = {}' + "`r`n" + `
  '# CD08-T02: station id -> person id, so an occupied or vacated station is readable without confusing the two identities.' + "`r`n" + `
  'var station_occupancy: Dictionary = {}'
$n3 = ([regex]::Matches($txt,[regex]::Escape($a3))).Count
$txt = $txt.Replace($a3,$b3)

$a4 = $T+'station_roles.clear()'
$b4 = $a4 + "`r`n" + $T + 'station_occupancy.clear()'
$n4 = ([regex]::Matches($txt,[regex]::Escape($a4))).Count
$txt = $txt.Replace($a4,$b4)

# expose it in the snapshot too, additively
$a5 = '"assignments":crew_assignments.duplicate(true),"station_roles":station_roles.duplicate(true)}'
$b5 = '"assignments":crew_assignments.duplicate(true),"station_roles":station_roles.duplicate(true),' + "`r`n" + `
  $T+$T+$T+'"station_occupancy":station_occupancy.duplicate(true)}'
$n5 = ([regex]::Matches($txt,[regex]::Escape($a5))).Count
$txt = $txt.Replace($a5,$b5)
[IO.File]::WriteAllText($p, $txt, (New-Object Text.UTF8Encoding($false)))
"  person_id=$n1 ; incap_guard=$n2 ; occupancy_field=$n3 ; occupancy_clear=$n4 ; snapshot=$n5"
