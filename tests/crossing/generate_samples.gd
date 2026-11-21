extends SceneTree
const Data = preload("res://scripts/crossing/level_data.gd")
const Codec = preload("res://addons/aggie_crossing/scene_codec.gd")

func _initialize() -> void:
	var demo := Data.blank()
	demo.name = "01 - The Library Run"
	demo.metadata = {"description": "A fictional campus crossing inspired by UC Davis; not a geographic map.", "author": "Aggie Crossing"}
	for row in [3, 4, 7, 8, 11, 12]:
		demo.terrain[row] = "road"
		var lane := Data.lane(row)
		lane.direction = 1 if row % 2 else -1
		lane.speed = 125.0 + (12 - row) * 5
		lane.cycle = 5.5 if row % 2 else 6.0
		lane.events = [
			{"id": "first", "type": "bicycle" if row % 2 else "scooter", "time": 0.0 if row % 2 else 1.3, "speed": 0.0},
			{"id": "second", "type": "scooter" if row % 2 else "bicycle", "time": 2.8 if row % 2 else 4.3, "speed": 0.0}]
		demo.lanes.append(lane)
	for row in [2, 6, 10, 13]:
		for col in [3, 4, 16, 17]:
			demo.obstacles.append({"id": "planter_%d_%d" % [col, row], "cell": [col, row], "kind": "planter"})
	for row in [1, 5, 9]:
		for col in [6, 14]:
			demo.obstacles.append({"id": "bench_%d_%d" % [col, row], "cell": [col, row], "kind": "bench"})
	demo.items = [
		{"id": "first_shield", "cell": [10, 13], "type": "shield", "properties": {"charges": 1}},
		{"id": "token_a", "cell": [10, 9], "type": "token", "properties": {"value": 1}},
		{"id": "token_b", "cell": [10, 5], "type": "token", "properties": {"value": 2}}]
	var error := Data.save_file("res://levels/crossing/campus_intro.json", demo)
	if not error.is_empty(): push_error(error); quit(1); return
	var empty := Data.blank()
	empty.name = "00 - Blank Template"
	error = Data.save_file("res://levels/crossing/blank_template.json", empty)
	if not error.is_empty(): push_error(error); quit(1); return
	var result := Codec.save_scene("res://scenes/crossing/campus_intro.tscn", demo)
	if result != OK: push_error("Cannot generate campus scene"); quit(1); return
	result = Codec.save_scene("res://scenes/crossing/blank_template.tscn", empty)
	if result != OK: push_error("Cannot generate blank scene"); quit(1); return
	print("Generated two validated native scenes and matching JSON examples.")
	quit()
