extends RefCounted
## Full-screen runtime scenery. Map positions scale; pixel actors keep their shape.
## Native editor previews continue to use the original 840 x 600 drawing path.
const Data = preload("res://scripts/crossing/level_data.gd")
const INK := Color("14121a")
const BLUE := Color("022851")
const GOLD := Color("ffbf00")
const PIXEL := 5.0

var _canvas: Control
var _mapping := Vector2.ONE
var _view := Vector2(1280, 720)
var _facing := Vector2.UP


func draw_world(canvas: Control, level: Dictionary, simulation: RefCounted, clock: float, view_size: Vector2) -> void:
	_canvas = canvas
	_view = view_size
	_mapping = view_size / Data.SIZE
	for row: int in Data.ROWS:
		_draw_ground(level, row)
	_draw_campus_details(level)
	for obstacle: Dictionary in level.obstacles:
		_draw_obstacle(_map(Data.cell_center(obstacle.cell)), str(obstacle.kind))
	for item: Dictionary in level.items:
		if simulation == null or not simulation.picked.has(item.id):
			_draw_pickup(_map(Data.cell_center(item.cell)), str(item.type))
	_draw_start(_map(Data.cell_center(level.start)))
	_draw_goal(_map(Data.cell_center(level.goal)))
	if simulation != null:
		for vehicle: Dictionary in simulation.vehicles:
			_draw_vehicle(_map(vehicle.position), str(vehicle.type), int(vehicle.direction), vehicle.color)
		var movement: Vector2 = simulation.player - simulation.previous_player
		if simulation.elapsed <= 0.0001:
			_facing = Vector2.UP
		elif movement.length_squared() > 0.0001:
			_facing = movement.normalized()
		_draw_student(_map(simulation.player), movement.length_squared() > 0.0001, simulation.invulnerable > 0.0, clock)
	else:
		_draw_student(_map(Data.cell_center(level.start)), false, false, clock)


func _map(point: Vector2) -> Vector2:
	return point * _mapping


func _box(rect: Rect2, color: Color) -> void:
	var origin := (rect.position / PIXEL).floor() * PIXEL
	var extent := (rect.size / PIXEL).ceil() * PIXEL
	_canvas.draw_rect(Rect2(origin, extent), color)


func _line(from: Vector2, to: Vector2, color: Color, width: float = PIXEL) -> void:
	_canvas.draw_line((from / PIXEL).round() * PIXEL, (to / PIXEL).round() * PIXEL, color, width, false)


func _draw_ground(level: Dictionary, row: int) -> void:
	var top := float(row) * Data.CELL * _mapping.y
	var height := Data.CELL * _mapping.y
	var terrain := str(level.terrain[row])
	if terrain == "road":
		_box(Rect2(0, top, _view.x, height), Color("35444d") if row % 2 == 0 else Color("3c4b54"))
		for mark in range(0, int(_view.x), 95):
			_box(Rect2(mark + (row * 17) % 55, top + 12, 5, 5), Color("46565b"))
			_box(Rect2(mark + 35, top + height - 12, 10, 5), Color("2f3b45"))
		if row == 0 or str(level.terrain[row - 1]) != "road":
			_box(Rect2(0, top, _view.x, 5), Color("c2bea0"))
			_box(Rect2(0, top + 5, _view.x, 5), Color("52605e"))
		else:
			for dash in range(15, int(_view.x), 75):
				_box(Rect2(dash, top, 35, 5), Color("c6bd92"))
		if row == Data.ROWS - 1 or str(level.terrain[row + 1]) != "road":
			_box(Rect2(0, top + height - 5, _view.x, 5), Color("b8b59b"))
		var crossing_x := _map(Data.cell_center(level.start)).x
		for stripe in range(5, int(height) - 4, 15):
			_box(Rect2(crossing_x - 25, top + stripe, 50, 7), Color("babaa1"))
		var lane_index := Data.lane_at(level, row)
		var direction := int(level.lanes[lane_index].direction) if lane_index >= 0 else 1
		for fraction in [0.12, 0.86]:
			_draw_direction(Vector2(_view.x * fraction, top + height * 0.5), direction)
	elif terrain == "path":
		_box(Rect2(0, top, _view.x, height), Color("a8a58b"))
		_box(Rect2(0, top, _view.x, 5), Color("73796c"))
		for tile in range(0, int(_view.x), 80):
			var left := tile + (40 if row % 2 == 0 else 0)
			_box(Rect2(left, top + 5, 5, height - 5), Color("8c927b"))
			_box(Rect2(left + 10, top + 10, 20, 5), Color("b9b79a"))
	else:
		_box(Rect2(0, top, _view.x, height), Color("637e4c") if row % 2 == 0 else Color("6d8551"))
		for tuft in range(0, int(_view.x), 55):
			var x := tuft + (row * 11) % 35
			var y := top + 8 + (tuft + row * 7) % maxi(10, int(height) - 15)
			_box(Rect2(x, y, 10, 5), Color("4b6945"))
			_box(Rect2(x + 5, y - 5, 5, 5), Color("88a264"))
			if (tuft + row) % 4 == 0:
				_box(Rect2(x + 25, y + 5, 5, 5), Color("789057"))


