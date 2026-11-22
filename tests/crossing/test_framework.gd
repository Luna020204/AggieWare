extends SceneTree
const Data = preload("res://scripts/crossing/level_data.gd")
const Simulation = preload("res://scripts/crossing/simulation.gd")
const Hooks = preload("res://scripts/crossing/game_hooks.gd")
const Codec = preload("res://addons/aggie_crossing/scene_codec.gd")
var failures := 0
var checks := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)
	else:
		print("PASS: " + message)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var output_error := DirAccess.make_dir_recursive_absolute("res://artifacts")
	if output_error != OK:
		push_error("Could not create the test output directory.")
		quit(1)
		return
	var blank := Data.blank()
	check(Data.validate(blank).is_empty(), "Blank schema is valid")
	var malformed := blank.duplicate(true)
	malformed.start = [200, 4]
	check(not Data.validate(malformed).is_empty(), "Reject out-of-bounds start")
	malformed = blank.duplicate(true)
	malformed.terrain = "not an array"
	check(not Data.validate(malformed).is_empty(), "Reject malformed terrain without crashing")
	malformed = blank.duplicate(true)
	malformed.rules.player_speed = "fast"
	check(not Data.validate(malformed).is_empty(), "Reject nonnumeric rules")
	malformed = blank.duplicate(true)
	malformed.terrain[6] = "road"
	malformed.lanes = [Data.lane(6), Data.lane(6)]
	check(not Data.validate(malformed).is_empty(), "Reject duplicate lanes and IDs")
	malformed.lanes = [Data.lane(6)]
	malformed.lanes[0].events[0].time = 5.0
	check(not Data.validate(malformed).is_empty(), "Reject event at cycle boundary")
	malformed.lanes[0].events[0].time = -0.1
	check(not Data.validate(malformed).is_empty(), "Reject negative event time")
	malformed = blank.duplicate(true)
	malformed.goal = [11, 0]
	malformed.rules.allow_horizontal = false
	check(not Data.validate(malformed).is_empty(), "Vertical-only goal must align")
	var path := "res://artifacts/roundtrip.tmp.json"
	check(Data.save_file(path, blank).is_empty(), "Save level atomically")
	blank.name = "Overwrite check"
	check(Data.save_file(path, blank).is_empty(), "Overwrite existing level atomically")
	var loaded := Data.load_file(path)
	check(loaded.has("level") and loaded.level.name == blank.name, "Round-trip JSON")
	check(not Data.save_file(path, malformed).is_empty(), "Invalid save rejected")
	check(Data.load_file(path).level.name == blank.name, "Invalid save preserves previous file")
	DirAccess.remove_absolute(path)
	for fixture in ["campus_intro", "blank_template"]:
		var result := Data.load_file("res://levels/crossing/%s.json" % fixture)
		check(result.has("level"), "Valid fixture: " + fixture + (" / " + str(result.error) if result.has("error") else ""))
		check(result.get("level", {}).get("rules", {}).get("allow_horizontal", false), "JSON fixture enables horizontal movement: " + fixture)
		var saved_scene: Node = load("res://scenes/crossing/%s.tscn" % fixture).instantiate()
		check(saved_scene.allow_horizontal, "Native scene enables horizontal movement: " + fixture)
		saved_scene.free()
	var hooks := Hooks.new()
	root.add_child(hooks)
	var sim := Simulation.new()
	sim.start(blank, hooks)
	var original := JSON.stringify(blank)
	var initial_position := sim.player
	sim.tick(0.1, Vector2.RIGHT)
	check(sim.player.x > initial_position.x and sim.player.y == initial_position.y, "Default movement allows walking right")
	var right_position := sim.player
	sim.tick(0.1, Vector2.LEFT)
	check(sim.player.x < right_position.x and sim.player.y == initial_position.y, "Default movement allows walking left")
	check(sim.player.is_equal_approx(initial_position), "Left and right movement use equal speeds")
	sim.tick(0.1, Vector2.UP)
	check(sim.player.y < initial_position.y, "Player advances upward")
	var diagonal_start := sim.player
	sim.tick(0.1, Vector2(1, -1))
	var diagonal_distance := sim.player.distance_to(diagonal_start)
	# Vector2 uses float32; allow subpixel accumulation across the fixed substeps.
	check(absf(diagonal_distance - float(blank.rules.player_speed) * 0.1) < 0.001, "Diagonal movement keeps walking speed (%.6f px)" % diagonal_distance)
	var vertical_only := blank.duplicate(true)
	vertical_only.rules.allow_horizontal = false
	sim.start(vertical_only, hooks)
	sim.tick(0.1, Vector2.RIGHT)
	check(sim.player == initial_position, "Explicit vertical-only levels still restrict horizontal movement")
	sim.state = "paused"
	var paused_time: float = sim.elapsed
	sim.tick(0.2, Vector2.UP)
	check(sim.elapsed == paused_time, "Paused simulation freezes")
	sim.start(blank, hooks)
	for i in 20: sim.tick(0.25, Vector2.UP)
	check(sim.state == "won", "Reach goal triggers victory")
	check(JSON.stringify(blank) == original, "Playtest never mutates authoring data")
	var blocked := blank.duplicate(true)
	blocked.obstacles.append({"id": "wall", "cell": [10, 13], "kind": "barrier"})
	sim.start(blocked, hooks)
	for i in 5: sim.tick(0.2, Vector2.UP)
	check(sim.player.y >= 565, "Obstacle stops player")
	check(Simulation.swept_hit(Vector2(-100, 0), Vector2(100, 0), Vector2(20, 10)), "Swept collision catches tunneling")
	check(not Simulation.swept_hit(Vector2(-100, 50), Vector2(100, 50), Vector2(20, 10)), "Swept collision rejects parallel miss")
	var type_defaults := blank.duplicate(true)
	type_defaults.terrain[6] = "road"
	var type_lane := Data.lane(6)
	type_lane.speed = 120.0
	type_lane.events[1].time = 0.0
	type_defaults.lanes = [type_lane]
	sim.start(type_defaults, hooks)
	check(sim.vehicles[0].speed == 120.0 and sim.vehicles[1].speed == 180.0, "Inherited scooter speed is 1.5 times the bicycle baseline")
	var bike_start: Vector2 = sim.vehicles[0].position
	var scooter_start: Vector2 = sim.vehicles[1].position
	sim.tick(0.1, Vector2.ZERO)
	check(is_equal_approx(sim.vehicles[1].position.distance_to(scooter_start), sim.vehicles[0].position.distance_to(bike_start) * 1.5), "Scooter travels 1.5 times farther in the same time")
	type_lane.speed = 200.0
	sim.start(type_defaults, hooks)
	check(sim.vehicles[0].speed == 200.0 and sim.vehicles[1].speed == 300.0, "Changing lane speed preserves the default type speed ratio")
	type_lane.events[1].speed = 210.0
	sim.start(type_defaults, hooks)
	check(sim.vehicles[1].speed == 210.0, "Explicit scooter override is exact, without an additional multiplier")
	var traffic := blank.duplicate(true)
	traffic.terrain[6] = "road"
	var lane := Data.lane(6)
	lane.cycle = 2.0
	lane.speed = 100.0
	lane.events = [{"id": "first", "type": "bicycle", "time": 0.0, "speed": 0.0}, {"id": "second", "type": "scooter", "time": 1.0, "speed": 200.0}]
	traffic.lanes = [lane]
	sim.start(traffic, hooks)
	check(sim.vehicles.size() == 1, "Spawn time-zero event exactly once")
	for i in 4: sim.tick(0.25, Vector2.ZERO)
	check(sim.vehicle_serial == 2, "Spawn delayed event at t=1")
	check(sim.vehicles[1].speed == 200, "Per-vehicle speed overrides lane")
	for i in 4: sim.tick(0.25, Vector2.ZERO)
	check(sim.vehicle_serial == 3, "Cycle repeats without boundary double spawn")
	lane.direction = -1
	sim.start(traffic, hooks)
	var before: float = sim.vehicles[0].position.x
	sim.tick(0.1, Vector2.ZERO)
	check(sim.vehicles[0].position.x < before, "Negative direction travels left")
	var collision := blank.duplicate(true)
	collision.terrain[14] = "road"
	lane = Data.lane(14)
	lane.events = [{"id": "hit", "type": "bicycle", "time": 0.0, "speed": 600.0}]
	collision.lanes = [lane]
	sim.start(collision, hooks)
	for i in 4: sim.tick(0.25, Vector2.ZERO)
	check(sim.state == "crashed", "Vehicle collision ends run")
	collision.variables.shields = 1
	sim.start(collision, hooks)
	for i in 4: sim.tick(0.25, Vector2.ZERO)
	check(sim.state == "playing" and hooks.variables.shields == 0, "Shield absorbs one collision")
	var items := blank.duplicate(true)
	items.items = [{"id": "pickup", "cell": [10, 14], "type": "token", "properties": {"value": 3}}]
	sim.start(items, hooks)
	sim.tick(0.1, Vector2.ZERO)
	sim.tick(0.1, Vector2.ZERO)
	check(hooks.variables.tokens == 3, "Item collected once with configurable value")
	hooks.register_item_handler("coffee", func(item: Dictionary) -> void: hooks.set_variable("energy", item.properties.amount))
	items.items[0].type = "coffee"
	items.items[0].properties = {"amount": 7}
	sim.start(items, hooks)
	sim.tick(0.1, Vector2.ZERO)
	check(hooks.variables.energy == 7, "Custom item handler receives properties")
	sim.start(blank, hooks)
	check(not hooks.variables.has("energy") and hooks.variables.tokens == 0, "Restart resets runtime variables")
	hooks.register_vehicle_type("cart", Vector2(30, 12), Color.WHITE)
	traffic.lanes[0].events[0].type = "cart"
	sim.start(traffic, hooks)
	check(sim.vehicles[0].half_size == Vector2(30, 12), "Vehicle registry controls collision bounds")
	# Native scene data is authoritative. Test conversion without executing game logic.
	var authored: Dictionary = Data.load_file("res://levels/crossing/campus_intro.json").level
	var scene := Codec.from_data(authored)
	check(scene is CrossingCampusLevel, "JSON imports as a native level node")
	check(scene.validate_scene().is_empty(), "Native scene validates")
	var node_lane: CrossingRoadLane = scene.get_node("lane_11")
	check(node_lane.events.size() == 2 and node_lane.events[0] is CrossingVehicleEvent, "Schedules use native typed Resources")
	node_lane.position.y = 0
	check(scene.to_data().lanes[4].row == 0, "Moving a scene lane changes the authored row")
	node_lane.position.y = 440
	var marker: CrossingLevelPiece = scene.get_node("Start")
	scene.allow_horizontal = false
	marker.position.x = 440
	check(not scene.validate_scene().is_empty(), "Invalid native marker placement is reported")
	marker.position.x = 400
	scene.allow_horizontal = true
	var snapshot := JSON.stringify(scene.to_data())
	sim.start(scene.to_data(), hooks)
	sim.tick(0.2, Vector2.UP)
	check(JSON.stringify(scene.to_data()) == snapshot, "Runtime never modifies native authoring scene")
	var packed := PackedScene.new()
	check(packed.pack(scene) == OK, "Native scene packs with owned child nodes")
	var instance := packed.instantiate()
	check(instance.validate_scene().is_empty() and instance.to_data().items.size() == 3, "Packed scene round-trip preserves items and schedules")
	instance.free()
	scene.free()
	var extended := Codec.from_data(blank)
	var coffee := CrossingLevelPiece.new()
	coffee.name = "Coffee"
	coffee.kind = "item"
	coffee.item_type = "coffee"
	coffee.properties = {"energy": 25}
	coffee.position = Vector2(400, 560)
	extended.add_child(coffee)
	var extension := Node.new()
	extension.set_script(load("res://extensions/crossing/coffee_pickup.gd"))
	extended.add_child(extension)
	root.add_child(extended)
	await process_frame
	var controller: Node = extended.get_node("StandaloneGameLayer/GameController")
	check(controller._prompt_left > 0.0 and not controller._ended, "F6 authored level uses the shared microgame prompt")
	controller.simulation.tick(0.1, Vector2.ZERO)
	check(controller.hooks.variables.get("energy") == 25, "Example extension registers before the first run")
	extended.queue_free()
	hooks.queue_free()
	await process_frame
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
