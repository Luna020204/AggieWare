@tool
extends RefCounted
## Integration checks run inside the actual Godot editor, using its undo manager.
static func run(plugin: EditorPlugin) -> void:
	for i in 120:
		await plugin.get_tree().process_frame
		if plugin._level() != null: break
	var root: CrossingCampusLevel = plugin._level()
	if root == null:
		push_error("Native editor test: no level scene opened.")
		plugin.get_tree().quit(1)
		return
	var failures := 0
	var before := JSON.stringify(root.to_data())
	plugin.row_input.value = 3
	plugin._add_lane()
	var lane: CrossingRoadLane = plugin._selected()
	if lane == null or lane.to_data().row != 2:
		push_error("FAIL: native dock adds owned lane")
		failures += 1
	else:
		print("PASS: native dock adds owned lane")
	var manager := plugin.get_undo_redo()
	var history := manager.get_history_undo_redo(manager.get_object_history_id(root))
	history.undo()
	if JSON.stringify(root.to_data()) != before:
		push_error("FAIL: native undo restores scene")
		failures += 1
	else: print("PASS: native undo restores scene")
	history.redo()
	if lane.get_parent() != root:
		push_error("FAIL: native redo restores child")
		failures += 1
	else: print("PASS: native redo restores child")
	plugin.add_vehicle(lane, "scooter")
	if lane.events.size() != 3:
		push_error("FAIL: inspector action adds vehicle Resource")
		failures += 1
	else: print("PASS: inspector action adds vehicle Resource")
	history.undo()
	if lane.events.size() != 2:
		push_error("FAIL: vehicle Resource undo")
		failures += 1
	else: print("PASS: vehicle Resource undo")
	plugin._move_node(lane, Vector2(0, 40))
	if lane.position.y != 40:
		push_error("FAIL: move lane using native undo action")
		failures += 1
	else: print("PASS: move lane using native undo action")
	history.undo()
	history.undo()
	if JSON.stringify(root.to_data()) != before:
		push_error("FAIL: all native changes undo cleanly")
		failures += 1
	else: print("PASS: all native changes undo cleanly")
	# Exercise viewport selection and dragging with the actual editor pan/zoom transform.
	var piece: CrossingLevelPiece = root.get_node("bench_6_5")
	var initial := piece.position
	var transform := plugin.get_editor_interface().get_editor_viewport_2d().global_canvas_transform * root.get_global_transform()
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = transform * (initial + Vector2(20, 20))
	plugin._forward_canvas_gui_input(down)
	var motion := InputEventMouseMotion.new()
	motion.position = transform * (initial + Vector2(60, 20))
	plugin._forward_canvas_gui_input(motion)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = motion.position
	plugin._forward_canvas_gui_input(up)
	if piece.position != initial + Vector2(40, 0):
		push_error("FAIL: 2D viewport drag snaps to a cell")
		failures += 1
	else: print("PASS: 2D viewport drag snaps to a cell")
	history.undo()
	if piece.position != initial:
		push_error("FAIL: viewport drag supports native undo")
		failures += 1
	else: print("PASS: viewport drag supports native undo")
	plugin._select(root.get_node("lane_11"))
	plugin.get_editor_interface().set_main_screen_editor("2D")
	plugin.dock_shell.make_visible()
	for i in 10: await plugin.get_tree().process_frame
	var original_lane: CrossingRoadLane = root.get_node("lane_11")
	var timeline := _find_timeline(plugin.get_editor_interface().get_inspector(), original_lane)
	if timeline == null:
		push_error("FAIL: native Inspector exposes the traffic timeline")
		failures += 3
	else:
		print("PASS: native Inspector exposes the traffic timeline")
		var original_time := original_lane.events[0].spawn_time
		timeline.event_moved.emit(0, 0.9)
		if not is_equal_approx(original_lane.events[0].spawn_time, 0.9):
			push_error("FAIL: timeline edits the native vehicle Resource")
			failures += 1
		else: print("PASS: timeline edits the native vehicle Resource")
		history.undo()
		if not is_equal_approx(original_lane.events[0].spawn_time, original_time):
			push_error("FAIL: timeline editing supports native undo")
			failures += 1
		else: print("PASS: timeline editing supports native undo")
	if "--capture-native-editor" in OS.get_cmdline_user_args():
		plugin.get_tree().root.mode = Window.MODE_WINDOWED
		plugin.get_tree().root.size = Vector2i(1600, 1000)
	for i in 20: await plugin.get_tree().process_frame
	print("NATIVE EDITOR RESULT: 12 checks, ", failures, " failures")
	if "--capture-native-editor" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		var image := plugin.get_editor_interface().get_base_control().get_viewport().get_texture().get_image()
		var result := DirAccess.make_dir_recursive_absolute("res://artifacts")
		if result == OK:
			result = image.save_png("res://artifacts/native_editor.png")
		if result != OK:
			failures += 1
			push_error("Could not save the native editor screenshot.")
		print("Native editor screenshot: ", result)
	plugin.get_tree().quit(1 if failures else 0)

static func _find_timeline(node: Node, lane: Node) -> Control:
	if node.get_script() == load("res://scripts/crossing/timeline.gd") and node.source_lane == lane:
		return node as Control
	for child in node.get_children():
		var found := _find_timeline(child, lane)
		if found != null: return found
	return null
