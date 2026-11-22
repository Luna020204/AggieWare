@tool
extends RefCounted
## Optional JSON interchange; .tscn scenes remain the native authoring format.
const Level = preload("res://addons/aggie_crossing/campus_level.gd")
const Lane = preload("res://addons/aggie_crossing/road_lane.gd")
const Piece = preload("res://addons/aggie_crossing/level_piece.gd")
const Event = preload("res://addons/aggie_crossing/vehicle_event.gd")

static func from_data(data: Dictionary) -> Node2D:
	var root := Level.new()
	root.name = "CampusLevel"
	root.level_name = str(data.name)
	root.player_speed = float(data.rules.player_speed)
	root.allow_horizontal = bool(data.rules.allow_horizontal)
	root.initial_variables = data.variables.duplicate(true)
	root.level_metadata = data.metadata.duplicate(true)
	root.ground_rows = PackedStringArray(data.terrain)
	for i in root.ground_rows.size():
		if root.ground_rows[i] == "road": root.ground_rows[i] = "grass"
	for lane in data.lanes:
		var node := Lane.new()
		node.name = str(lane.id).validate_node_name()
		node.position = Vector2(0, int(lane.row) * 40)
		node.direction = int(lane.direction)
		node.default_speed = float(lane.speed)
		node.cycle_seconds = float(lane.cycle)
		for event in lane.events:
			var resource := Event.new()
			resource.resource_local_to_scene = true
			resource.resource_name = str(event.type).capitalize()
			resource.vehicle_type = str(event.type) if event.type in ["bicycle", "scooter"] else "custom"
			resource.custom_type = str(event.type) if resource.vehicle_type == "custom" else ""
			resource.spawn_time = float(event.time)
			resource.speed_override = float(event.speed)
			node.events.append(resource)
		root.add_child(node, true)
		node.owner = root
	for kind in ["start", "goal"]:
		var node := Piece.new()
		node.name = kind.capitalize()
		node.kind = kind
		node.position = Vector2(data[kind][0], data[kind][1]) * 40
		root.add_child(node, true)
		node.owner = root
	for key in ["obstacles", "items"]:
		for entry in data[key]:
			var node := Piece.new()
			node.name = str(entry.id).validate_node_name()
			node.kind = "item" if key == "items" else str(entry.kind)
			node.position = Vector2(entry.cell[0], entry.cell[1]) * 40
			if key == "items":
				node.item_type = str(entry.type)
				node.properties = entry.properties.duplicate(true)
			root.add_child(node, true)
			node.owner = root
	return root

static func save_scene(path: String, data: Dictionary) -> Error:
	var root := from_data(data)
	var packed := PackedScene.new()
	var result := packed.pack(root)
	if result == OK: result = ResourceSaver.save(packed, path)
	root.free()
	return result
