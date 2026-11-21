extends "res://scripts/core/microgame_base.gd"

## Upload the correct file, then submit; higher difficulties move the targets.
const UI := preload("res://scripts/ui/microgame_ui.gd")
const CardDrag := preload("res://scripts/core/card_drag.gd")
const ROUND_SECONDS: Array[float] = [10.0, 8.0, 6.0]
const DECOY_NAMES: Array[String] = ["notes.txt", "lecture.pdf", "draft.zip"]

var _zone_clock := 0.0
var _submit_clock := 0.0
var _placed_file: Control
var _drag := CardDrag.new()
var _dragging_file: Control:
	get: return _drag.card
	set(value): _drag.card = value
var _files: Array[Control] = []
var _timer_label: Label
var _status_label: Label
var _drop_zone: PanelContainer
var _drop_zone_label: Label
var _submit_button: Button
var _rng := RandomNumberGenerator.new()


func get_round_seconds() -> float:
	return ROUND_SECONDS[clampi(difficulty, 0, 2)]


func _input(event: InputEvent) -> void:
	if not can_interact():
		_drag.cancel()
		return
	if _drag.handle_input(event):
		get_viewport().set_input_as_handled()


func _update_game(delta: float) -> void:
	_timer_label.text = "TIME  %.1f s" % _seconds_left
	if _seconds_left <= 0.0:
		return
	if difficulty >= 1:
		_zone_clock += delta
		while _zone_clock >= 1.25:
			_zone_clock -= 1.25
			_move_drop_zone()
	if difficulty >= 2:
		_submit_clock += delta
		while _submit_clock >= 1.5:
			_submit_clock -= 1.5
			_move_submit_button()
	if InputActions.is_just_pressed(InputActions.ACTION_CONFIRM):
		_on_submit_pressed()


func _build_ui() -> void:
	_rng.randomize()
	_drag.dropped.connect(_on_file_dropped)
	var header := UI.build_header(self, "CANVAS", "Upload file.zip to the Canvas assignment, then submit it.", show_internal_timer)
	_timer_label = header.timer
	UI.panel(self, Rect2(40, 235, 280, 350))
	UI.label(self, "Your files", Vector2(60, 247), 20, UI.TEXT, Vector2(240, 28))
	UI.label(self, "Drag the correct file", Vector2(60, 275), 16, UI.MUTED, Vector2(240, 24))
	_drop_zone = UI.panel(self, Rect2(420, 255, 490, 210), Color("#20375d"), Color("#73b7ff"))
	var drop_layout := VBoxContainer.new()
	drop_layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drop_layout.alignment = BoxContainer.ALIGNMENT_CENTER
	drop_layout.add_theme_constant_override("separation", 8)
	_drop_zone.add_child(drop_layout)
	_drop_zone_label = UI.label(drop_layout, "DROP FILE HERE", Vector2.ZERO, 28, UI.TEXT, Vector2.ZERO)
	_drop_zone_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var drop_hint := UI.label(drop_layout, "Canvas assignment", Vector2.ZERO, 18, UI.MUTED, Vector2.ZERO)
	drop_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label = UI.label(self, "", Vector2(48, 640), 20)
	_submit_button = Button.new()
	_submit_button.text = "Submit to Canvas"
	_submit_button.position = Vector2(960, 320)
	_submit_button.size = Vector2(240, 64)
	_submit_button.focus_mode = Control.FOCUS_NONE
	_submit_button.add_theme_font_size_override("font_size", 20)
	_submit_button.add_theme_stylebox_override("normal", UI.panel_style(Color("#2b7a5b"), Color("#55d69b")))
	_submit_button.add_theme_stylebox_override("hover", UI.panel_style(Color("#3d9b72"), Color("#8af0bd")))
	_submit_button.pressed.connect(_on_submit_pressed)
	add_child(_submit_button)
	UI.label(self, _difficulty_text(), Vector2(48, 682), 15, UI.MUTED)


