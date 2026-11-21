class_name MicrogameBase
extends Control
## Shared lifecycle for hosted microgames and independent F6 playtests.
## A game implements the hooks below; the host owns score, lives, and navigation.

signal round_completed(success: bool)
signal time_changed(seconds_left: float, round_seconds: float)

@export_range(0, 2, 1) var difficulty := 0
@export var managed_by_flow := false
@export var show_internal_timer := true
@export var prompt := "PLAY"
@export_range(0.0, 3.0, 0.05) var prompt_seconds := 0.65
@export_range(0.0, 120.0, 0.1) var duration_override := 0.0

var _seconds_left := 0.0
var _round_seconds := 0.0
var _ended := false
var _prompt_left := 0.0
var _prompt_layer: CanvasLayer
var _prompt_cover: ColorRect
var _prompt_label: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	difficulty = clampi(difficulty, 0, 2)
	_build_ui()
	_build_prompt()
	if not managed_by_flow:
		var pause_scene: PackedScene = load("res://scenes/ui/settings_pause_menu.tscn")
		add_child(pause_scene.instantiate())
	_start_round()

func _process(delta: float) -> void:
	if _ended or not is_inside_tree() or get_tree().paused:
		return
	if _prompt_left > 0.0:
		_prompt_left = maxf(0.0, _prompt_left - delta)
		_prompt_layer.visible = _prompt_left > 0.0
		return
	var active_delta := minf(maxf(delta, 0.0), _seconds_left)
	_seconds_left = maxf(0.0, _seconds_left - active_delta)
	time_changed.emit(_seconds_left, _round_seconds)
	_update_game(active_delta)
	if not _ended and _seconds_left <= 0.0:
		_on_timeout()

func _unhandled_key_input(event: InputEvent) -> void:
	if managed_by_flow or get_tree().paused or (event is InputEventKey and event.echo):
		return
	if event.is_action_pressed(InputActions.ACTION_RETRY):
		_start_round()
		get_viewport().set_input_as_handled()

func _start_round() -> void:
	difficulty = clampi(difficulty, 0, 2)
	_round_seconds = duration_override if duration_override > 0.0 else get_round_seconds()
	_round_seconds = maxf(_round_seconds, 0.01)
	_seconds_left = _round_seconds
	_ended = false
	_prompt_left = maxf(prompt_seconds, 0.0)
	_reset_game()
	_prompt_label.text = prompt
	_prompt_layer.visible = not _ended and _prompt_left > 0.0
	time_changed.emit(_seconds_left, _round_seconds)

func _finish_round(success: bool, message: String) -> void:
	if _ended:
		return
	_ended = true
	_prompt_left = 0.0
	if is_instance_valid(_prompt_layer):
		_prompt_layer.hide()
	var result_message := message
	if not managed_by_flow:
		result_message += " · Press %s to retry." % InputActions.action_label(InputActions.ACTION_RETRY)
	_show_result(success, result_message)
	round_completed.emit(success)

func can_interact() -> bool:
	return is_inside_tree() and not get_tree().paused and not _ended and _prompt_left <= 0.0 and _seconds_left > 0.0

func get_seconds_left() -> float:
	return _seconds_left

func is_round_finished() -> bool:
	return _ended

func get_round_seconds() -> float:
	return 10.0

func _build_ui() -> void:
	pass

func _reset_game() -> void:
	pass

func _update_game(_delta: float) -> void:
	pass

func _on_timeout() -> void:
	_finish_round(false, "Time's up!")

func _show_result(_success: bool, _message: String) -> void:
	pass

func _build_prompt() -> void:
	_prompt_layer = CanvasLayer.new()
	_prompt_layer.name = "RoundPrompt"
	_prompt_layer.layer = 50
	add_child(_prompt_layer)
	_prompt_cover = ColorRect.new()
	_prompt_cover.color = Color(0.03, 0.06, 0.12, 0.75)
	_prompt_cover.mouse_filter = Control.MOUSE_FILTER_STOP
	_prompt_cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_prompt_layer.add_child(_prompt_cover)
	_prompt_label = Label.new()
	_prompt_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prompt_label.add_theme_font_size_override("font_size", 64)
	_prompt_label.add_theme_color_override("font_color", Color("ffd166"))
	_prompt_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_cover.add_child(_prompt_label)
