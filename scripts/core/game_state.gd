extends Node

## Shared runtime state used by the pause/settings menu and future core loop.

signal paused_changed(is_paused: bool)
signal setting_changed(setting_name: StringName, value: Variant)

var is_paused: bool = false
var settings: Dictionary = {
	&"music_enabled": true,
	&"sfx_enabled": true,
	# SCRUM-41 accessibility (see scripts/core/accessibility.gd).
	&"timer_assist": 1.0,
	&"result_cues": true,
	# SCRUM-57: hold the mash key instead of tapping it repeatedly.
	&"mash_hold": false,
}


func _ready() -> void:
	# The pause menu must continue receiving input while the game tree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return
	if event.is_action_pressed(InputActions.ACTION_PAUSE):
		toggle_pause()
		get_viewport().set_input_as_handled()


func pause_game() -> void:
	var changed := not is_paused
	is_paused = true
	get_tree().paused = true
	if changed:
		paused_changed.emit(true)


func resume_game() -> void:
	var changed := is_paused
	is_paused = false
	get_tree().paused = false
	if changed:
		paused_changed.emit(false)


func toggle_pause() -> void:
	if is_paused:
		resume_game()
	else:
		pause_game()


func set_setting(setting_name: StringName, value: Variant) -> void:
	if not settings.has(setting_name):
		push_warning("Unknown game setting: %s" % setting_name)
		return
	if setting_name == &"timer_assist":
		if not (value is float or value is int) or not is_finite(float(value)):
			return
		var nearest := 1.0
		for option: float in Accessibility.TIMER_ASSIST_LEVELS:
			if absf(option - float(value)) < absf(nearest - float(value)):
				nearest = option
		value = nearest
	elif not value is bool:
		return
	if settings[setting_name] == value:
		return
	settings[setting_name] = value
	if setting_name == &"timer_assist":
		Accessibility.refresh_microgame_speed()
	setting_changed.emit(setting_name, value)


func get_setting(setting_name: StringName, fallback: Variant = null) -> Variant:
	return settings.get(setting_name, fallback)
