@tool
extends Control
## Shared rendering for the native editor preview and the running game.
const Data = preload("res://scripts/crossing/level_data.gd")

var level: Dictionary = {}
var simulation: RefCounted
var edit_mode := true
var grid_visible := true
var font: Font
var clock := 0.0
var show_state_overlay := true

func _ready() -> void:
	clip_contents = true

func _process(delta: float) -> void:
	clock += delta
	if not edit_mode:
		queue_redraw()

func _draw() -> void:
	if level.is_empty():
		return
	for row in Data.ROWS:
		_draw_row(row)
	# A subtle path keeps the default vertical crossing legible.
	var route_x := (float(level.start[0]) + 0.5) * Data.CELL
	if level.start[0] == level.goal[0]:
		for y in range(20, 600, 16):
			draw_circle(Vector2(route_x, y), 1.4, Color(0.99, 0.95, 0.76, 0.25))
	for obstacle in level.obstacles:
		_draw_obstacle(Data.cell_center(obstacle.cell), str(obstacle.kind))
	for item in level.items:
		if edit_mode or simulation == null or not simulation.picked.has(item.id):
			_draw_item(Data.cell_center(item.cell), str(item.type))
	_draw_marker(Data.cell_center(level.goal), true)
	_draw_marker(Data.cell_center(level.start), false)
	if edit_mode:
		for lane in level.lanes:
			for i in lane.events.size():
				var event: Dictionary = lane.events[i]
				var fraction := float(event.time) / float(lane.cycle)
				var x := 100 + fraction * 640
				if int(lane.direction) == -1:
					x = Data.SIZE.x - x
				var p := Vector2(x, (float(lane.row) + 0.5) * Data.CELL)
				_draw_vehicle(p, str(event.type), int(lane.direction), Color("e1bd6d") if event.type == "bicycle" else Color("83c9c7"))
				_text(p + Vector2(25, 5), "%.1fs" % float(event.time), 10, Color("d9e3e3"))
		_draw_player(Data.cell_center(level.start), false)
	else:
		for car in simulation.vehicles:
			_draw_vehicle(car.position, str(car.type), int(car.direction), car.color)
		_draw_player(simulation.player, simulation.invulnerable > 0)
		if show_state_overlay and simulation.state in ["crashed", "won", "paused", "ready"]:
			_draw_overlay()
	if edit_mode:
		if grid_visible:
			for col in range(1, Data.COLS):
				draw_line(Vector2(col * 40, 0), Vector2(col * 40, 600), Color(0.08, 0.18, 0.18, 0.12))
			for row in range(1, Data.ROWS):
				draw_line(Vector2(0, row * 40), Vector2(840, row * 40), Color(0.08, 0.18, 0.18, 0.12))
	draw_rect(Rect2(0, 0, 840, 600), Color("5d7773"), false, 2)

func _draw_row(row: int) -> void:
	var y := float(row) * 40
	var kind: String = level.terrain[row]
	if kind == "road":
		draw_rect(Rect2(0, y, 840, 40), Color("4c5c62") if row % 2 else Color("526168"))
		if row == 0 or level.terrain[row - 1] != "road":
			draw_rect(Rect2(0, y, 840, 3), Color("afbbb1"))
		else:
			for x in range(12, 840, 40):
				draw_line(Vector2(x, y), Vector2(x + 20, y), Color("c0c8b0"), 1.2)
		if row == 14 or level.terrain[row + 1] != "road":
			draw_rect(Rect2(0, y + 37, 840, 3), Color("afbbb1"))
		var route_x := float(level.start[0]) * 40
		for stripe in 4:
			draw_rect(Rect2(route_x + 4, y + 4 + stripe * 9, 32, 4), Color(0.91, 0.91, 0.80, 0.40))
		var index := Data.lane_at(level, row)
		if index >= 0:
			var direction := int(level.lanes[index].direction)
			_arrow(Vector2(26 if direction == 1 else 814, y + 20), direction, Color("b9c8c5"))
			_text(Vector2(54, y + 33), "%02d" % (row + 1), 9, Color("9eadae"))
	elif kind == "path":
		draw_rect(Rect2(0, y, 840, 40), Color("c6c7b2"))
		draw_line(Vector2(0, y), Vector2(840, y), Color("b0b7a2"))
		for x in range(0, 840, 80):
			draw_line(Vector2(x + (40 if row % 2 else 0), y), Vector2(x + (40 if row % 2 else 0), y + 40), Color("b4bba5"))
	else:
		draw_rect(Rect2(0, y, 840, 40), Color("8ba88b") if row % 2 else Color("91ac8e"))
		for x in range(12, 840, 57):
			var p := Vector2(x + (row * 7) % 24, y + 10 + (x * 13) % 21)
			draw_line(p, p + Vector2(2, -3), Color("789979"), 1)
			draw_line(p + Vector2(3, 0), p + Vector2(4, -2), Color("789979"), 1)
		# Decorative foliage stays at the far edges, clear of the crossing route.
		if row in [1, 5, 9, 13]:
			_tree(Vector2(20, y + 20))
			_tree(Vector2(822, y + 18))