func _draw_direction(at: Vector2, direction: int) -> void:
	var paint := Color("8c9a91")
	_line(at + Vector2(-20 * direction, 0), at + Vector2(20 * direction, 0), paint, 5)
	_line(at + Vector2(10 * direction, -10), at + Vector2(20 * direction, 0), paint, 5)
	_line(at + Vector2(10 * direction, 10), at + Vector2(20 * direction, 0), paint, 5)


func _draw_campus_details(level: Dictionary) -> void:
	for row: int in Data.ROWS:
		if str(level.terrain[row]) == "grass":
			var y := (row + 0.5) * Data.CELL * _mapping.y
			if row % 3 == 1:
				_draw_tree(Vector2(25, y), row)
				_draw_tree(Vector2(_view.x - 20, y), row + 1)
			else:
				for x in [55.0, 105.0, _view.x - 85.0, _view.x - 135.0]:
					_draw_flower(Vector2(x, y), row)
	# Overhanging branches provide natural contrast behind upper-left status text.
	_draw_tree(Vector2(35, 15), 1)
	_draw_tree(Vector2(125, 5), 0)
	_draw_tree(Vector2(215, 10), 1)
	if str(level.terrain[Data.ROWS - 1]) == "path":
		var parking_y := _view.y - 25
		for rack in 3:
			var left := 100.0 + rack * 60
			_line(Vector2(left, parking_y - 10), Vector2(left, parking_y + 10), INK, 10)
			_line(Vector2(left, parking_y - 10), Vector2(left + 25, parking_y - 10), Color("adbab0"), 5)
			_line(Vector2(left + 25, parking_y - 10), Vector2(left + 25, parking_y + 10), Color("adbab0"), 5)
	# Stone entry edges frame the library-side finish without adding collisions.
	if str(level.terrain[0]) == "path":
		_box(Rect2(_view.x - 210, 0, 210, 15), Color("50676b"))
		_box(Rect2(_view.x - 210, 15, 210, 10), Color("c3baa0"))
		for column in range(int(_view.x) - 195, int(_view.x), 45):
			_box(Rect2(column, 0, 20, 20), Color("8b9785"))


