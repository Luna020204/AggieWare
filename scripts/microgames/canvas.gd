extends "res://scripts/core/microgame_base.gd"

## Upload the correct file, then submit; higher difficulties move the targets.
const UI := preload("res://scripts/ui/microgame_ui.gd")
const CardDrag := preload("res://scripts/core/card_drag.gd")
const ROUND_SECONDS: Array[float] = [9.0, 8.0, 7.0]
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
var _drop_zone: Control
var _art: Control
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
	_timer_label.text = "TIME %.1f" % _seconds_left
	_art.queue_redraw()
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
	UI.add_backdrop(self, "desk")
	_art = UI.pixel_canvas(self, _draw_world)
	var header := UI.build_header(self, "CANVAS UPLOAD", "DRAG FILE.ZIP, THEN SUBMIT.", show_internal_timer)
	_timer_label = header.timer
	_drop_zone = Control.new()
	_drop_zone.position = Vector2(420, 255)
	_drop_zone.size = Vector2(490, 210)
	_drop_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_drop_zone)
	_drop_zone_label = UI.label(_drop_zone, "DROP FILE.ZIP", Vector2(20, 20), 28, UI.TEXT, Vector2(450, 40))
	_drop_zone_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label = UI.status_label(self)
	_submit_button = Button.new()
	_submit_button.text = "SUBMIT"
	_submit_button.position = Vector2(960, 320)
	_submit_button.size = Vector2(240, 64)
	_submit_button.focus_mode = Control.FOCUS_NONE
	UI.flat_button(_submit_button, 28)
	_submit_button.pressed.connect(_on_submit_pressed)
	add_child(_submit_button)


func _draw_world() -> void:
	if not is_instance_valid(_drop_zone):
		return
	var screen := Rect2(_drop_zone.position, _drop_zone.size * _drop_zone.scale)
	_art.draw_rect(screen.grow(15), Color("253347"))
	_art.draw_rect(screen, Color("315b67"))
	_art.draw_rect(Rect2(screen.position + Vector2(10, 10), Vector2(screen.size.x - 20, 5)), Color("78a2a2"))
	var keyboard := Rect2(screen.position + Vector2(-30, screen.size.y + 15), Vector2(screen.size.x + 60, 70))
	_art.draw_rect(keyboard, Color("475463"))
	for row in 3:
		for key in 14:
			_art.draw_rect(Rect2(keyboard.position + Vector2(25 + key * 35, 10 + row * 15), Vector2(25, 8)), Color("809299"))
	_art.draw_rect(Rect2(_submit_button.position + Vector2(5, 8), _submit_button.size), Color("243632"))
	_art.draw_rect(Rect2(_submit_button.position, _submit_button.size), Color("358061"))
	_art.draw_rect(Rect2(_submit_button.position + Vector2(5, 5), Vector2(_submit_button.size.x - 10, 5)), Color("7fbf96"))
	for card: Control in _files:
		if card != _drag.card:
			_draw_file(card)
	if is_instance_valid(_drag.card):
		_draw_file(_drag.card)


func _draw_file(card: Control) -> void:
	var box := Rect2(card.position, card.size * card.scale)
	_art.draw_rect(Rect2(box.position + Vector2(5, 8), box.size), Color(0.22, 0.18, 0.21, 0.5))
	_art.draw_rect(box, Color("e8d6ac"))
	_art.draw_rect(Rect2(box.position, Vector2(20, box.size.y)), Color("d9aa59"))
	_art.draw_rect(Rect2(box.end - Vector2(20, box.size.y), Vector2(20, 15)), Color("b8b08c"))
	_art.draw_rect(Rect2(box.position + Vector2(30, box.size.y - 10), Vector2(box.size.x - 50, 5)), Color("c5bd9b"))

func _reset_game() -> void:
	_drag.cancel()
	_placed_file = null
	_zone_clock = 0.0
	_submit_clock = 0.0
	_timer_label.text = "TIME %.1f" % _seconds_left
	UI.set_status(_status_label, "")
	_drop_zone_label.text = "DROP FILE.ZIP"
	_submit_button.text = "SUBMIT"
	_submit_button.disabled = false
	_drop_zone.position = Vector2(420, 255)
	_submit_button.position = Vector2(960, 320)
	UI.clear_nodes(_files)
	_create_file_card("file.zip", true, Vector2(70, 310))
	for index: int in range(difficulty + 1):
		_create_file_card(DECOY_NAMES[index], false, Vector2(70, 374 + index * 64))
	_art.queue_redraw()


func _create_file_card(file_name: String, is_target: bool, card_position: Vector2) -> void:
	var card := Button.new()
	card.text = file_name.to_upper()
	card.position = card_position
	card.size = Vector2(220, 52)
	card.custom_minimum_size = card.size
	card.focus_mode = Control.FOCUS_NONE
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	UI.flat_button(card, 21)
	card.add_theme_color_override("font_color", Color("#152643"))
	card.add_theme_color_override("font_hover_color", Color("#152643"))
	card.add_theme_color_override("font_pressed_color", Color("#152643"))
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
			_drop_zone_label.text = "READY TO SUBMIT"
		else:
			show_feedback("WRONG FILE!", UI.REJECT)
			card.position = card.get_meta("origin")
	else:
		card.position = card.get_meta("origin")


func _on_submit_pressed() -> void:
	if not can_interact():
		return
	if _placed_file == null:
		show_feedback("UPLOAD FILE.ZIP FIRST!", UI.REJECT)
		return
	_finish_round(true, "UPLOADED!")


func _on_timeout() -> void:
	_finish_round(false, "TIME'S UP!")


func _show_result(_success: bool, _message: String) -> void:
	_drag.cancel()
	_art.queue_redraw()
	_submit_button.disabled = true
	for file_card: Button in _files:
		file_card.disabled = true


func _on_pause_changed(paused: bool) -> void:
	if paused:
		_drag.cancel()
		_art.queue_redraw()


func _move_drop_zone() -> void:
	_drop_zone.position = Vector2(_rng.randf_range(360.0, 650.0), _rng.randf_range(220.0, 390.0))
	if is_instance_valid(_placed_file):
		CardDrag.center_on(_placed_file, _drop_zone)


func _move_submit_button() -> void:
	_submit_button.position = Vector2(_rng.randf_range(920.0, 1010.0), _rng.randf_range(230.0, 520.0))