func _tree(p: Vector2) -> void:
	draw_circle(p + Vector2(4, 5), 17, Color(0.12, 0.25, 0.20, 0.18))
	draw_circle(p, 15, Color("537c61"))
	draw_circle(p + Vector2(-5, -4), 10, Color("628e6c"))
	draw_circle(p + Vector2(6, 2), 8, Color("739c75"))

func _draw_marker(p: Vector2, goal: bool) -> void:
	draw_rect(Rect2(p - Vector2(18, 18), Vector2(36, 36)), Color(0.09, 0.22, 0.26, 0.42))
	draw_rect(Rect2(p - Vector2(18, 18), Vector2(36, 36)), Color("f0cc73") if goal else Color("cde9d3"), false, 2)
	if goal:
		draw_line(p + Vector2(-7, 11), p + Vector2(-7, -12), Color("f8efd6"), 2)
		draw_colored_polygon(PackedVector2Array([p + Vector2(-6, -12), p + Vector2(10, -8), p + Vector2(-6, -3)]), Color("f0cc73"))
		_text(p + Vector2(30, 5), "SHIELDS LIBRARY / FINISH", 12, Color("1c3e3e"))
	else:
		_text(p + Vector2(30, 5), "START / HEAD NORTH", 12, Color("294744"))

func _draw_obstacle(p: Vector2, kind: String) -> void:
	draw_rect(Rect2(p + Vector2(-14, -11), Vector2(31, 29)), Color(0.12, 0.23, 0.22, 0.25))
	if kind == "planter":
		draw_rect(Rect2(p - Vector2(15, 15), Vector2(30, 30)), Color("b7b19a"))
		draw_rect(Rect2(p - Vector2(12, 12), Vector2(24, 24)), Color("527e62"))
		draw_circle(p + Vector2(-5, -3), 8, Color("699a72"))
		draw_circle(p + Vector2(5, 4), 8, Color("80a27b"))
		draw_circle(p + Vector2(4, -6), 2.5, Color("edc981"))
	elif kind == "bench":
		for y in [-10, -2, 6]:
			draw_rect(Rect2(p + Vector2(-16, y), Vector2(32, 5)), Color("bc9565"))
		for x in [-11, 11]:
			draw_line(p + Vector2(x, -14), p + Vector2(x, 14), Color("384e4d"), 3)
	else:
		draw_rect(Rect2(p - Vector2(16, 12), Vector2(32, 24)), Color("d8bb6c"))
		for x in [-10, 2, 14]:
			draw_line(p + Vector2(x - 8, 10), p + Vector2(x + 2, -10), Color("4d5552"), 4)

func _draw_item(p: Vector2, type_id: String) -> void:
	draw_circle(p, 15, Color(0.99, 0.91, 0.63, 0.18))
	if type_id == "shield":
		var points := PackedVector2Array([p + Vector2(-9, -9), p + Vector2(9, -9), p + Vector2(8, 3), p + Vector2(0, 11), p + Vector2(-8, 3)])
		draw_colored_polygon(points, Color("8ed8d2"))
		draw_line(p + Vector2(0, -5), p + Vector2(0, 5), Color("315861"), 2)
	else:
		draw_circle(p, 9, Color("f0cc73"))
		draw_arc(p, 6, 0, TAU, 18, Color("b3833e"), 1.5, true)
		_text(p + Vector2(-3, 4), "$" if type_id == "token" else "?", 12, Color("6e552d"))

