extends RefCounted
## JSON is the public level format. Keep migrations here, outside the editor/runtime.

const SCHEMA_VERSION := 1
const COLS := 21
const ROWS := 15
const CELL := 40.0
const SIZE := Vector2(840, 600)

static func blank() -> Dictionary:
	var terrain: Array = []
	for row in ROWS:
		terrain.append("path" if row in [0, 14] else "grass")
	return {
		"schema_version": SCHEMA_VERSION, "name": "Untitled crossing",
		"grid": {"columns": COLS, "rows": ROWS, "cell_size": int(CELL)},
		"terrain": terrain, "start": [10, 14], "goal": [10, 0],
		"lanes": [], "obstacles": [], "items": [],
		"rules": {"player_speed": 150.0, "allow_horizontal": true},
		"variables": {"tokens": 0, "shields": 0}, "metadata": {}
	}

static func lane(row: int) -> Dictionary:
	return {"id": "lane_%d" % row, "row": row, "direction": 1,
		"speed": 145.0, "cycle": 5.0, "events": [
			{"id": "bike_1", "type": "bicycle", "time": 0.0, "speed": 0.0},
			{"id": "scooter_1", "type": "scooter", "time": 2.5, "speed": 0.0}
		]}

static func cell_center(cell: Array) -> Vector2:
	return Vector2(float(cell[0]) + 0.5, float(cell[1]) + 0.5) * CELL

static func lane_at(level: Dictionary, row: int) -> int:
	for i in level.lanes.size():
		if int(level.lanes[i].row) == row:
			return i
	return -1

static func object_at(objects: Array, cell: Array) -> int:
	for i in objects.size():
		if objects[i].cell == cell:
			return i
	return -1

static func _number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))

static func _cell_ok(value: Variant) -> bool:
	return value is Array and value.size() == 2 and _number(value[0]) and _number(value[1]) and float(value[0]) == int(value[0]) and float(value[1]) == int(value[1]) and int(value[0]) >= 0 and int(value[0]) < COLS and int(value[1]) >= 0 and int(value[1]) < ROWS

