extends "res://scripts/core/microgame_base.gd"

## Drag the matching logic gate and inputs into a circuit.
const UI := preload("res://scripts/ui/microgame_ui.gd")
const CardDrag := preload("res://scripts/core/card_drag.gd")
const DURATIONS: Array[float] = [10.0, 8.0, 6.0]
const GATE_NAMES: Array[String] = ["AND", "OR", "NOT", "XOR"]
const SYMBOLS: Dictionary = {"AND": "A · B", "OR": "A + B", "NOT": "¬ A", "XOR": "A ⊕ B"}

var _gate_name := "AND"
var _placed: Dictionary = {}
var _cards: Array[Button] = []
var _drag := CardDrag.new()
var _dragging: Button:
	get: return _drag.card as Button
	set(value): _drag.card = value
var _zones: Dictionary = {}
var _status_label: Label
var _timer_label: Label
var _expression_label: Label
var _rng := RandomNumberGenerator.new()


func get_round_seconds() -> float:
	return DURATIONS[clampi(difficulty, 0, 2)]


func _input(event: InputEvent) -> void:
	if not can_interact():
		_drag.cancel()
		return
	if _drag.handle_input(event):
		get_viewport().set_input_as_handled()


func _update_game(_delta: float) -> void:
	_timer_label.text = "TIME  %.1f s" % _seconds_left


func _build_ui() -> void:
	_rng.randomize()
	_drag.dropped.connect(_on_card_dropped)
	var header := UI.build_header(self, "LOGIC GATES", "Drag the gate and input labels into the matching sockets.", show_internal_timer)
	_timer_label = header.timer
	_expression_label = UI.label(self, "", Vector2(340, 190), 25, UI.ACCENT, Vector2(840, 36))
	_status_label = UI.label(self, "", Vector2(48, 640), 20, UI.MUTED)
	_make_zone("GATE", Vector2(820, 300), "GATE")
	_make_zone("A", Vector2(500, 455), "INPUT A")
	_make_zone("B", Vector2(820, 455), "INPUT B")


func _make_zone(key: String, zone_position: Vector2, title: String) -> void:
	var zone := UI.panel(self, Rect2(zone_position, Vector2(220, 70)), Color("#20375d"), Color("#73b7ff"), 9)
	var label := UI.label(zone, title, Vector2.ZERO, 20, UI.TEXT, Vector2.ZERO)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_zones[key] = zone


func _reset_game() -> void:
	_drag.cancel()
	_placed.clear()
	_gate_name = GATE_NAMES[_rng.randi_range(0, 1 if difficulty == 0 else 3)]
	_timer_label.text = "TIME  %.1f s" % _seconds_left
	_expression_label.text = "BUILD  X = %s" % SYMBOLS[_gate_name]
	UI.set_status(_status_label, "Match the gate and inputs before time runs out")
	UI.clear_nodes(_cards)
	_zones["B"].visible = _gate_name != "NOT"
	var choices := 2 if difficulty == 0 else 4
	for index: int in choices:
		_make_card("GATE", GATE_NAMES[index], Vector2(70, 285 + index * 68))
	_make_card("A", "A", Vector2(410, 565))
	if _gate_name != "NOT":
		_make_card("B", "B", Vector2(635, 565))


func _make_card(kind: String, value: String, origin: Vector2) -> void:
	var card := Button.new()
	card.text = value
	card.position = origin
	card.size = Vector2(170, 54)
	card.focus_mode = Control.FOCUS_NONE
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.add_theme_font_size_override("font_size", 20)
	card.set_meta("kind", kind)
	card.set_meta("value", value)
	card.set_meta("origin", origin)
	card.gui_input.connect(_on_card_input.bind(card))
	add_child(card)
	_cards.append(card)


func _on_card_input(event: InputEvent, card: Button) -> void:
	if not can_interact() or card.disabled:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_drag.begin(card, event.position)
		get_viewport().set_input_as_handled()


func _finish_drag() -> void:
	_drag.finish()


func _on_card_dropped(card: Button) -> void:
	if not can_interact():
		card.position = card.get_meta("origin")
		return
	var kind: String = card.get_meta("kind")
	var value: String = card.get_meta("value")
	var zone: PanelContainer = _zones[kind]
	if CardDrag.contains_center(card, zone) and not _placed.has(kind) and (kind != "GATE" or value == _gate_name):
		_placed[kind] = true
		CardDrag.center_on(card, zone)
		card.disabled = true
		card.z_index = 5
		UI.set_status(_status_label, "%s connected" % value, "success")
		var needed := 2 if _gate_name == "NOT" else 3
		if _placed.size() == needed:
			_finish_round(true, "Circuit complete — X = %s" % SYMBOLS[_gate_name])
	else:
		card.position = card.get_meta("origin")
		UI.set_status(_status_label, "Wrong socket or gate — try again", "warning")


func _on_timeout() -> void:
	_finish_round(false, "Time's up — rebuild the circuit!")


func _show_result(success: bool, message: String) -> void:
	_drag.cancel()
	UI.set_status(_status_label, message, "success" if success else "error")
	for card: Button in _cards:
		card.disabled = true
