class_name NativeMicrogameSession
extends Control
## Hosts an unchanged, self-contained microgame without adding presentation.
## Native games own their clock, input, introduction, HUD, and result artwork.

signal round_completed(success: bool)
signal time_changed(seconds_left: float, round_seconds: float)
signal result_finished

@export_range(0, 2, 1) var difficulty := 0
@export var managed_by_flow := true
@export var show_internal_timer := true
@export var prompt := "PLAY"
@export var game_title := ""
@export var instruction_text := ""
@export var prompt_seconds := 3.2
@export var result_seconds := 1.4
@export var playback_speed := 1.0

var native_game: Control
var _packed: PackedScene
var _native_properties: Dictionary = {}
var _seconds_left := 0.0
var _round_seconds := 0.0
var _ended := false
var _playing_started := false
var _result_left := 0.0
var _result_emitted := false
var _run_token := 0


func _init() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Native controls must not inherit the host's uppercase-only menu font.
	# In Scope, preserving case is part of distinguishing the answer choices.
	var native_theme := ThemeDB.get_default_theme().duplicate() as Theme
	native_theme.default_font = ThemeDB.fallback_font
	native_theme.default_font_size = ThemeDB.fallback_font_size
	theme = native_theme
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR


## Called before the session enters the tree. The session owns the instance.
func configure(candidate: Control, packed: PackedScene) -> void:
	_packed = packed
	_attach_native(candidate)


func _enter_tree() -> void:
	_prepare_native()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var state := get_tree().root.get_node_or_null("GameState")
	if state != null:
		state.paused_changed.connect(_on_pause_changed)
	if prompt_seconds <= 0.0:
		skip_intro()
	_refresh_play_state()


func _process(delta: float) -> void:
	if not is_inside_tree() or get_tree().paused or not is_instance_valid(native_game):
		return
	if _ended:
		if not _result_emitted:
			_result_left = maxf(0.0, _result_left - maxf(delta, 0.0))
			# The native overlay runs independently, including after its game ends.
			# Wait for its actual fade, not merely an assumed host delay.
			if _result_left <= 0.0 and _native_pop_remaining() <= 0.0:
				_result_emitted = true
				result_finished.emit()
		return
	_refresh_play_state()


func _unhandled_key_input(event: InputEvent) -> void:
	if managed_by_flow or get_tree().paused or (event is InputEventKey and event.echo):
		return
	if event.is_action_pressed(InputActions.ACTION_RETRY):
		restart_round()
		get_viewport().set_input_as_handled()


func restart_round() -> void:
	Accessibility.end_microgame(self)
	_discard_native()
	_ended = false
	_playing_started = false
	_result_emitted = false
	_result_left = 0.0
	if _packed == null:
		return
	_attach_native(_packed.instantiate() as Control)
	if prompt_seconds <= 0.0:
		skip_intro()
	_refresh_play_state()


func _attach_native(candidate: Control) -> void:
	native_game = candidate
	_native_properties.clear()
	for property: Dictionary in native_game.get_property_list():
		_native_properties[StringName(property["name"])] = true
	_prepare_native()
	_round_seconds = float(native_game.call("get_round_seconds"))
	_seconds_left = _round_seconds
	native_game.connect("time_changed", _on_native_time_changed.bind(_run_token))
	native_game.connect("round_completed", _on_native_completed.bind(_run_token))
	add_child(native_game)


func _prepare_native() -> void:
	if not is_instance_valid(native_game):
		return
	native_game.set("difficulty", clampi(difficulty, 0, 2))
	# Native layout and timer stay intact. The collection HUD is hidden instead.
	native_game.set("show_internal_timer", true)
	# Delay menu removal until entry so hosts can finish configuring the session.
	# The parent's _enter_tree runs before any native child receives _ready.
	if managed_by_flow and is_inside_tree():
		_remove_embedded_pause_menus(native_game)


func _remove_embedded_pause_menus(parent: Node) -> void:
	for child: Node in parent.get_children():
		var script: Script = child.get_script()
		if script != null and script.resource_path == "res://scripts/ui/settings_pause_menu.gd":
			parent.remove_child(child)
			child.queue_free()
		else:
			_remove_embedded_pause_menus(child)