func _draw_player(p: Vector2, shielded: bool) -> void:
	if shielded:
		draw_arc(p, 18 + sin(clock * 8), 0, TAU, 28, Color("9ee9e1"), 2.5, true)
	draw_circle(p + Vector2(2, 5), 11, Color(0.07, 0.14, 0.18, 0.25))
	var walk := sin(clock * 12) * 2.0 if not edit_mode and simulation.player != simulation.previous_player else 0.0
	draw_line(p + Vector2(-5, 7), p + Vector2(-5, 12 + walk), Color("273747"), 5)
	draw_line(p + Vector2(5, 7), p + Vector2(5, 12 - walk), Color("273747"), 5)
	draw_circle(p + Vector2(-9, 1), 4, Color("d5a77c"))
	draw_circle(p + Vector2(9, 1), 4, Color("d5a77c"))
	draw_rect(Rect2(p + Vector2(-8, -4), Vector2(16, 15)), Color("244e71"))
	draw_rect(Rect2(p + Vector2(-6, 2), Vector2(12, 10)), Color("e9c66f"))
	draw_line(p + Vector2(-3, 3), p + Vector2(-3, 10), Color("b89548"), 1)
	draw_circle(p + Vector2(0, -6), 7, Color("d9ad81"))
	draw_arc(p + Vector2(0, -6), 6, PI, TAU, 12, Color("403e36"), 5, true)

func _draw_vehicle(p: Vector2, type_id: String, direction: int, color: Color) -> void:
	draw_set_transform(p, 0, Vector2(direction, 1))
	draw_line(Vector2(-19, 5), Vector2(20, 5), Color(0.08, 0.16, 0.18, 0.25), 7, true)
	if type_id == "bicycle":
		for x in [-17, 17]:
			draw_line(Vector2(x - 7, 0), Vector2(x + 7, 0), Color("1e3038"), 4, true)
			draw_line(Vector2(x - 5, 0), Vector2(x + 5, 0), Color("a6b4b0"), 1, true)
		draw_polyline(PackedVector2Array([Vector2(-17, 0), Vector2(-3, -4), Vector2(9, 0), Vector2(-17, 0)]), color, 2.5, true)
		draw_line(Vector2(9, 0), Vector2(17, 0), color, 3)
		draw_line(Vector2(13, -9), Vector2(13, 9), Color("1e3038"), 2.5)
	else:
		draw_line(Vector2(-18, 0), Vector2(18, 0), Color("243c45"), 5, true)
		draw_line(Vector2(-14, 0), Vector2(9, 0), color, 5, true)
		draw_line(Vector2(14, -9), Vector2(14, 9), Color("243c45"), 3, true)
		draw_circle(Vector2(18, 0), 2, Color("e8d998"))
	draw_line(Vector2(-1, -6), Vector2(11, -8), Color("d5ae87"), 3, true)
	draw_line(Vector2(-1, 6), Vector2(11, 8), Color("d5ae87"), 3, true)
	draw_line(Vector2(-7, -5), Vector2(-2, 5), Color("314355"), 4, true)
	draw_circle(Vector2(-3, 0), 8, color)
	draw_circle(Vector2(1, 0), 5.5, Color("e4e6da"))
	draw_line(Vector2(0, -4), Vector2(0, 4), Color("869e9e"), 1.3)
	draw_set_transform(Vector2.ZERO)

func _arrow(p: Vector2, direction: int, color: Color) -> void:
	draw_line(p - Vector2(9 * direction, 0), p + Vector2(9 * direction, 0), color, 2, true)
	draw_polyline(PackedVector2Array([p + Vector2(3 * direction, -5), p + Vector2(9 * direction, 0), p + Vector2(3 * direction, 5)]), color, 2, true)

func _text(p: Vector2, value: String, size_px: int, color: Color) -> void:
	if font != null:
		draw_string(font, p, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, color)

func _draw_overlay() -> void:
	draw_rect(Rect2(0, 0, 840, 600), Color(0.04, 0.10, 0.15, 0.58))
	var title := "MADE IT TO CLASS!" if simulation.state == "won" else ("PAUSED" if simulation.state == "paused" else "WATCH THE TRAFFIC")
	if simulation.state == "ready": title = "READY FOR CLASS?"
	var width := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
	_text(Vector2(420 - width / 2, 279), title, 30, Color("f0cc73"))
	var sub := "Space to resume" if simulation.state == "paused" else "R to retry"
	if simulation.state == "ready":
		sub = "Press WASD / arrow keys or Space to start" if simulation.level.rules.allow_horizontal else "Press W / UP or Space to start"
	width = font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	_text(Vector2(420 - width / 2, 318), sub, 16, Color("e5ece6"))
