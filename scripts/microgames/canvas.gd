extends "res://scripts/core/microgame_base.gd"

## Upload the correct file, then submit; higher difficulties move the targets.
const UI := preload("res://scripts/ui/microgame_ui.gd")
const CardDrag := preload("res://scripts/core/card_drag.gd")
const ROUND_SECONDS: Array[float] = [9.0, 8.0, 7.0]
const DECOY_NAMES: Array[String] = ["notes.txt", "lecture.pdf", "draft.zip"]
const NAVY := Color("304452")
const BLUE := Color("075b94")
const INK := Color("263b4e")
const MUTED_INK := Color("536b7d")

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
	_art = UI.pixel_canvas(self, _draw_world)
	var header := UI.build_header(self, "CANVAS UPLOAD", "DRAG FILE.ZIP, THEN SUBMIT.", show_internal_timer)
	_timer_label = header.timer
	UI.label(self, "ACCOUNT", Vector2(17, 103), 14, UI.TEXT, Vector2(100, 30))
	UI.label(self, "DASHBOARD", Vector2(5, 178), 14, UI.TEXT, Vector2(115, 30))
	UI.label(self, "COURSES", Vector2(17, 253), 14, UI.TEXT, Vector2(100, 30))
	UI.label(self, "CALENDAR", Vector2(11, 328), 14, UI.TEXT, Vector2(105, 30))
	UI.label(self, "INBOX", Vector2(28, 403), 14, UI.TEXT, Vector2(85, 30))
	UI.label(self, "ECS 179", Vector2(140, 98), 21, INK, Vector2(150, 35))
	UI.label(self, "HOME", Vector2(140, 178), 14, BLUE, Vector2(145, 30))
	UI.label(self, "ASSIGNMENTS", Vector2(140, 230), 14, BLUE, Vector2(155, 30))
	UI.label(self, "FILES", Vector2(140, 282), 14, BLUE, Vector2(145, 30))
	UI.label(self, "GRADES", Vector2(140, 334), 14, BLUE, Vector2(145, 30))
	UI.label(self, "ECS 179  >  ASSIGNMENTS", Vector2(330, 70), 21, BLUE, Vector2(650, 32))
	UI.label(self, "Game Design Upload", Vector2(330, 140), 35, INK, Vector2(750, 45))
	UI.label(self, "DUE  TODAY  11:59 PM", Vector2(330, 215), 14, MUTED_INK, Vector2(270, 26))
	UI.label(self, "SUBMITTING  A FILE UPLOAD", Vector2(630, 215), 14, MUTED_INK, Vector2(420, 26))
	UI.label(self, "FILE UPLOAD", Vector2(330, 285), 21, INK, Vector2(300, 35))
	UI.label(self, "CHOOSE A FILE", Vector2(330, 345), 14, MUTED_INK, Vector2(250, 28))
	UI.label(self, "DRAG A FILE HERE", Vector2(660, 335), 14, MUTED_INK, Vector2(350, 28))
	_drop_zone = Control.new()
	_drop_zone.position = Vector2(620, 370)
	_drop_zone.size = Vector2(490, 160)
	_drop_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_drop_zone)
	_drop_zone_label = UI.label(_drop_zone, "DROP FILE.ZIP", Vector2(20, 55), 28, BLUE, Vector2(450, 40))
	_drop_zone_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label = UI.status_label(self)
	_submit_button = Button.new()
	_submit_button.text = "SUBMIT ASSIGNMENT"
	_submit_button.position = Vector2(910, 580)
	_submit_button.size = Vector2(320, 64)
	_submit_button.focus_mode = Control.FOCUS_NONE
	UI.flat_button(_submit_button, 21)
	_submit_button.pressed.connect(_on_submit_pressed)
	add_child(_submit_button)