func _on_native_time_changed(seconds_left: float, round_seconds: float, token: int) -> void:
	if token != _run_token or _ended:
		return
	_seconds_left = maxf(seconds_left, 0.0)
	_round_seconds = round_seconds
	_refresh_play_state()
	time_changed.emit(_seconds_left, _round_seconds)


func _on_native_completed(success: bool, token: int) -> void:
	if token != _run_token or _ended:
		return
	_ended = true
	_result_left = maxf(result_seconds, 1.4)
	Accessibility.end_microgame(self)
	round_completed.emit(success)


func _refresh_play_state() -> void:
	if _ended or _playing_started or not is_inside_tree() or not is_instance_valid(native_game):
		return
	if native_game.is_inside_tree() and _native_intro_remaining() <= 0.0:
		_playing_started = true
		Accessibility.begin_microgame(playback_speed, self)


## These few native implementation details are isolated here, never in hosts.
func _read_native(property_name: StringName, fallback: Variant = null) -> Variant:
	if not is_instance_valid(native_game) or not _native_properties.has(property_name):
		return fallback
	return native_game.get(property_name)


func _native_intro_remaining() -> float:
	return maxf(float(_read_native(&"_intro_left", 0.0)), 0.0)


func _native_pop_remaining() -> float:
	var overlay := _native_message_overlay()
	if overlay == null:
		return 0.0
	var remaining: Variant = overlay.get("_pop_left")
	return maxf(float(remaining), 0.0) if remaining is float or remaining is int else 0.0


func _native_message_overlay() -> Control:
	var overlay: Variant = _read_native(&"_overlay")
	# Microscope also has an _overlay, but it is its eyepiece, not a message.
	if not is_instance_valid(overlay) or not overlay.has_method("clear_pop") or not overlay.has_method("pop"):
		return null
	return overlay as Control


## Deterministic debug stepping; disable automatic processing on the session,
## native game, and its message overlay before using this instead of frames.
func tick_native(delta: float) -> void:
	if not is_inside_tree() or get_tree().paused or not is_instance_valid(native_game):
		return
	_process(delta)
	if not is_inside_tree() or not is_instance_valid(native_game):
		return
	if native_game.has_method("_process"):
		native_game.call("_process", delta)
	var overlay := _native_message_overlay()
	if overlay != null:
		overlay.call("_process", delta)
	_refresh_play_state()


func _on_pause_changed(paused: bool) -> void:
	if paused and not _ended and bool(_read_native(&"_dragging", false)) and native_game.has_method("_reset_card"):
		# A released mouse while paused must not leave a timed swipe in progress.
		native_game.call("_reset_card")


func skip_intro() -> void:
	if not is_inside_tree() or get_tree().paused or _ended:
		return
	if is_instance_valid(native_game) and native_game.has_method("skip_intro"):
		native_game.call("skip_intro")
	_refresh_play_state()


func get_intro_seconds() -> float:
	if prompt_seconds <= 0.0 or not is_instance_valid(native_game) or not native_game.has_method("get_intro_seconds"):
		return 0.0
	return float(native_game.call("get_intro_seconds"))


func get_round_seconds() -> float:
	if is_instance_valid(native_game) and not native_game.is_inside_tree():
		native_game.set("difficulty", clampi(difficulty, 0, 2))
	return float(native_game.call("get_round_seconds")) if is_instance_valid(native_game) else _round_seconds


func get_round_duration() -> float:
	return _round_seconds


func get_seconds_left() -> float:
	return _seconds_left


func is_round_finished() -> bool:
	return _ended


func is_playing() -> bool:
	return _playing_started and not _ended


func uses_native_hud() -> bool:
	return true


func can_interact() -> bool:
	return is_inside_tree() and not get_tree().paused and is_playing() and _seconds_left > 0.0


func _discard_native() -> void:
	_run_token += 1
	if is_instance_valid(native_game):
		remove_child(native_game)
		native_game.queue_free()
	native_game = null


func _exit_tree() -> void:
	_run_token += 1
	Accessibility.end_microgame(self)
