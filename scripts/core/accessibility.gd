class_name Accessibility
extends RefCounted

## SCRUM-41: accessibility options shared by the week flow and the launcher.
##
## The values live in GameState.settings (so the pause/settings menu edits
## them and SCRUM-57 saves them):
##   timer_assist    1.0 / 1.25 / 1.5: how much longer each microgame lasts.
##                   Applied by slowing game time while a microgame runs, so it
##                   works for every microgame without changing their code.
##   result_cues     Show a large shape + word result banner (✔ CLEAR /
##                   ✖ MISS) and a ⚠ on the low-time HUD timer, so results
##                   never depend on red/green alone.

const TIMER_ASSIST_LEVELS: Array[float] = [1.0, 1.25, 1.5]
const TIMER_ASSIST_NAMES: Array[String] = ["Off", "+25% time", "+50% time"]


static func timer_assist() -> float:
	var value := float(_setting(&"timer_assist", 1.0))
	return clampf(value, 1.0, 2.0)


static func result_cues_enabled() -> bool:
	return bool(_setting(&"result_cues", true))


## Looks the GameState autoload up at runtime so this helper also compiles
## in headless --script tools, where autoload names are not identifiers.
static func _setting(setting_name: StringName, fallback: Variant) -> Variant:
	var tree := Engine.get_main_loop() as SceneTree
	var state: Node = tree.root.get_node_or_null("GameState") if tree != null else null
	if state == null:
		return fallback
	return state.call("get_setting", setting_name, fallback)


## Game speed to use while a microgame is running.
static func microgame_time_scale(base_speed: float = 1.0) -> float:
	return base_speed / timer_assist()


static func begin_microgame(base_speed: float = 1.0) -> void:
	Engine.time_scale = microgame_time_scale(base_speed)


static func end_microgame() -> void:
	Engine.time_scale = 1.0
