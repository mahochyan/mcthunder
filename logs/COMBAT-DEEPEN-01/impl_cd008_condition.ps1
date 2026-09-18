$c='E:\AIprogram\mcthunder-cont'
$T=[char]9
$p="$c\scripts\defs\vehicle_runtime_state.gd"
$txt = Get-Content $p -Raw -Encoding UTF8

# (1) crew records are created in the versioned vocabulary, with the legacy alive field retained and derived
$a1 = '			crew_states[station.id] = {"alive":true,"original_role":station.role}'
$b1 = '			# CD08: the versioned condition is the readable state; alive is retained and derived so a legacy reader sees' + "`r`n" + `
  $T+$T+$T + '# exactly what it saw before. No penalty is applied by the condition in this version.' + "`r`n" + `
  $T+$T+$T + 'crew_states[station.id] = CrewDamageProfile.fresh_person(station.role)'
$n1 = ([regex]::Matches($txt,[regex]::Escape($a1))).Count
$txt = $txt.Replace($a1,$b1)

# (2) availability reads condition and legacy alive together; the middle conditions do not reduce duty in this version
$a2 = '	return not person.is_empty() and crew_states.has(person) and crew_states[person].get("alive",false)'
$b2 = '	if person.is_empty() or not crew_states.has(person): return false' + "`r`n" + `
  $T + '# CD08: condition and availability are separate. Legacy records without a condition fall back to the boolean, and in' + "`r`n" + `
  $T + '# this version only incapacitation removes a person from duty, so no unconfirmed middle penalty is switched on.' + "`r`n" + `
  $T + 'var person_state: Dictionary = crew_states[person]' + "`r`n" + `
  $T + 'var condition := str(person_state.get("condition",""))' + "`r`n" + `
  $T + 'if condition.is_empty(): return bool(person_state.get("alive",false))' + "`r`n" + `
  $T + 'return bool(person_state.get("alive",false)) and CrewDamageProfile.is_available(condition)'
$n2 = ([regex]::Matches($txt,[regex]::Escape($a2))).Count
$txt = $txt.Replace($a2,$b2)

# (3) a legacy snapshot submitted for migration is handled explicitly, with a named version and a rollback
$a3 = '	var item := str(delta.get("item_id",""))'
$b3 = '	# CD08-T06: a record written before this order migrates under a named version, and the rollback is kept beside it.' + "`r`n" + `
  $T + 'if str(delta.get("kind","")) == "legacy_alive":' + "`r`n" + `
  $T+$T + 'var legacy: Dictionary = delta.get("snapshot",{})' + "`r`n" + `
  $T+$T + 'var people_in: Dictionary = legacy.get("people",{})' + "`r`n" + `
  $T+$T + 'var migrated := CrewDamageProfile.migrate_legacy(people_in)' + "`r`n" + `
  $T+$T + 'crew_states = (migrated.get("people",{}) as Dictionary).duplicate(true)' + "`r`n" + `
  $T+$T + 'if not crew_assignments.is_empty(): pass' + "`r`n" + `
  $T+$T + 'legacy_migration = {"version":migrated.get("version",""),"from_version":migrated.get("from_version",""),' + "`r`n" + `
  $T+$T+$T + '"migrated":migrated.get("migrated",[]),"rollback":CrewDamageProfile.rollback_to_legacy(crew_states)}' + "`r`n" + `
  $T+$T + 'return {"ok":true,"migration_version":str(legacy_migration.get("version","")),' + "`r`n" + `
  $T+$T+$T + '"migrated_entries":(legacy_migration.get("migrated",[]) as Array).size(),"rollback_available":true}' + "`r`n" + `
  $T + 'var item := str(delta.get("item_id",""))'
$n3 = ([regex]::Matches($txt,[regex]::Escape($a3))).Count
$txt = $txt.Replace($a3,$b3)

# (4) a place to keep the migration record
$a4 = 'var death_record: Dictionary = {}'
$b4 = 'var death_record: Dictionary = {}' + "`r`n" + `
  $T + '# CD08-T06: the last legacy migration performed on this instance, with its rollback, so the change is auditable.' + "`r`n" + `
  $T + 'var legacy_migration: Dictionary = {}'
$n4 = ([regex]::Matches($txt,[regex]::Escape($a4))).Count
$txt = $txt.Replace($a4,$b4)
[IO.File]::WriteAllText($p, $txt, (New-Object Text.UTF8Encoding($false)))
"  fresh_person=$n1 role_available=$n2 legacy_branch=$n3 migration_field=$n4"
"  has_condition=" + $txt.Contains('CrewDamageProfile.fresh_person') + " ; migration_recorded=" + $txt.Contains('legacy_migration = {')
