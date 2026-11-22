extends "res://scripts/core/microgame_base.gd"

## Drag the matching logic gate and inputs into a circuit.
const UI := preload("res://scripts/ui/microgame_ui.gd")
const CardDrag := preload("res://scripts/core/card_drag.gd")
const DURATIONS: Array[float] = [9.0, 8.0, 7.0]
const GATE_NAMES: Array[String] = ["AND", "OR", "NOT", "XOR"]
const SYMBOLS: Dictionary = {"AND": "A AND B", "OR": "A OR B", "NOT": "NOT A", "XOR": "A XOR B"}

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
var _art: Control
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
	_timer_label.text = "TIME %.1f" % _seconds_left
	_art.queue_redraw()


func _build_ui() -> void:
	_rng.randomize()
	_drag.dropped.connect(_on_card_dropped)
	UI.add_backdrop(self, "engineering")
	_art = UI.pixel_canvas(self, _draw_world)
	var header := UI.build_header(self, "LOGIC GATES", "CONNECT THE GATE AND INPUTS.", show_internal_timer)
	_timer_label = header.timer
	_expression_label = UI.label(self, "", Vector2(450, 200), 28, UI.TEXT, Vector2(650, 40))
	_status_label = UI.status_label(self)
	_make_zone("GATE", Vector2(820, 300), "GATE")
	_make_zone("A", Vector2(500, 455), "INPUT A")
	_make_zone("B", Vector2(820, 455), "INPUT B")


func _make_zone(key: String, zone_position: Vector2, title: String) -> void:
	var zone := Control.new()
	zone.position = zone_position
	zone.size = Vector2(220, 70)
	zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(zone)
	var label := UI.label(zone, title, Vector2(0, -35), 21, UI.TEXT, Vector2(220, 30))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_zones[key] = zone


func _draw_world() -> void:
	_art.draw_rect(Rect2(350, 180, 850, 430), Color("203832"))
	_art.draw_rect(Rect2(365, 195, 820, 400), Color("365f45"))
	for at in [Vector2(375, 205), Vector2(1175, 205), Vector2(375, 585), Vector2(1175, 585)]:
		_art.draw_rect(Rect2(at, Vector2(10, 10)), Color("abb58c"))
	_art.draw_line(Vector2(610, 490), Vector2(610, 335), Color("b4a669"), 10)
	_art.draw_line(Vector2(610, 335), Vector2(840, 335), Color("b4a669"), 10)
	_art.draw_line(Vector2(930, 490), Vector2(1110, 490), Color("b4a669"), 10)
	_art.draw_line(Vector2(1110, 490), Vector2(1110, 335), Color("b4a669"), 10)
	_art.draw_line(Vector2(1020, 335), Vector2(1140, 335), Color("b4a669"), 10)
	_art.draw_rect(Rect2(1135, 320, 25, 25), Color("ffd166") if _placed.has("GATE") else Color("b8574d"))
	for key: String in _zones:
		var zone: Control = _zones[key]
		if not zone.visible:
			continue
		_art.draw_rect(Rect2(zone.position, zone.size), Color("152b29"))
		for pin in 5:
			var offset := Vector2(10 + pin * 45, -5)
			_art.draw_rect(Rect2(zone.position + offset, Vector2(15, 10)), Color("d5bc77"))
			_art.draw_rect(Rect2(zone.position + offset + Vector2(0, zone.size.y), Vector2(15, 10)), Color("d5bc77"))
	for card: Button in _cards:
		if card != _drag.card:
			_draw_chip(card)
	if is_instance_valid(_drag.card):
		_draw_chip(_drag.card)


func _draw_chip(card: Control) -> void:
	var box := Rect2(card.position, card.size * card.scale)
	_art.draw_rect(Rect2(box.position + Vector2(5, 5), box.size), Color("172626"))
	_art.draw_rect(box, Color("394453"))
	_art.draw_rect(Rect2(box.position + Vector2(5, 5), Vector2(box.size.x - 10, 5)), Color("647783"))
	for pin in 4:
		_art.draw_rect(Rect2(box.position + Vector2(10 + pin * 40, -5), Vector2(15, 10)), Color("b7c4bb"))
		_art.draw_rect(Rect2(box.position + Vector2(10 + pin * 40, box.size.y - 5), Vector2(15, 10)), Color("b7c4bb"))

func _reset_game() -> void:
	_drag.cancel()
	_placed.clear()
	_gate_name = GATE_NAMES[_rng.randi_range(0, 1 if difficulty == 0 else 3)]
	_timer_label.text = "TIME %.1f" % _seconds_left
	_expression_label.text = "X = %s" % SYMBOLS[_gate_name]
	UI.set_status(_status_label, "")
	UI.clear_nodes(_cards)
	_zones["B"].visible = _gate_name != "NOT"
	var choices := 2 if difficulty == 0 else 4
	for index: int in choices:
		_make_card("GATE", GATE_NAMES[index], Vector2(70, 285 + index * 68))
	_make_card("A", "A", Vector2(410, 565))
	if _gate_name != "NOT":
		_make_card("B", "B", Vector2(635, 565))
	_art.queue_redraw()


func _make_card(kind: String, value: String, origin: Vector2) -> void:
	var card := Button.new()
	card.text = value
	card.position = origin
	card.size = Vector2(170, 54)
	card.focus_mode = Control.FOCUS_NONE
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	UI.flat_button(card, 28)
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
	var zone: Control = _zones[kind]
	if CardDrag.contains_center(card, zone) and not _placed.has(kind) and (kind != "GATE" or value == _gate_name):
		_placed[kind] = true
		CardDrag.center_on(card, zone)
		card.disabled = true
		card.z_index = 5
		var needed := 2 if _gate_name == "NOT" else 3
		if _placed.size() == needed:
			_finish_round(true, "CIRCUIT COMPLETE!")
	else:
		card.position = card.get_meta("origin")
		show_feedback("WRONG CONNECTION!", UI.REJECT)
	_art.queue_redraw()


func _on_timeout() -> void:
	_finish_round(false, "TIME'S UP!")


func _show_result(_success: bool, _message: String) -> void:
	_drag.cancel()
	_art.queue_redraw()
	for card: Button in _cards:
		card.disabled = true


func _on_pause_changed(paused: bool) -> void:
	if paused:
		_drag.cancel()
		_art.queue_redraw()