static func validate(data: Variant) -> PackedStringArray:
	var errors := PackedStringArray()
	if not data is Dictionary:
		return PackedStringArray(["The level root must be a JSON object."])
	if data.get("schema_version") != SCHEMA_VERSION:
		errors.append("Unsupported schema_version. Expected 1.")
	if not data.get("name") is String or str(data.get("name", "")).length() > 80:
		errors.append("name must be a string of up to 80 characters.")
	var grid: Variant = data.get("grid")
	if not grid is Dictionary or grid.get("columns") != COLS or grid.get("rows") != ROWS or grid.get("cell_size") != CELL:
		errors.append("This version uses a 21 x 15 grid with 40-pixel cells.")
	var terrain: Variant = data.get("terrain")
	if not terrain is Array or terrain.size() != ROWS:
		errors.append("terrain must contain exactly 15 rows.")
	else:
		for kind in terrain:
			if not kind in ["road", "grass", "path"]:
				errors.append("Terrain must be road, grass, or path.")
	for key in ["start", "goal"]:
		if not _cell_ok(data.get(key)):
			errors.append("%s must be integer coordinates [column, row] inside the grid." % key)
	for key in ["lanes", "obstacles", "items"]:
		if not data.get(key) is Array:
			errors.append("%s must be an array." % key)
		elif data[key].size() > 300:
			errors.append("%s may contain at most 300 objects." % key)
	for key in ["rules", "variables", "metadata"]:
		if not data.get(key) is Dictionary:
			errors.append("%s must be an object." % key)
	if not errors.is_empty():
		return errors
	if data.start == data.goal:
		errors.append("Start and goal cannot occupy the same cell.")
	if not _number(data.rules.get("player_speed")) or float(data.rules.player_speed) < 40.0 or float(data.rules.player_speed) > 400.0:
		errors.append("Player speed must be between 40 and 400.")
	if not data.rules.get("allow_horizontal") is bool:
		errors.append("allow_horizontal must be a boolean.")
	elif not data.rules.allow_horizontal and data.start[0] != data.goal[0]:
		errors.append("Start and goal must share a column when horizontal movement is disabled.")
	var used_rows: Array = []
	var ids: Array = []
	for entry in data.lanes:
		if not entry is Dictionary:
			errors.append("Each lane must be an object.")
			continue
		var row: Variant = entry.get("row")
		if not _number(row) or float(row) != int(row) or int(row) < 0 or int(row) >= ROWS:
			errors.append("Lane row must be an integer inside the grid.")
			continue
		if int(row) in used_rows or terrain[int(row)] != "road":
			errors.append("Only one lane is allowed per row, on road terrain.")
		used_rows.append(int(row))
		_check_id(entry, ids, errors)
		if not _number(entry.get("direction")) or (float(entry.direction) != -1.0 and float(entry.direction) != 1.0):
			errors.append("direction must be -1 or 1.")
		if not _number(entry.get("speed")) or float(entry.speed) < 30 or float(entry.speed) > 600:
			errors.append("Lane speed must be between 30 and 600.")
		if not _number(entry.get("cycle")) or float(entry.cycle) < 0.5 or float(entry.cycle) > 120:
			errors.append("Cycle length must be between 0.5 and 120 seconds.")
			continue
		if not entry.get("events") is Array or entry.events.size() > 64:
			errors.append("Each lane needs an events array with up to 64 entries.")
			continue
		var event_ids: Array = []
		for event in entry.events:
			if not event is Dictionary:
				errors.append("Each spawn event must be an object.")
				continue
			_check_id(event, event_ids, errors)
			if not event.get("type") is String or str(event.get("type", "")).is_empty():
				errors.append("Vehicle type must be a nonempty string.")
			if not _number(event.get("time")) or float(event.time) < 0 or float(event.time) >= float(entry.cycle):
				errors.append("Spawn time must satisfy 0 <= time < cycle.")
			if not _number(event.get("speed")) or (float(event.speed) != 0.0 and (float(event.speed) < 30 or float(event.speed) > 600)):
				errors.append("Vehicle speed must be 0 (inherit lane) or between 30 and 600.")
	for key in ["obstacles", "items"]:
		var occupied: Array = []
		for entry in data[key]:
			if not entry is Dictionary:
				errors.append("Entries in %s must be objects." % key)
				continue
			_check_id(entry, ids, errors)
			if not _cell_ok(entry.get("cell")):
				errors.append("Coordinates in %s must be inside the grid." % key)
			elif entry.cell in occupied:
				errors.append("Two objects of the same category cannot share a cell.")
			else:
				occupied.append(entry.cell)
			if key == "items" and (not entry.get("type") is String or not entry.get("properties") is Dictionary):
				errors.append("Items need a type string and a properties object.")
			elif key == "items" and entry.type in ["token", "shield"]:
				var property_name := "value" if entry.type == "token" else "charges"
				var amount: Variant = entry.properties.get(property_name, 1)
				if not _number(amount) or float(amount) < 0 or float(amount) > 1000:
					errors.append("The built-in item property %s must be a number from 0 to 1000." % property_name)
			if key == "obstacles" and not entry.get("kind") in ["planter", "bench", "barrier"]:
				errors.append("Obstacle kind must be planter, bench, or barrier.")
	for obstacle in data.obstacles:
		if obstacle is Dictionary and obstacle.get("cell") in [data.start, data.goal]:
			errors.append("Obstacles cannot occupy the start or goal.")
		if obstacle is Dictionary:
			for item in data.items:
				if item is Dictionary and obstacle.get("cell") == item.get("cell"):
					errors.append("Items cannot overlap obstacles.")
	return errors

static func _check_id(entry: Dictionary, ids: Array, errors: PackedStringArray) -> void:
	var value: Variant = entry.get("id")
	if not value is String or str(value).is_empty() or value in ids:
		errors.append("Object IDs must be nonempty, unique strings.")
	ids.append(value)

static func load_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"error": "File not found: " + path}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"error": "Unable to read the file."}
	if file.get_length() > 2_000_000:
		return {"error": "The level file exceeds 2 MB."}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return {"error": "JSON line %d: %s" % [parser.get_error_line(), parser.get_error_message()]}
	var errors := validate(parser.data)
	if not errors.is_empty():
		return {"error": "\n".join(errors)}
	# Godot's JSON parser returns all numbers as floats; normalize structural integers.
	for key in ["start", "goal"]:
		parser.data[key] = [int(parser.data[key][0]), int(parser.data[key][1])]
	for entry in parser.data.lanes:
		entry.row = int(entry.row)
		entry.direction = int(entry.direction)
	for key in ["obstacles", "items"]:
		for entry in parser.data[key]:
			entry.cell = [int(entry.cell[0]), int(entry.cell[1])]
	return {"level": parser.data}

static func save_file(path: String, data: Dictionary) -> String:
	var errors := validate(data)
	if not errors.is_empty():
		return "\n".join(errors)
	# Write alongside the destination, then rename; a failed write preserves the old file.
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return "Cannot write to this directory. Choose a writable location."
	file.store_string(JSON.stringify(data, "\t") + "\n")
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK:
		return "Write failed. The previous file was preserved."
	var result := DirAccess.rename_absolute(temporary, path)
	if result != OK:
		return "Could not replace the destination (error %d). The previous file was preserved." % result
	return ""
