class_name CrewRoster
extends RefCounted
## Assignment maps station role -> person id. One person occupies at most one role.
static func assign(assignments: Dictionary, people: Dictionary, role: String, person_id: String) -> Dictionary:
	if not assignments.has(role) or not people.has(person_id) or not people[person_id].get("alive",false):
		return {"ok":false,"reason":"invalid_or_incapacitated"}
	var next := assignments.duplicate(true)
	for key in next:
		if next[key] == person_id:
			next[key] = ""
	next[role] = person_id
	return {"ok":true,"assignments":next}