func _draw_tree(at: Vector2, variant: int) -> void:
	_box(Rect2(at + Vector2(-35, 20), Vector2(80, 20)), Color(0.06, 0.10, 0.10, 0.35))
	_box(Rect2(at + Vector2(-5, 10), Vector2(15, 25)), Color("614332"))
	_box(Rect2(at + Vector2(-30, -30), Vector2(65, 65)), INK)
	_box(Rect2(at + Vector2(-45, -15), Vector2(95, 35)), INK)
	_box(Rect2(at + Vector2(-30, -40), Vector2(50, 15)), INK)
	_box(Rect2(at + Vector2(-25, -30), Vector2(55, 60)), Color("315941"))
	_box(Rect2(at + Vector2(-40, -10), Vector2(85, 25)), Color("315941"))
	_box(Rect2(at + Vector2(-25, -35), Vector2(40, 15)), Color("4e794b"))
	_box(Rect2(at + Vector2(-30, -20), Vector2(55, 20)), Color("4e794b"))
	for patch in 5:
		var x := -25 + (patch * 13 + variant * 10) % 55
		var y := -25 + (patch * 17) % 45
		_box(Rect2(at + Vector2(x, y), Vector2(10, 5)), Color("719459") if patch % 2 else Color("244b3c"))


func _draw_flower(at: Vector2, variant: int) -> void:
	_box(Rect2(at + Vector2(-5, 0), Vector2(5, 15)), Color("315b3c"))
	_box(Rect2(at + Vector2(-10, 5), Vector2(15, 5)), Color("456b3f"))
	_box(Rect2(at + Vector2(-10, -5), Vector2(15, 5)), Color("d9b77a") if variant % 2 else Color("ba87a1"))
	_box(Rect2(at + Vector2(-5, -10), Vector2(5, 15)), Color("ead19a") if variant % 2 else Color("d0a1b7"))
	_box(Rect2(at + Vector2(-5, -5), Vector2(5, 5)), GOLD)


func _draw_obstacle(at: Vector2, kind: String) -> void:
	_box(Rect2(at + Vector2(-20, 15), Vector2(50, 10)), Color(0.06, 0.10, 0.10, 0.4))
	if kind == "planter":
		_box(Rect2(at + Vector2(-25, -20), Vector2(50, 45)), INK)
		_box(Rect2(at + Vector2(-20, -15), Vector2(40, 35)), Color("a17b56"))
		_box(Rect2(at + Vector2(-15, -15), Vector2(30, 25)), Color("315941"))
		_box(Rect2(at + Vector2(-10, -15), Vector2(20, 15)), Color("6f9458"))
		_draw_flower(at + Vector2(0, -5), 1)
	elif kind == "bench":
		_box(Rect2(at + Vector2(-25, -15), Vector2(50, 35)), INK)
		for slat in 3:
			_box(Rect2(at + Vector2(-25, -10 + slat * 10), Vector2(50, 5)), Color("c29a62") if slat != 2 else Color("9a714b"))
		_box(Rect2(at + Vector2(-20, -20), Vector2(5, 45)), Color("435052"))
		_box(Rect2(at + Vector2(15, -20), Vector2(5, 45)), Color("435052"))
	else:
		_box(Rect2(at + Vector2(-25, -15), Vector2(50, 35)), INK)
		_box(Rect2(at + Vector2(-25, -10), Vector2(50, 20)), Color("d0a65c"))
		for stripe in 3:
			_line(at + Vector2(-25 + stripe * 20, 10), at + Vector2(-10 + stripe * 20, -10), Color("384246"), 10)
		_box(Rect2(at + Vector2(-20, 15), Vector2(10, 10)), INK)
		_box(Rect2(at + Vector2(10, 15), Vector2(10, 10)), INK)


