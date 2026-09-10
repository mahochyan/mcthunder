class_name ShotRecordStore
extends RefCounted
const LIMIT := 16
var _records: Array[Dictionary] = []

func push_bounded(record: Dictionary) -> Dictionary:
	var valid := ShotRecordBuilder.validate(record)
	if not valid.ok: return valid
	var encoded := ShotRecordCodec.encode(record)
	if not encoded.ok: return encoded
	var frozen := record.duplicate(true)
	ShotRecordBuilder.freeze_containers(frozen)
	_records.append(frozen)
	if _records.size()>LIMIT: _records.pop_front()
	return {"ok":true}

func count() -> int:
	return _records.size()

func get_record(index: int) -> Dictionary:
	if index<0 or index>=_records.size(): return {}
	return _records[index].duplicate(true)

func latest_replayable_index() -> int:
	# A valid terminal record can describe a miss without any target geometry.
	# Such records remain useful evidence, but ReplayView cannot display them.
	for index in range(_records.size()-1,-1,-1):
		var record: Dictionary=_records[index]
		if record.get("complete",false) and not record.get("frames",[]).is_empty(): return index
	return -1

func clear() -> void:
	_records.clear()
