@tool
extends Control
## Drag event diamonds to edit their spawn time within the selected lane's cycle.
signal event_selected(index: int)
signal event_moved(index: int, time: float)
var lane: Dictionary = {}
var selected := -1
var font: Font
var dragging := -1
var preview_time := -1.0
var source_lane: Node
var refresh_timer := 0.0

func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func _process(delta: float) -> void:
	refresh_timer += delta
	if refresh_timer >= 0.1 and is_instance_valid(source_lane) and dragging < 0:
		refresh_timer = 0
		lane = source_lane.to_data()
		queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("142632"))
	if lane.is_empty():
		if font != null:
			draw_string(font, Vector2(18, 38), "Select a road lane to edit its spawn timeline", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("8ba3ae"))
		return
	var cycle := float(lane.cycle)
	draw_line(Vector2(26, 36), Vector2(size.x - 26, 36), Color("47606b"), 2)
	for i in 6:
		var x := 26 + (size.x - 52) * float(i) / 5.0
		draw_line(Vector2(x, 29), Vector2(x, 43), Color("617980"), 1)
		draw_string(font, Vector2(x - 8, 19), "%.1f" % (cycle * i / 5.0), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("8ba3ae"))
	for i in lane.events.size():
		var event: Dictionary = lane.events[i]
		var time := preview_time if dragging == i and preview_time >= 0 else float(event.time)
		var p := Vector2(26 + time / cycle * (size.x - 52), 36)
		var color := Color("e6bf69") if event.type == "bicycle" else Color("85ceca")
		if i == selected:
			draw_circle(p, 12, Color(0.95, 0.95, 0.83, 0.18))
		draw_colored_polygon(PackedVector2Array([p + Vector2(0, -8), p + Vector2(8, 0), p + Vector2(0, 8), p + Vector2(-8, 0)]), color)
		if i == selected:
			draw_string(font, p + Vector2(12, 5), "%.1fs" % time, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("e5eada"))

func _gui_input(event: InputEvent) -> void:
	if lane.is_empty():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var closest := 15.0
			for i in lane.events.size():
				var x := 26 + float(lane.events[i].time) / float(lane.cycle) * (size.x - 52)
				var distance := absf(event.position.x - x)
				if distance < closest:
					closest = distance
					dragging = i
			if dragging >= 0:
				selected = dragging
				event_selected.emit(dragging)
		else:
			if dragging >= 0 and preview_time >= 0:
				event_moved.emit(dragging, preview_time)
			dragging = -1
			preview_time = -1
		queue_redraw()
		accept_event()
	elif event is InputEventMouseMotion and dragging >= 0:
		preview_time = snappedf(clampf((event.position.x - 26) / (size.x - 52) * float(lane.cycle), 0, float(lane.cycle) - 0.1), 0.1)
		queue_redraw()
		accept_event()
