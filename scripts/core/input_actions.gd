extends Node

## Shared input contract for every microgame.
##
## Microgames should use these action names instead of reading raw keys. The
## action map is created defensively at runtime so a freshly imported project
## is usable even before a teammate opens the Input Map editor.

const ACTION_TYPE: StringName = &"game_type"
const ACTION_MASH: StringName = &"game_mash"
const ACTION_UP: StringName = &"game_up"
const ACTION_DOWN: StringName = &"game_down"
const ACTION_LEFT: StringName = &"game_left"
const ACTION_RIGHT: StringName = &"game_right"
const ACTION_CONFIRM: StringName = &"game_confirm"
const ACTION_PAUSE: StringName = &"game_pause"
const ACTION_RETRY: StringName = &"game_retry"

const ACTIONS: Array[StringName] = [
	ACTION_TYPE,
	ACTION_MASH,
	ACTION_UP,
	ACTION_DOWN,
	ACTION_LEFT,
	ACTION_RIGHT,
	ACTION_CONFIRM,
	ACTION_PAUSE,
	ACTION_RETRY,
]

const DEFAULT_KEYS: Dictionary = {
	ACTION_TYPE: [KEY_SPACE, KEY_ENTER],
	ACTION_MASH: [KEY_SPACE, KEY_ENTER],
	ACTION_UP: [KEY_UP, KEY_W],
	ACTION_DOWN: [KEY_DOWN, KEY_S],
	ACTION_LEFT: [KEY_LEFT, KEY_A],
	ACTION_RIGHT: [KEY_RIGHT, KEY_D],
	ACTION_CONFIRM: [KEY_ENTER, KEY_SPACE],
	ACTION_PAUSE: [KEY_ESCAPE],
	ACTION_RETRY: [KEY_R],
}


func _ready() -> void:
	_ensure_default_actions()


func _ensure_default_actions() -> void:
	for action_name: StringName in ACTIONS:
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
		# An existing binding belongs to the project or player. Do not silently
		# re-add WASD/default keys after a teammate has customized the Input Map.
		if not InputMap.action_get_events(action_name).is_empty():
			continue
		for keycode: int in DEFAULT_KEYS[action_name]:
			var event := InputEventKey.new()
			event.physical_keycode = keycode
			InputMap.action_add_event(action_name, event)


func is_pressed(action_name: StringName) -> bool:
	return Input.is_action_pressed(action_name)


func is_just_pressed(action_name: StringName) -> bool:
	return Input.is_action_just_pressed(action_name)


func get_strength(action_name: StringName) -> float:
	return Input.get_action_strength(action_name)


func movement_vector() -> Vector2:
	return Input.get_vector(ACTION_LEFT, ACTION_RIGHT, ACTION_UP, ACTION_DOWN)


func get_action_events(action_name: StringName) -> Array[InputEvent]:
	if not InputMap.has_action(action_name):
		return []
	return InputMap.action_get_events(action_name)


func action_label(action_name: StringName) -> String:
	var events := get_action_events(action_name)
	if events.is_empty():
		return String(action_name)
	return events[0].as_text().replace(" (Physical)", "")


## Hook for SCRUM-57 key remapping. Replacing the events keeps remapping
## centralized instead of making each microgame own a different key map.
func replace_action_events(action_name: StringName, events: Array[InputEvent]) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	InputMap.action_erase_events(action_name)
	for event: InputEvent in events:
		InputMap.action_add_event(action_name, event)


func reset_action(action_name: StringName) -> void:
	if not DEFAULT_KEYS.has(action_name):
		return
	var events: Array[InputEvent] = []
	for keycode: int in DEFAULT_KEYS[action_name]:
		var event := InputEventKey.new()
		event.physical_keycode = keycode
		events.append(event)
	replace_action_events(action_name, events)
