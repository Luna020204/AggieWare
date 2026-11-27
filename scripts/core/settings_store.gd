extends Node

## SCRUM-57: saves and restores player options between sessions.
##
## Autoload (after InputActions and GameState). Stores GameState.settings and
## any rebound keys in user://settings.cfg. The pause/settings menu calls
## rebind() / reset_bindings(); GameState.setting_changed triggers a save.

signal bindings_changed

## Actions the player may rebind (pause stays on Escape so it can't be lost).
const REBINDABLE: Array[StringName] = [
	&"game_up", &"game_down", &"game_left", &"game_right",
	&"game_confirm", &"game_type", &"game_mash",
	&"game_retry",
]
const ACTION_LABELS: Dictionary = {
	&"game_up": "Up", &"game_down": "Down", &"game_left": "Left", &"game_right": "Right",
	&"game_confirm": "Action / confirm", &"game_type": "Type", &"game_mash": "Mash",
	&"game_retry": "Retry standalone game",
}

var path := "user://settings.cfg"
var _loading := false
var highest_unlocked_day := 0


func _ready() -> void:
	# Headless --script tools (smoke tests, CI) must not read or overwrite the
	# player's real settings; tests that need a file set `path` themselves.
	if OS.get_cmdline_args().has("--script") or OS.get_cmdline_args().has("-s"):
		path = ""
	load_settings()
	GameState.setting_changed.connect(func(_name: StringName, _value: Variant) -> void: save_settings())


## Replaces the keyboard binding of `action` with `event` and saves.
func rebind(action: StringName, event: InputEventKey) -> void:
	if not REBINDABLE.has(action):
		return
	var key := InputEventKey.new()
	key.physical_keycode = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
	if key.physical_keycode == KEY_NONE or key.physical_keycode == KEY_ESCAPE:
		return
	var events: Array[InputEvent] = [key]
	InputActions.replace_action_events(action, events)
	bindings_changed.emit()
	save_settings()


func reset_bindings() -> void:
	for action: StringName in REBINDABLE:
		InputActions.reset_action(action)
	bindings_changed.emit()
	save_settings()


## Human-readable key list for an action, e.g. "W / Up".
func describe(action: StringName) -> String:
	var names: Array[String] = []
	for event: InputEvent in InputActions.get_action_events(action):
		if event is InputEventKey:
			var code: int = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
			names.append(OS.get_keycode_string(code))
	return " / ".join(names) if not names.is_empty() else "—"


## Other rebindable actions already using the same key (for a warning).
func conflicts(action: StringName, event: InputEventKey) -> Array[String]:
	var found: Array[String] = []
	var code := event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
	for other: StringName in REBINDABLE:
		if other == action:
			continue
		for existing: InputEvent in InputActions.get_action_events(other):
			if existing is InputEventKey:
				var existing_code: int = existing.physical_keycode if existing.physical_keycode != KEY_NONE else existing.keycode
				if existing_code == code:
					found.append(ACTION_LABELS[other])
					break
	return found


func unlock_day(day: int) -> void:
	if day > highest_unlocked_day:
		highest_unlocked_day = day
		save_settings()


func save_settings() -> void:
	if _loading or path == "":
		return
	var config := ConfigFile.new()
	config.set_value("week", "highest_unlocked_day", highest_unlocked_day)
	for setting_name: StringName in GameState.settings:
		config.set_value("settings", String(setting_name), GameState.settings[setting_name])
	for action: StringName in REBINDABLE:
		var codes: Array[int] = []
		for event: InputEvent in InputActions.get_action_events(action):
			if event is InputEventKey:
				codes.append(event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode)
		config.set_value("bindings", String(action), codes)
	var error := config.save(path)
	if error != OK:
		push_warning("Could not save settings to %s (%s)" % [path, error_string(error)])


func load_settings() -> void:
	var config := ConfigFile.new()
	if path == "" or config.load(path) != OK:
		return
	var saved_day: Variant = config.get_value("week", "highest_unlocked_day", 0)
	highest_unlocked_day = maxi(0, saved_day) if saved_day is int else 0
	_loading = true
	for key: String in config.get_section_keys("settings") if config.has_section("settings") else PackedStringArray():
		var setting_name := StringName(key)
		if GameState.settings.has(setting_name):
			GameState.set_setting(setting_name, config.get_value("settings", key))
	if config.has_section("bindings"):
		for action: StringName in REBINDABLE:
			var codes: Variant = config.get_value("bindings", String(action), [])
			if not (codes is Array or codes is PackedInt32Array or codes is PackedInt64Array):
				continue
			var events: Array[InputEvent] = []
			var seen: Array[int] = []
			for code: Variant in codes:
				if not code is int or code <= KEY_NONE or code == KEY_ESCAPE or seen.has(code):
					continue
				var key := InputEventKey.new()
				key.physical_keycode = code
				events.append(key)
				seen.append(code)
			if not events.is_empty():
				InputActions.replace_action_events(action, events)
	_loading = false
	bindings_changed.emit()
