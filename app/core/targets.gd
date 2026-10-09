class_name Targets
extends RefCounted
## Targets - the target presets the user can switch on: the researched ones (AppData.presets) and their
## own (Storage.settings.customTargets), all static, reading the autoloads
## what this offers
## - allPresets() -> [{id, name, kind "sport"/"physique"/"custom", summary, offsets, cardio, keyExercises}]
## - getPreset(id) -> one of them or {};  isCustom(id)
## - activeIds() / activePresets() / hasActive() / isActive(id); toggle(id), setActive(ids)
## - baseline() -> the week slider (rangeWeek): every offset is counted from it
## - regionTargets() -> regionId -> weekly sets ({} with nothing on); cardioTargets() -> lightId -> minutes
## - tagsFor(exerciseId) -> names of the active presets that list it as a key exercise
## - saveCustom(target) -> the saved one (new id when it has none); deleteCustom(id) -> the removed one
##   (also switched off); restoreCustom(target, wasActive) puts it back (undo)
## - hasCardio() -> any finished workout logged cardio minutes (the Cardio overlay shows from then on)

### /// TUNING ///

# a new custom target's name and the most characters a name keeps
const newTargetName: String = "My target"
const nameMaxLength: int = 28


### /// THE PRESETS ///

static func allPresets() -> Array:
	# the researched presets first, then the user's own in the order they were made
	var list: Array = AppData.presets.duplicate()
	for target in Storage.settings["customTargets"]:
		list.append(_customPreset(target))
	return list


static func _customPreset(target: Dictionary) -> Dictionary:
	# a custom target in the same shape as a researched preset (no summary, no key exercises)
	return {
		"id": target["id"],
		"name": target["name"],
		"kind": "custom",
		"summary": "",
		"offsets": target["offsets"],
		"cardio": target["cardio"],
		"keyExercises": [],
	}


static func getPreset(presetId: String) -> Dictionary:
	if AppData.presetById.has(presetId):
		return AppData.presetById[presetId]
	for target in Storage.settings["customTargets"]:
		if target["id"] == presetId:
			return _customPreset(target)
	return {}


static func isCustom(presetId: String) -> bool:
	return not AppData.presetById.has(presetId) and not getPreset(presetId).is_empty()


### /// WHICH ARE ON ///

static func activeIds() -> Array:
	# the switched-on ids that still exist, in the order they were switched on
	var ids: Array = []
	for presetId in Storage.settings["activeTargets"]:
		if not getPreset(presetId).is_empty():
			ids.append(presetId)
	return ids


static func activePresets() -> Array:
	var list: Array = []
	for presetId in activeIds():
		list.append(getPreset(presetId))
	return list


static func hasActive() -> bool:
	return activeIds().size() > 0


static func isActive(presetId: String) -> bool:
	return activeIds().has(presetId)


static func toggle(presetId: String) -> void:
	var ids: Array = activeIds()
	if ids.has(presetId):
		ids.erase(presetId)
	else:
		ids.append(presetId)
	setActive(ids)


static func setActive(ids: Array) -> void:
	Storage.setSetting("activeTargets", ids.duplicate())


### /// THE NUMBERS ///

static func baseline() -> float:
	return float(Storage.settings["rangeWeek"])


static func regionTargets() -> Dictionary:
	return HeatEngine.regionTargets(activePresets(), baseline())


static func cardioTargets() -> Dictionary:
	return HeatEngine.cardioTargets(activePresets(), AppData.cardioDefaultTarget)


static func tagsFor(exerciseId: String) -> Array:
	# names of the switched-on presets whose research names this exercise
	var names: Array = []
	for preset in activePresets():
		if preset["keyExercises"].has(exerciseId):
			names.append(str(preset["name"]))
	return names


### /// CUSTOM TARGETS ///

static func saveCustom(target: Dictionary) -> Dictionary:
	### WHAT THIS DOES
	# stores a custom target (replacing the one with its id, or as a new one) and returns it as saved

	var list: Array = Storage.settings["customTargets"].duplicate(true)
	var saved: Dictionary = target.duplicate(true)
	var replaced: bool = false

	if str(saved.get("id", "")) == "":
		saved["id"] = "c%d_%d" % [int(Time.get_unix_time_from_system()), randi() % 1000000]
	saved["name"] = str(saved.get("name", newTargetName)).strip_edges().left(nameMaxLength)
	if saved["name"] == "":
		saved["name"] = newTargetName
	for index in range(list.size()):
		if list[index]["id"] == saved["id"]:
			list[index] = saved
			replaced = true
	if not replaced:
		list.append(saved)
	Storage.setSetting("customTargets", list)
	for stored in Storage.settings["customTargets"]:
		if stored["id"] == saved["id"]:
			return stored
	return saved


static func deleteCustom(presetId: String) -> Dictionary:
	# removes it and switches it off; returns it (empty if there was none) for an undo
	var list: Array = Storage.settings["customTargets"].duplicate(true)
	var removed: Dictionary = {}
	for index in range(list.size()):
		if list[index]["id"] == presetId:
			removed = list[index]
			list.remove_at(index)
			break
	if removed.is_empty():
		return removed
	var ids: Array = activeIds()
	ids.erase(presetId)
	Storage.setSetting("activeTargets", ids)
	Storage.setSetting("customTargets", list)
	return removed


static func restoreCustom(target: Dictionary, wasActive: bool) -> void:
	if target.is_empty() or not getPreset(str(target["id"])).is_empty():
		return
	saveCustom(target)
	if wasActive:
		toggle(str(target["id"]))


### /// CARDIO ///

static func hasCardio() -> bool:
	for workout in Storage.submittedWorkouts():
		for entry in workout["entries"]:
			if int(entry.get("minutes", 0)) > 0:
				return true
	return false