func _draw_world() -> void:
	if not is_instance_valid(_drop_zone):
		return
	_art.draw_rect(Rect2(0, 0, 1280, 720), Color.WHITE)
	_art.draw_rect(Rect2(0, 0, 120, 720), NAVY)
	_art.draw_rect(Rect2(120, 0, 180, 720), Color("f5f6f8"))
	_art.draw_rect(Rect2(300, 45, 980, 3), Color("e2e5e9"))
	_art.draw_rect(Rect2(320, 110, 900, 2), Color("d9dee4"))
	_art.draw_rect(Rect2(320, 255, 900, 2), Color("d9dee4"))
	_art.draw_rect(Rect2(320, 315, 900, 2), Color("d9dee4"))
	_art.draw_rect(Rect2(320, 560, 900, 2), Color("d9dee4"))
	_art.draw_rect(Rect2(125, 220, 6, 48), BLUE)
	for y in [75, 150, 225, 300, 375]:
		_art.draw_rect(Rect2(47, y, 25, 25), Color("dde8ee"))
	var screen := Rect2(_drop_zone.position, _drop_zone.size * _drop_zone.scale)
	_art.draw_rect(screen, Color("f1f8fc") if _placed_file == null else Color("e8f7ee"))
	for step in 8:
		_art.draw_rect(Rect2(screen.position + Vector2(step * 60, 0), Vector2(35, 5)), BLUE)
		_art.draw_rect(Rect2(screen.position + Vector2(step * 60, screen.size.y - 5), Vector2(35, 5)), BLUE)
	for step in 3:
		_art.draw_rect(Rect2(screen.position + Vector2(0, step * 55), Vector2(5, 30)), BLUE)
		_art.draw_rect(Rect2(screen.position + Vector2(screen.size.x - 5, step * 55), Vector2(5, 30)), BLUE)
	_art.draw_rect(Rect2(_submit_button.position + Vector2(4, 5), _submit_button.size), Color("bbc8d2"))
	_art.draw_rect(Rect2(_submit_button.position, _submit_button.size), BLUE)
	_art.draw_rect(Rect2(_submit_button.position, Vector2(_submit_button.size.x, 4)), Color("4d9bcc"))
	for card: Control in _files:
		if card != _drag.card:
			_draw_file(card)
	if is_instance_valid(_drag.card):
		_draw_file(_drag.card)


func _draw_file(card: Control) -> void:
	var box := Rect2(card.position, card.size * card.scale)
	_art.draw_rect(Rect2(box.position + Vector2(3, 4), box.size), Color("c9d3da"))
	_art.draw_rect(box, Color.WHITE)
	_art.draw_rect(Rect2(box.position, Vector2(8, box.size.y)), BLUE)
	_art.draw_rect(Rect2(box.position + Vector2(12, box.size.y - 4), Vector2(box.size.x - 18, 3)), Color("ced9e1"))

func _reset_game() -> void:
	_drag.cancel()
	_placed_file = null
	_zone_clock = 0.0
	_submit_clock = 0.0
	_timer_label.text = "TIME %.1f" % _seconds_left
	UI.set_status(_status_label, "")
	_drop_zone_label.text = "DROP FILE.ZIP"
	_submit_button.text = "SUBMIT ASSIGNMENT"
	_submit_button.disabled = false
	_drop_zone.position = Vector2(620, 370)
	_submit_button.position = Vector2(910, 580)
	UI.clear_nodes(_files)
	_create_file_card("file.zip", true, Vector2(330, 380))
	for index: int in range(difficulty + 1):
		_create_file_card(DECOY_NAMES[index], false, Vector2(330, 444 + index * 64))
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
	card.add_theme_color_override("font_color", INK)
	card.add_theme_color_override("font_hover_color", INK)
	card.add_theme_color_override("font_pressed_color", INK)
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
			_drop_zone_label.text = "FILE ATTACHED"
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
	_drop_zone.position = Vector2(_rng.randf_range(610.0, 690.0), _rng.randf_range(365.0, 410.0))
	if is_instance_valid(_placed_file):
		CardDrag.center_on(_placed_file, _drop_zone)


func _move_submit_button() -> void:
	_submit_button.position = Vector2(_rng.randf_range(880.0, 940.0), _rng.randf_range(580.0, 625.0))
