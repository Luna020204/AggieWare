extends Node

## Shared runtime state used by the pause/settings menu and future core loop.

signal paused_changed(is_paused: bool)
signal setting_changed(setting_name: StringName, value: Variant)

var is_paused: bool = false
var settings: Dictionary = {
	&"music_enabled": true,
	&"sfx_enabled": true,
}


func _ready() -> void:
	# The pause menu must continue receiving input while the game tree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return
	if event.is_action_pressed(InputActions.ACTION_PAUSE):
		toggle_pause()
		get_viewport().set_input_as_handled()


func pause_game() -> void:
	if is_paused:
		return
	is_paused = true
	get_tree().paused = true
	paused_changed.emit(true)


func resume_game() -> void:
	if not is_paused:
		return
	is_paused = false
	get_tree().paused = false
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
	if settings[setting_name] == value:
		return
	settings[setting_name] = value
	setting_changed.emit(setting_name, value)


func get_setting(setting_name: StringName, fallback: Variant = null) -> Variant:
	return settings.get(setting_name, fallback)
