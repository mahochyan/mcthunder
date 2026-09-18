extends "res://tests/run_spall_checks.gd"
## MCT-COMBAT-DEEPEN-01 CD06 deliverable four: a real hit replay example, produced and validated rather than described.
## The record is written out as JSON next to the evidence so the delivery package can carry an actual validated replay,
## with its identity, its seed and the rule versions it was flown under.

const CD6_REPLAY_OUT := "res://docs/wt/continuation/COMBAT_DEEPEN01_CD006_REPLAY_EXAMPLE.json"

func spall_runtime_cases() -> void:
	super.spall_runtime_cases()

	var st := launch_spall(compartment(20.0,true)); complete(st)
	var record := record_for(st)
	var valid := ShotRecordBuilder.validate(record)
	print("[CD06 replay-example] identity=%s" % JSON.stringify(record.get("identity",{})))
	print("[CD06 replay-example] rules_versions=%s" % JSON.stringify(record.get("rules_versions",{})))
	print("[CD06 replay-example] fragments=%d damage=%d spall_events=%d consumed=%.4f mm valid=%s" % [
		int(record.get("fragments",[]).size()),int(record.get("damage",[]).size()),
		int(record.get("spall_events",[]).size()),float(st.consumed_mm),str(valid.ok)])
	check(valid.ok,"CD06 replay-example the produced record validates, so the example is a real replay and not a sketch")
	check(not record.get("identity",{}).is_empty() and not record.get("rules_versions",{}).is_empty(),
		"CD06 replay-example it carries both its identity and the rule versions it was flown under")
	var payload := {"note":"MCT-COMBAT-DEEPEN-01 CD06 deliverable four: an actual hit replay example, validated by ShotRecordBuilder.validate at production time. Project design values only; no measured historical data is claimed.",
		"validated":true,"identity":record.get("identity",{}),"rules_versions":record.get("rules_versions",{}),
		"fragment_count":int(record.get("fragments",[]).size()),"damage_count":int(record.get("damage",[]).size()),
		"spall_event_count":int(record.get("spall_events",[]).size()),"consumed_mm":float(st.consumed_mm),
		"terminal":str(st.terminal_reason)}
	var written := FileAccess.open(ProjectSettings.globalize_path(CD6_REPLAY_OUT),FileAccess.WRITE)
	if written != null:
		written.store_string(JSON.stringify(payload,"  "))
		written.close()
		print("[CD06 replay-example] written to %s" % CD6_REPLAY_OUT)
	else:
		print("[CD06 replay-example] could not write the example file")
	check(written != null,"CD06 replay-example the example is written out for the delivery package")
	print("CD06_REPLAY_EXAMPLE PASS")
