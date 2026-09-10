class_name TutorialCatalog
extends RefCounted
const COUNT := 10
const LESSONS := [0,0,0,1,3,5,2,6,0,-1]
static func title(chapter: int) -> String: return LocalizationService.text("tutorial_title_%d" % chapter)
static func hint(chapter: int) -> String: return LocalizationService.text("tutorial_hint_%d" % chapter)
static func validate(value: Variant) -> bool:
	if not value is Dictionary or value.size() != 2 or not value.get("chapter") is int or value.chapter < 0 or value.chapter > COUNT or not value.get("completed") is Array: return false
	if value.completed.size() > COUNT: return false
	var seen := {}
	for chapter in value.completed:
		if not chapter is int or chapter < 0 or chapter >= COUNT or seen.has(chapter): return false
		seen[chapter] = true
	return true
