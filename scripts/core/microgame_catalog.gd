class_name MicrogameCatalog
extends RefCounted
## Debug catalog and shared introduction metadata. The WeekPlan owns day order.

const ENTRIES: Array[Dictionary] = [
	{"id": "canvas", "title": "Canvas Upload", "day": "Mon / Fri", "scene": "res://scenes/microgames/canvas.tscn", "verb": "UPLOAD!", "icon": "drag", "instruction": "DRAG FILE.ZIP, THEN SUBMIT."},
	{"id": "crossing", "title": "Campus Crossing", "day": "Mon", "scene": "res://scenes/microgames/crossing.tscn", "verb": "CROSS!", "icon": "arrows", "instruction": "DODGE TRAFFIC. REACH THE FLAG."},
	{"id": "schedule", "title": "Schedule Builder", "day": "Tue", "scene": "res://scenes/microgames/schedule_builder.tscn", "verb": "REGISTER!", "icon": "click", "instruction": "WAIT FOR 8:00, THEN REGISTER."},
	{"id": "focus", "title": "Stay Focused", "day": "Wed", "scene": "res://scenes/microgames/stay_focused.tscn", "verb": "BLOCK!", "icon": "arrows_lr", "instruction": "MOVE LEFT / RIGHT TO BLOCK."},
	{"id": "gates", "title": "Logic Gates", "day": "Thu", "scene": "res://scenes/microgames/gates.tscn", "verb": "BUILD!", "icon": "drag", "instruction": "CONNECT THE GATE AND INPUTS."},
	{"id": "scope", "title": "Variable Not in Scope", "day": "Lecture Hall", "scene": "res://scenes/microgames/variable_scope.tscn", "verb": "FIX!", "icon": "click", "instruction": "FIX THE VARIABLE SCOPE ERROR."},
	{"id": "swipe", "title": "Swipe Card", "day": "Rush Hour", "scene": "res://scenes/microgames/swipe_card.tscn", "verb": "SWIPE!", "icon": "drag", "instruction": "FIND YOUR AGGIE CARD, THEN SWIPE!"},
	{"id": "awake", "title": "Stay Awake", "day": "Lecture Hall", "scene": "res://scenes/microgames/stay_awake.tscn", "verb": "POP!", "icon": "click", "instruction": "CLICK EVERY Z BEFORE IT HITS."},
	{"id": "microscope", "title": "Microscope", "day": "Lecture Hall", "scene": "res://scenes/microgames/microscope.tscn", "verb": "FIND!", "icon": "arrows", "instruction": "CENTER THE GOLD AGGIE BACTERIA."},
	{"id": "position_lock", "title": "Position Lock", "day": "Fri", "scene": "res://scenes/microgames/position_lock.tscn", "verb": "LOCK!", "icon": "arrows", "instruction": "MOVE FRAME. HOLD VESSEL INSIDE."},
	{"id": "shield_break", "title": "Shield Break", "day": "Fri", "scene": "res://scenes/microgames/shield_break.tscn", "verb": "FIRE!", "icon": "arrows_lr", "instruction": "AIM AT SHIELD. MASH ACTION."},
]

const DIFFICULTY_NAMES: Array[String] = ["EASY", "NORMAL", "HARD"]
const NativeSession = preload("res://scripts/core/native_microgame_session.gd")
const REQUIRED_SIGNALS: Array[String] = ["round_completed", "time_changed", "result_finished"]
const REQUIRED_METHODS: Array[String] = ["get_round_seconds", "get_round_duration", "get_seconds_left", "get_intro_seconds", "skip_intro", "can_interact", "is_playing", "is_round_finished", "uses_native_hud"]
const REQUIRED_PROPERTIES: Array[String] = ["difficulty", "managed_by_flow", "show_internal_timer", "prompt", "game_title", "instruction_text", "prompt_seconds", "result_seconds", "playback_speed"]


static func find_index(id: String) -> int:
	for index: int in ENTRIES.size():
		if ENTRIES[index]["id"] == id:
			return index
	return -1


static func find_by_scene(scene_path: String) -> Dictionary:
	for entry: Dictionary in ENTRIES:
		if entry["scene"] == scene_path:
			return entry
	return {}


## Accept the common host protocol, or wrap a self-contained native game.
## This also supports native scenes selected through an editable WeekPlan.
static func instantiate(entry: Dictionary, difficulty: int) -> Control:
	var scene_path := str(entry.get("scene", ""))
	if scene_path.is_empty() or not ResourceLoader.exists(scene_path):
		return null
	var packed := load(scene_path) as PackedScene
	if packed == null:
		return null
	var candidate := packed.instantiate()
	if not candidate is Control:
		candidate.free()
		return null
	var microgame: Control = candidate
	if not contract_problems(candidate).is_empty():
		if not native_contract_problems(candidate).is_empty():
			candidate.free()
			return null
		var session := NativeSession.new()
		session.difficulty = clampi(difficulty, 0, 2)
		session.configure(candidate, packed)
		microgame = session
	microgame.set("managed_by_flow", true)
	microgame.set("show_internal_timer", microgame.call("uses_native_hud"))
	microgame.set("difficulty", clampi(difficulty, 0, 2))
	microgame.set("game_title", str(entry.get("title", "Microgame")).to_upper())
	if entry.has("instruction") and not str(entry["instruction"]).is_empty():
		microgame.set("instruction_text", entry["instruction"])
	microgame.set("prompt", entry.get("verb", "PLAY"))
	return microgame


static func contract_problems(microgame: Object) -> Array[String]:
	var problems: Array[String] = []
	if not microgame is Control:
		problems.append("root must extend Control")
	for signal_name: String in REQUIRED_SIGNALS:
		if not microgame.has_signal(signal_name):
			problems.append("missing signal %s" % signal_name)
	for method_name: String in REQUIRED_METHODS:
		if not microgame.has_method(method_name):
			problems.append("missing method %s()" % method_name)
	for property_name: String in REQUIRED_PROPERTIES:
		if not _has_property(microgame, property_name):
			problems.append("missing property %s" % property_name)
	return problems


static func native_contract_problems(microgame: Object) -> Array[String]:
	var problems: Array[String] = []
	for signal_name: String in ["round_completed", "time_changed"]:
		if not microgame.has_signal(signal_name):
			problems.append("missing native signal %s" % signal_name)
	if not microgame.has_method("get_round_seconds"):
		problems.append("missing native method get_round_seconds()")
	for property_name: String in ["difficulty", "show_internal_timer"]:
		if not _has_property(microgame, property_name):
			problems.append("missing native property %s" % property_name)
	return problems


static func _has_property(object: Object, property_name: String) -> bool:
	for property: Dictionary in object.get_property_list():
		if str(property["name"]) == property_name:
			return true
	return false