func _draw_pickup(at: Vector2, kind: String) -> void:
	if kind == "shield":
		_box(Rect2(at + Vector2(-15, -15), Vector2(30, 25)), INK)
		_box(Rect2(at + Vector2(-10, 5), Vector2(20, 10)), INK)
		_box(Rect2(at + Vector2(-5, 15), Vector2(10, 5)), INK)
		_box(Rect2(at + Vector2(-10, -10), Vector2(20, 20)), Color("69babc"))
		_box(Rect2(at + Vector2(-5, 5), Vector2(10, 10)), Color("69babc"))
		_box(Rect2(at + Vector2(-5, -10), Vector2(5, 15)), Color("c9e6d1"))
	elif kind == "token":
		_box(Rect2(at + Vector2(-10, -15), Vector2(20, 30)), INK)
		_box(Rect2(at + Vector2(-15, -10), Vector2(30, 20)), INK)
		_box(Rect2(at + Vector2(-10, -10), Vector2(20, 20)), GOLD)
		_box(Rect2(at + Vector2(-5, -5), Vector2(10, 10)), Color("b78340"))
		_box(Rect2(at + Vector2(-10, -10), Vector2(5, 15)), Color("ffe1a0"))
	else:
		_box(Rect2(at + Vector2(-10, -10), Vector2(25, 30)), INK)
		_box(Rect2(at + Vector2(-5, -5), Vector2(15, 20)), Color("d5c49a"))
		_box(Rect2(at + Vector2(15, -5), Vector2(10, 15)), Color("ad946d"))
		_box(Rect2(at + Vector2(-10, -15), Vector2(25, 5)), Color("80533e"))


func _draw_start(at: Vector2) -> void:
	_line(at + Vector2(0, 10), at + Vector2(0, -10), Color("ced5b8"), 10)
	_line(at + Vector2(-10, 0), at + Vector2(0, -10), Color("ced5b8"), 5)
	_line(at + Vector2(10, 0), at + Vector2(0, -10), Color("ced5b8"), 5)


func _draw_goal(at: Vector2) -> void:
	at = at.clamp(Vector2(30, 30), _view - Vector2(35, 30))
	_box(Rect2(at + Vector2(-30, 15), Vector2(60, 10)), Color("7e8e79"))
	_box(Rect2(at + Vector2(-20, 20), Vector2(40, 5)), Color("d5ceb0"))
	_box(Rect2(at + Vector2(-20, -25), Vector2(10, 50)), INK)
	_box(Rect2(at + Vector2(-15, -25), Vector2(5, 50)), Color("e7ddbd"))
	_box(Rect2(at + Vector2(-10, -25), Vector2(40, 25)), BLUE)
	_box(Rect2(at + Vector2(-5, -20), Vector2(30, 15)), GOLD)
	_box(Rect2(at + Vector2(5, -20), Vector2(10, 15)), Color("d9a444"))


func _draw_vehicle(at: Vector2, kind: String, direction: int, accent: Color) -> void:
	# Horizontal wheel silhouettes and a visible frame distinguish bikes from scooters.
	_box(Rect2(at + Vector2(-35, 10), Vector2(75, 10)), Color(0.04, 0.08, 0.10, 0.35))
	for x in [-30, 30]:
		_box(Rect2(at + Vector2(x - 10, -5), Vector2(20, 10)), INK)
		_box(Rect2(at + Vector2(x - 5, -5), Vector2(10, 5)), Color("929f9e"))
	if kind == "bicycle":
		var back := at + Vector2(-30 * direction, 0)
		var seat := at + Vector2(-10 * direction, -10)
		var pedal := at + Vector2(5 * direction, 5)
		var fork := at + Vector2(25 * direction, -5)
		_line(back, seat, accent, 5)
		_line(seat, pedal, accent, 5)
		_line(pedal, back, accent, 5)
		_line(seat, fork, accent, 5)
		_line(pedal, fork, accent, 5)
		_line(fork, at + Vector2(30 * direction, 0), Color("b1bcb3"), 5)
		_box(Rect2(at + Vector2(-20 * direction - 5, -15), Vector2(15, 5)), INK)
	else:
		_box(Rect2(at + Vector2(-25, -5), Vector2(45, 15)), INK)
		_box(Rect2(at + Vector2(-20, -5), Vector2(40, 5)), accent)
		_line(at + Vector2(20 * direction, 0), at + Vector2(30 * direction, -10), accent, 5)
		_box(Rect2(at + Vector2(-20 * direction, 5), Vector2(15, 5)), Color("c0cdc5"))
	_line(at + Vector2(25 * direction, -15), at + Vector2(25 * direction, 15), INK, 5)
	_line(at + Vector2(-5 * direction, -10), at + Vector2(20 * direction, -15), Color("c6a27d"), 5)
	_line(at + Vector2(-5 * direction, 10), at + Vector2(20 * direction, 15), Color("c6a27d"), 5)
	_box(Rect2(at + Vector2(-20 * direction - 5, -10), Vector2(20, 25)), BLUE if kind == "bicycle" else Color("7b596e"))
	_box(Rect2(at + Vector2(-10 * direction - 5, -10), Vector2(15, 20)), accent)
	_box(Rect2(at + Vector2(0, -10), Vector2(15, 20)), INK)
	_box(Rect2(at + Vector2(0, -10), Vector2(10, 15)), Color("e4ddbf"))
	_box(Rect2(at + Vector2(5 * direction, -5), Vector2(5, 10)), Color("a4bab5"))