func _reset_game() -> void:
	_drag.cancel()
	_placed_file = null
	_zone_clock = 0.0
	_submit_clock = 0.0
	_timer_label.text = "TIME  %.1f s" % _seconds_left
	UI.set_status(_status_label, "")
	_drop_zone_label.text = "DROP FILE HERE"
	_submit_button.text = "Submit to Canvas"
	_submit_button.disabled = false
	_drop_zone.position = Vector2(420, 255)
	_submit_button.position = Vector2(960, 320)
	UI.clear_nodes(_files)
	_create_file_card("file.zip", true, Vector2(70, 310))
	for index: int in range(difficulty + 1):
		_create_file_card(DECOY_NAMES[index], false, Vector2(70, 374 + index * 64))


func _create_file_card(file_name: String, is_target: bool, card_position: Vector2) -> void:
	var card := Button.new()
	card.text = file_name
	card.position = card_position
	card.size = Vector2(220, 52)
	card.custom_minimum_size = card.size
	card.focus_mode = Control.FOCUS_NONE
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.add_theme_font_size_override("font_size", 18)
	card.add_theme_color_override("font_color", Color("#152643"))
	card.add_theme_color_override("font_hover_color", Color("#152643"))
	card.add_theme_color_override("font_pressed_color", Color("#152643"))
	card.add_theme_stylebox_override("normal", UI.panel_style(Color("#f1f5ff"), Color("#9bb4e3")))
	card.add_theme_stylebox_override("hover", UI.panel_style(Color("#ffffff"), Color("#73b7ff")))
	card.set_meta("is_target", is_target)
	card.set_meta("origin", card_position)
	card.gui_input.connect(_on_file_gui_input.bind(card))
	add_child(card)
	_files.append(card)


func _on_file_gui_input(event: InputEvent, card: Control) -> void:
	if not can_interact() or card == _placed_file:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_drag.begin(card, event.position)
		get_viewport().set_input_as_handled()


func _finish_drag() -> void:
	_drag.finish()


func _on_file_dropped(card: Control) -> void:
	if not can_interact():
		card.position = card.get_meta("origin")
		return
	if CardDrag.contains_center(card, _drop_zone):
		if bool(card.get_meta("is_target", false)):
			_placed_file = card
			CardDrag.center_on(card, _drop_zone)
			card.z_index = 5
			_drop_zone_label.text = "file.zip READY"
			UI.set_status(_status_label, "Correct file — press Submit", "success")
		else:
			UI.set_status(_status_label, "That is not the assignment file", "error")
			card.position = card.get_meta("origin")
	else:
		card.position = card.get_meta("origin")


func _on_submit_pressed() -> void:
	if not can_interact():
		return
	if _placed_file == null:
		UI.set_status(_status_label, "Drag file.zip into the drop zone first", "warning")
		return
	_finish_round(true, "Submitted — Canvas upload complete!")


func _on_timeout() -> void:
	_finish_round(false, "Time's up — try again!")


func _show_result(success: bool, message: String) -> void:
	_drag.cancel()
	UI.set_status(_status_label, message, "success" if success else "error")
	_submit_button.disabled = true
	for file_card: Button in _files:
		file_card.disabled = true


func _move_drop_zone() -> void:
	_drop_zone.position = Vector2(_rng.randf_range(360.0, 650.0), _rng.randf_range(220.0, 390.0))
	if is_instance_valid(_placed_file):
		CardDrag.center_on(_placed_file, _drop_zone)


func _move_submit_button() -> void:
	_submit_button.position = Vector2(_rng.randf_range(920.0, 1010.0), _rng.randf_range(230.0, 520.0))


func _difficulty_text() -> String:
	match difficulty:
		0: return "Difficulty 1 · upload and submit the correct file"
		1: return "Difficulty 2 · decoy files + moving drop zone"
		_: return "Difficulty 3 · less time + moving drop zone + shifting submit"
