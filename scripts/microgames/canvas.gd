extends Control

## SCRUM-56: Canvas registration mini-game.
##
## The player must drag file.zip into the Canvas drop zone and submit it before
## time runs out. Difficulty variants add decoy files, a moving drop zone, and
## a shifting submit button. Mouse interaction is local to this mini-game;
## keyboard actions still go through the shared InputActions autoload.

signal round_completed(success: bool)

@export_range(0, 2, 1) var difficulty: int = 0

const ROUND_SECONDS: Array[float] = [10.0, 8.0, 6.0]
const DECOY_NAMES: Array[String] = ["notes.txt", "lecture.pdf", "draft.zip"]

var _time_left: float = 0.0
var _zone_clock: float = 0.0
var _submit_clock: float = 0.0
var _game_over := false
var _placed_file: Control
var _dragging_file: Control
var _drag_offset := Vector2.ZERO
var _files: Array[Control] = []

var _timer_label: Label
var _status_label: Label
var _drop_zone: PanelContainer
var _drop_zone_label: Label
var _submit_button: Button
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	difficulty = clampi(difficulty, 0, 2)
	_rng.randomize()
	_build_ui()
	_start_round()


func _process(delta: float) -> void:
	if _game_over:
		return

	_time_left = maxf(0.0, _time_left - delta)
	_timer_label.text = "Time: %.1f" % _time_left
	if _time_left <= 0.0:
		_finish_round(false, "Time's up — try again")
		return

	if difficulty >= 1:
		_zone_clock += delta
		if _zone_clock >= 1.25:
			_zone_clock = 0.0
			_move_drop_zone()

	if difficulty >= 2:
		_submit_clock += delta
		if _submit_clock >= 1.5:
			_submit_clock = 0.0
			_move_submit_button()

	if InputActions.is_just_pressed(InputActions.ACTION_CONFIRM):
		_on_submit_pressed()


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color("#101a2d")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var header := VBoxContainer.new()
	header.position = Vector2(40.0, 28.0)
	header.size = Vector2(1200.0, 112.0)
	header.add_theme_constant_override("separation", 4)
	add_child(header)

	var title := Label.new()
	title.text = "CANVAS"
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color("#f5f7ff"))
	header.add_child(title)

	var instruction := Label.new()
	instruction.text = "Upload file.zip to the Canvas assignment, then submit it."
	instruction.add_theme_font_size_override("font_size", 18)
	instruction.add_theme_color_override("font_color", Color("#b8c7e6"))
	header.add_child(instruction)

	_timer_label = Label.new()
	_timer_label.add_theme_font_size_override("font_size", 22)
	_timer_label.add_theme_color_override("font_color", Color("#ffd166"))
	header.add_child(_timer_label)

	var tray := PanelContainer.new()
	tray.position = Vector2(40.0, 190.0)
	tray.size = Vector2(280.0, 280.0)
	tray.add_theme_stylebox_override("panel", _panel_style(Color("#172746"), Color("#38537d")))
	add_child(tray)

	var tray_layout := VBoxContainer.new()
	tray_layout.add_theme_constant_override("separation", 8)
	tray_layout.add_theme_constant_override("margin_left", 18)
	tray_layout.add_theme_constant_override("margin_top", 18)
	tray_layout.add_theme_constant_override("margin_right", 18)
	tray_layout.add_theme_constant_override("margin_bottom", 18)
	tray.add_child(tray_layout)
	var tray_title := Label.new()
	tray_title.text = "Your files"
	tray_title.add_theme_font_size_override("font_size", 20)
	tray_layout.add_child(tray_title)
	var tray_hint := Label.new()
	tray_hint.text = "Drag the correct file"
	tray_hint.add_theme_color_override("font_color", Color("#a8b8d8"))
	tray_layout.add_child(tray_hint)

	_drop_zone = PanelContainer.new()
	_drop_zone.position = Vector2(420.0, 205.0)
	_drop_zone.size = Vector2(490.0, 210.0)
	_drop_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drop_zone.add_theme_stylebox_override("panel", _panel_style(Color("#20375d"), Color("#73b7ff")))
	add_child(_drop_zone)

	var drop_layout := VBoxContainer.new()
	drop_layout.alignment = BoxContainer.ALIGNMENT_CENTER
	drop_layout.add_theme_constant_override("separation", 8)
	_drop_zone.add_child(drop_layout)
	_drop_zone_label = Label.new()
	_drop_zone_label.text = "DROP FILE HERE"
	_drop_zone_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_drop_zone_label.add_theme_font_size_override("font_size", 28)
	drop_layout.add_child(_drop_zone_label)
	var drop_hint := Label.new()
	drop_hint.text = "Canvas assignment"
	drop_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	drop_hint.add_theme_color_override("font_color", Color("#b8c7e6"))
	drop_layout.add_child(drop_hint)

	_status_label = Label.new()
	_status_label.position = Vector2(420.0, 440.0)
	_status_label.size = Vector2(490.0, 44.0)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 18)
	add_child(_status_label)

	_submit_button = Button.new()
	_submit_button.text = "Submit to Canvas"
	_submit_button.position = Vector2(960.0, 280.0)
	_submit_button.size = Vector2(240.0, 64.0)
	_submit_button.add_theme_font_size_override("font_size", 20)
	_submit_button.add_theme_stylebox_override("normal", _panel_style(Color("#2b7a5b"), Color("#55d69b")))
	_submit_button.add_theme_stylebox_override("hover", _panel_style(Color("#3d9b72"), Color("#8af0bd")))
	_submit_button.pressed.connect(_on_submit_pressed)
	add_child(_submit_button)

	var difficulty_hint := Label.new()
	difficulty_hint.position = Vector2(40.0, 625.0)
	difficulty_hint.size = Vector2(1160.0, 36.0)
	difficulty_hint.text = _difficulty_text()
	difficulty_hint.add_theme_color_override("font_color", Color("#879ac1"))
	difficulty_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(difficulty_hint)


