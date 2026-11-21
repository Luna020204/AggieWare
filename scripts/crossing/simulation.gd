extends RefCounted
## Deterministic simulation used by playtest and tests, independent of editor UI.
const Data = preload("res://scripts/crossing/level_data.gd")
const Hooks = preload("res://scripts/crossing/game_hooks.gd")
const PLAYER_RADIUS := 10.0

var level: Dictionary = {}
var hooks: Node
var elapsed := 0.0
var player := Vector2.ZERO
var previous_player := Vector2.ZERO
var vehicles: Array[Dictionary] = []
var picked: Dictionary = {}
var state := "playing"
var invulnerable := 0.0
var notice := "Watch the traffic. Head north to the library."
var schedules: Array[Dictionary] = []
var vehicle_serial := 0

func start(data: Dictionary, event_bus: Node) -> void:
	level = data.duplicate(true)
	hooks = event_bus
	elapsed = 0.0
	player = Data.cell_center(level.start)
	previous_player = player
	vehicles.clear()
	picked.clear()
	schedules.clear()
	state = "playing"
	invulnerable = 0.0
	notice = "Watch the traffic. Head north to the library."
	vehicle_serial = 0
	for lane in level.lanes:
		for event in lane.events:
			schedules.append({"lane": lane, "event": event, "next": float(event.time)})
	hooks.begin(level)
	_spawn_until(0.0)

func tick(delta: float, movement: Vector2) -> void:
	if state != "playing" or delta <= 0.0:
		return
	# Bounded substeps also protect collision and pickup ordering at low frame rates.
	var remaining := minf(delta, 0.25)
	while remaining > 0.000001 and state == "playing":
		var step := minf(remaining, 1.0 / 120.0)
		_step(step, movement)
		remaining -= step

func _step(delta: float, movement: Vector2) -> void:
	invulnerable = maxf(0.0, invulnerable - delta)
	previous_player = player
	if not level.rules.allow_horizontal:
		movement.x = 0.0
	var velocity := movement.limit_length() * float(level.rules.player_speed) * delta
	_move_axis(Vector2(velocity.x, 0))
	_move_axis(Vector2(0, velocity.y))
	for car in vehicles:
		car.previous = car.position
		car.position.x += float(car.speed) * int(car.direction) * delta
	elapsed += delta
	_spawn_until(elapsed)
	for item in level.items:
		if not picked.has(item.id) and player.distance_to(Data.cell_center(item.cell)) < 21:
			picked[item.id] = true
			hooks.collect(item)
			notice = "Collected: %s" % item.type
	for car in vehicles:
		if invulnerable <= 0.0 and swept_hit(previous_player - car.previous, player - car.position, car.half_size + Vector2.ONE * PLAYER_RADIUS):
			hooks.vehicle_hit.emit(car.duplicate(true))
			var shields: Variant = hooks.variables.get("shields", 0)
			if (shields is float or shields is int) and float(shields) > 0:
				hooks.add_variable("shields", -1)
				invulnerable = 1.5
				notice = "Your shield absorbed a collision."
			else:
				state = "crashed"
				notice = "Collision! Press R to retry."
				return
	vehicles = vehicles.filter(func(car: Dictionary) -> bool: return car.position.x >= -80 and car.position.x <= Data.SIZE.x + 80)
	if player.distance_to(Data.cell_center(level.goal)) < 18.0:
		state = "won"
		notice = "You made it to the library!"
		hooks.run_finished.emit(elapsed, hooks.variables.duplicate(true))

func _move_axis(offset: Vector2) -> void:
	var candidate := player + offset
	candidate.x = clampf(candidate.x, PLAYER_RADIUS, Data.SIZE.x - PLAYER_RADIUS)
	candidate.y = clampf(candidate.y, PLAYER_RADIUS, Data.SIZE.y - PLAYER_RADIUS)
	for obstacle in level.obstacles:
		var center := Data.cell_center(obstacle.cell)
		if swept_hit(player - center, candidate - center, Vector2(25, 25)):
			return
	player = candidate

func _spawn_until(time: float) -> void:
	for schedule in schedules:
		while float(schedule.next) <= time + 0.000001:
			_spawn(schedule.lane, schedule.event, time - float(schedule.next))
			schedule.next = float(schedule.next) + float(schedule.lane.cycle)

func _spawn(lane: Dictionary, event: Dictionary, age: float) -> void:
	var definition: Dictionary = hooks.vehicle_types.get(str(event.type), {"half_size": Vector2(22, 10), "color": Color("ce9ddd")})
	# An explicit override is an absolute speed; only inherited speeds use the type multiplier.
	var speed: float = float(event.speed) if float(event.speed) > 0.0 else float(lane.speed) * float(definition.get("speed_multiplier", 1.0))
	var direction := int(lane.direction)
	var position := Vector2(-32 if direction == 1 else Data.SIZE.x + 32, (int(lane.row) + 0.5) * Data.CELL)
	position.x += speed * direction * age
	vehicle_serial += 1
	vehicles.append({"id": vehicle_serial, "event_id": event.id, "lane_id": lane.id,
		"type": event.type, "speed": speed, "direction": direction,
		"position": position, "previous": position, "half_size": definition.half_size,
		"color": definition.color})

static func swept_hit(from: Vector2, to: Vector2, half_size: Vector2) -> bool:
	# Segment/slab intersection in relative coordinates catches fast moving vehicles.
	var offset := to - from
	var entry := 0.0
	var exit_time := 1.0
	for axis in 2:
		if absf(offset[axis]) < 0.000001:
			if absf(from[axis]) > half_size[axis]:
				return false
		else:
			var a := (-half_size[axis] - from[axis]) / offset[axis]
			var b := (half_size[axis] - from[axis]) / offset[axis]
			entry = maxf(entry, minf(a, b))
			exit_time = minf(exit_time, maxf(a, b))
			if entry > exit_time:
				return false
	return true