func _draw_student(at: Vector2, walking: bool, shielded: bool, clock: float) -> void:
	# Keep the sprite and shield inside the frame; simulation coordinates are unchanged.
	at = at.clamp(Vector2(35, 40), _view - Vector2(35, 40))
	var step := 5.0 if walking and int(clock * 8.0) % 2 == 0 else 0.0
	_box(Rect2(at + Vector2(-20, 15), Vector2(45, 15)), Color(0.05, 0.08, 0.12, 0.35))
	if shielded:
		for corner in [Vector2(-30, -30), Vector2(20, -30), Vector2(-30, 25), Vector2(20, 25)]:
			_box(Rect2(at + corner, Vector2(15, 5)), Color("91d8cd"))
			_box(Rect2(at + corner, Vector2(5, 15)), Color("91d8cd"))
	_box(Rect2(at + Vector2(-15, 10), Vector2(15, 15 + step)), INK)
	_box(Rect2(at + Vector2(5, 10), Vector2(15, 20 - step)), INK)
	_box(Rect2(at + Vector2(-10, 10), Vector2(10, 10 + step)), Color("4e627c"))
	_box(Rect2(at + Vector2(5, 10), Vector2(10, 15 - step)), Color("4e627c"))
	_box(Rect2(at + Vector2(-20, -10), Vector2(40, 30)), INK)
	_box(Rect2(at + Vector2(-15, -5), Vector2(30, 20)), BLUE)
	_box(Rect2(at + Vector2(-25, -5), Vector2(10, 20)), INK)
	_box(Rect2(at + Vector2(15, -5), Vector2(10, 20)), INK)
	_box(Rect2(at + Vector2(-20, 0), Vector2(5, 10)), Color("d6a77e"))
	_box(Rect2(at + Vector2(15, 0), Vector2(5, 10)), Color("d6a77e"))
	_box(Rect2(at + Vector2(-15, -30), Vector2(30, 25)), INK)
	_box(Rect2(at + Vector2(-10, -25), Vector2(20, 20)), Color("d6a77e"))
	_box(Rect2(at + Vector2(-10, -25), Vector2(20, 10)), Color("594239"))
	_box(Rect2(at + Vector2(-15, -20), Vector2(5, 15)), Color("594239"))
	if _facing.y > 0.2:
		_box(Rect2(at + Vector2(-5, -15), Vector2(5, 5)), INK)
		_box(Rect2(at + Vector2(5, -15), Vector2(5, 5)), INK)
		_box(Rect2(at + Vector2(-5, 0), Vector2(10, 5)), GOLD)
	else:
		_box(Rect2(at + Vector2(-10, 0), Vector2(20, 20)), Color("d5a543"))
		_box(Rect2(at + Vector2(-5, 5), Vector2(15, 10)), GOLD)
		_box(Rect2(at + Vector2(-5, 15), Vector2(15, 5)), Color("a87939"))