func _start_round() -> void:
	difficulty = clampi(difficulty, 0, 2)
	_game_over = false
	_placed_file = null
	_dragging_file = null
	_time_left = ROUND_SECONDS[clampi(difficulty, 0, 2)]
	_zone_clock = 0.0
	_submit_clock = 0.0
	_timer_label.text = "Time: %.1f" % _time_left
	_status_label.text = ""
	_status_label.add_theme_color_override("font_color", Color("#c7d5f2"))
	_drop_zone_label.text = "DROP FILE HERE"
	_submit_button.text = "Submit to Canvas"
	_submit_button.disabled = false
	_drop_zone.position = Vector2(420.0, 205.0)
	_submit_button.position = Vector2(960.0, 280.0)

	for file_card: Control in _files:
		file_card.queue_free()
	_files.clear()

	_create_file_card("file.zip", true, Vector2(70.0, 270.0))
	for index: int in range(difficulty + 1):
		var decoy_position := Vector2(70.0, 340.0 + index * 64.0)
		_create_file_card(DECOY_NAMES[index], false, decoy_position)


func _create_file_card(file_name: String, is_target: bool, card_position: Vector2) -> void:
	var card := Button.new()
	card.text = file_name
	card.position = card_position
	card.size = Vector2(220.0, 52.0)
	card.custom_minimum_size = Vector2(220.0, 52.0)
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.add_theme_font_size_override("font_size", 18)
	card.add_theme_stylebox_override("normal", _panel_style(Color("#f1f5ff"), Color("#9bb4e3")))
	card.add_theme_stylebox_override("hover", _panel_style(Color("#ffffff"), Color("#73b7ff")))
	card.set_meta("is_target", is_target)
	card.set_meta("origin", card_position)
	card.gui_input.connect(_on_file_gui_input.bind(card))
	add_child(card)
	_files.append(card)


func _on_file_gui_input(event: InputEvent, card: Control) -> void:
	if _game_over or card == _placed_file:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragging_file = card
			_drag_offset = event.position
			card.z_index = 20
			card.grab_focus()
		else:
			if _dragging_file == card:
				_finish_drag()
				get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _dragging_file == card:
		card.position = get_global_mouse_position() - _drag_offset
		get_viewport().set_input_as_handled()


func _finish_drag() -> void:
	if not is_instance_valid(_dragging_file):
		_dragging_file = null
		return

	var card := _dragging_file
	_dragging_file = null
	card.z_index = 1
	var center := card.global_position + card.size * 0.5
	if _drop_zone.get_global_rect().has_point(center):
		if bool(card.get_meta("is_target", false)):
			_placed_file = card
			card.position = _drop_zone.position + (_drop_zone.size - card.size) * 0.5
			card.z_index = 5
			_drop_zone_label.text = "file.zip READY"
			_status_label.text = "Correct file — press Submit"
			_status_label.add_theme_color_override("font_color", Color("#73e6a8"))
		else:
			_status_label.text = "That is not the assignment file"
			_status_label.add_theme_color_override("font_color", Color("#ff9e9e"))
			card.position = card.get_meta("origin")
	else:
		card.position = card.get_meta("origin")


func _on_submit_pressed() -> void:
	if _game_over:
		_start_round()
		return
	if _placed_file == null:
		_status_label.text = "Drag file.zip into the drop zone first"
		_status_label.add_theme_color_override("font_color", Color("#ffd166"))
		return
	_finish_round(true, "Submitted — Canvas upload complete!")


func _finish_round(success: bool, message: String) -> void:
	_game_over = true
	_status_label.text = message
	_status_label.add_theme_color_override("font_color", Color("#73e6a8") if success else Color("#ff9e9e"))
	_submit_button.text = "Play Again"
	_submit_button.disabled = false
	for file_card: Control in _files:
		file_card.disabled = true
	round_completed.emit(success)


func _move_drop_zone() -> void:
	_drop_zone.position = Vector2(
		_rng.randf_range(360.0, 650.0),
		_rng.randf_range(170.0, 390.0)
	)


func _move_submit_button() -> void:
	_submit_button.position = Vector2(
		_rng.randf_range(920.0, 1010.0),
		_rng.randf_range(230.0, 520.0)
	)


func _difficulty_text() -> String:
	match difficulty:
		0:
			return "Difficulty 1 · 10 seconds"
		1:
			return "Difficulty 2 · decoy files + moving drop zone"
		_:
			return "Difficulty 3 · less time + moving drop zone + shifting submit"


func _panel_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 12.0
	style.content_margin_top = 8.0
	style.content_margin_right = 12.0
	style.content_margin_bottom = 8.0
	return style
