class_name MicrogameCatalog
extends RefCounted

## SCRUM-58: single list of every microgame the test launcher and the hook
## checker know about. Add one line here when you add a microgame.
##
## A microgame scene must follow the contract used by game_flow.gd:
##   - root is a Control
##   - signal round_completed(success: bool)
##   - signal time_changed(seconds_left: float, round_seconds: float)
##   - property `difficulty` (0 = easy, 1 = normal, 2 = hard)
##   - method get_round_seconds() -> float

const ENTRIES: Array[Dictionary] = [
	{"id": "canvas", "title": "Canvas Upload", "day": "Mon / Fri", "scene": "res://scenes/microgames/canvas.tscn"},
	{"id": "schedule", "title": "Schedule Builder", "day": "Tue", "scene": "res://scenes/microgames/schedule_builder.tscn"},
	{"id": "focus", "title": "Stay Focused", "day": "Wed", "scene": "res://scenes/microgames/stay_focused.tscn"},
	{"id": "gates", "title": "Logic Gates", "day": "Thu", "scene": "res://scenes/microgames/gates.tscn"},
	{"id": "scope", "title": "Variable Not in Scope", "day": "Lecture Hall", "scene": "res://scenes/microgames/variable_scope.tscn"},
	{"id": "swipe", "title": "Swipe Card", "day": "Rush Hour", "scene": "res://scenes/microgames/swipe_card.tscn"},
]

const DIFFICULTY_NAMES: Array[String] = ["EASY", "NORMAL", "HARD"]
const REQUIRED_SIGNALS: Array[String] = ["round_completed", "time_changed"]
const REQUIRED_METHODS: Array[String] = ["get_round_seconds"]


static func find_index(id: String) -> int:
	for index: int in ENTRIES.size():
		if ENTRIES[index]["id"] == id:
			return index
	return -1


## Instantiates a microgame ready to be added to the tree. Like game_flow.gd,
## it strips the scene's own pause menu so the host owns a single copy.
static func instantiate(entry: Dictionary, difficulty: int) -> Control:
	var packed := load(entry["scene"]) as PackedScene
	if packed == null:
		return null
	var microgame := packed.instantiate() as Control
	if microgame == null:
		return null
	var local_pause := microgame.get_node_or_null("SettingsPauseMenu")
	if local_pause != null:
		microgame.remove_child(local_pause)
		local_pause.free()
	microgame.set("difficulty", clampi(difficulty, 0, 2))
	return microgame


## Returns a list of human-readable problems; empty means the contract holds.
static func contract_problems(microgame: Object) -> Array[String]:
	var problems: Array[String] = []
	if not microgame is Control:
		problems.append("root is not a Control")
	for signal_name: String in REQUIRED_SIGNALS:
		if not microgame.has_signal(signal_name):
			problems.append("missing signal %s" % signal_name)
	for method_name: String in REQUIRED_METHODS:
		if not microgame.has_method(method_name):
			problems.append("missing method %s()" % method_name)
	if microgame.get("difficulty") == null:
		problems.append("missing property difficulty")
	return problems
