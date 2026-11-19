extends Control

## SCRUM-85: drag the matching logic gate and inputs into a circuit.

signal round_completed(success: bool)
signal time_changed(seconds_left: float, round_seconds: float)

@export_range(0, 2, 1) var difficulty: int = 0

const DURATIONS: Array[float] = [10.0, 8.0, 6.0]
const GATE_NAMES: Array[String] = ["AND", "OR", "NOT", "XOR"]
const SYMBOLS: Dictionary = {"AND": "A · B", "OR": "A + B", "NOT": "¬ A", "XOR": "A ⊕ B"}

var _seconds_left := 0.0
var _ended := false
var _gate_name := "AND"
var _placed: Dictionary = {}
var _cards: Array[Button] = []
var _dragging: Button
var _drag_offset := Vector2.ZERO
var _zones: Dictionary = {}
var _status_label: Label
var _timer_label: Label
var _expression_label: Label
var _rng := RandomNumberGenerator.new()


func get_round_seconds() -> float:
	return DURATIONS[clampi(difficulty, 0, 2)]


func _ready() -> void:
	difficulty = clampi(difficulty, 0, 2)
	_rng.randomize()
	_build_ui()
	_start_round()


func _input(event: InputEvent) -> void:
	if _dragging == null or _ended:
		return
	if event is InputEventMouseMotion:
		_dragging.position = get_global_mouse_position() - _drag_offset
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_finish_drag()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _ended:
		return
	_seconds_left = maxf(0.0, _seconds_left - delta)
	_timer_label.text = "TIME  %.1f s" % _seconds_left
	time_changed.emit(_seconds_left, DURATIONS[difficulty])
	if _seconds_left <= 0.0:
		_finish_round(false, "Time's up — rebuild the circuit!")


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color("#101a2d")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var title := Label.new()
	title.text = "LOGIC GATES"
	title.position = Vector2(48, 35)
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color("#f5f7ff"))
	add_child(title)
	var instruction := Label.new()
	instruction.text = "Drag the gate and input labels into the matching sockets."
	instruction.position = Vector2(48, 125)
	instruction.add_theme_font_size_override("font_size", 20)
	instruction.add_theme_color_override("font_color", Color("#b8c7e6"))
	add_child(instruction)
	_timer_label = Label.new()
	_timer_label.position = Vector2(48, 182)
	_timer_label.add_theme_font_size_override("font_size", 23)
	_timer_label.add_theme_color_override("font_color", Color("#ffd166"))
	add_child(_timer_label)
	_expression_label = Label.new()
	_expression_label.position = Vector2(340, 182)
	_expression_label.add_theme_font_size_override("font_size", 25)
	_expression_label.add_theme_color_override("font_color", Color("#ffd166"))
	add_child(_expression_label)
	_status_label = Label.new()
	_status_label.position = Vector2(48, 635)
	_status_label.size = Vector2(1180, 44)
	_status_label.add_theme_font_size_override("font_size", 20)
	_status_label.add_theme_color_override("font_color", Color("#b8c7e6"))
	add_child(_status_label)
	_make_zone("GATE", Vector2(820, 300), "GATE")
	_make_zone("A", Vector2(500, 455), "INPUT A")
	_make_zone("B", Vector2(820, 455), "INPUT B")


func _make_zone(key: String, zone_position: Vector2, title: String) -> void:
	var zone := PanelContainer.new()
	zone.position = zone_position
	zone.size = Vector2(220, 70)
	zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#20375d")
	style.border_color = Color("#73b7ff")
	style.set_border_width_all(2)
	style.set_corner_radius_all(9)
	zone.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = title
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	zone.add_child(label)
	add_child(zone)
	_zones[key] = zone


func _start_round() -> void:
	_ended = false
	_placed.clear()
	_seconds_left = DURATIONS[difficulty]
	_gate_name = GATE_NAMES[_rng.randi_range(0, 1 if difficulty == 0 else 3)]
	_timer_label.text = "TIME  %.1f s" % _seconds_left
	_expression_label.text = "BUILD  X = %s" % SYMBOLS[_gate_name]
	_status_label.text = "Match the gate and inputs before time runs out"
	for card: Button in _cards:
		card.queue_free()
	_cards.clear()
	_zones["B"].visible = _gate_name != "NOT"
	var choices := 2 if difficulty == 0 else 4
	for index: int in choices:
		_make_card("GATE", GATE_NAMES[index], Vector2(70, 285 + index * 68))
	_make_card("A", "A", Vector2(410, 565))
	if _gate_name != "NOT":
		_make_card("B", "B", Vector2(635, 565))
	time_changed.emit(_seconds_left, DURATIONS[difficulty])


func _make_card(kind: String, value: String, origin: Vector2) -> void:
	var card := Button.new()
	card.text = value
	card.position = origin
	card.size = Vector2(170, 54)
	card.add_theme_font_size_override("font_size", 20)
	card.set_meta("kind", kind)
	card.set_meta("value", value)
	card.set_meta("origin", origin)
	card.gui_input.connect(_on_card_input.bind(card))
	add_child(card)
	_cards.append(card)


func _on_card_input(event: InputEvent, card: Button) -> void:
	if _ended or card.disabled:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_dragging = card
		_drag_offset = event.position
		card.z_index = 20
		card.grab_focus()


func _finish_drag() -> void:
	if not is_instance_valid(_dragging):
		_dragging = null
		return
	var card := _dragging
	_dragging = null
	card.z_index = 1
	var center := card.global_position + card.size * 0.5
	var kind: String = card.get_meta("kind")
	var value: String = card.get_meta("value")
	var zone: PanelContainer = _zones[kind]
	if zone.get_global_rect().has_point(center) and not _placed.has(kind) and (kind != "GATE" or value == _gate_name):
		_placed[kind] = true
		card.position = zone.position + (zone.size - card.size) * 0.5
		card.disabled = true
		card.z_index = 5
		_status_label.text = "%s connected" % value
		var needed := 2 if _gate_name == "NOT" else 3
		if _placed.size() == needed:
			_finish_round(true, "Circuit complete — X = %s" % SYMBOLS[_gate_name])
	else:
		card.position = card.get_meta("origin")
		_status_label.text = "Wrong socket or gate — try again"


func _finish_round(success: bool, message: String) -> void:
	if _ended:
		return
	_ended = true
	_status_label.text = message
	_status_label.add_theme_color_override("font_color", Color("#73e6a8") if success else Color("#ff9e9e"))
	for card: Button in _cards:
		card.disabled = true
	round_completed.emit(success)
