@tool
extends EditorPlugin
const Data = preload("res://scripts/crossing/level_data.gd")
const Codec = preload("res://addons/aggie_crossing/scene_codec.gd")
const LaneInspector = preload("res://addons/aggie_crossing/lane_inspector.gd")

var dock: VBoxContainer
var dock_shell: EditorDock
var status: Label
var row_input: SpinBox
var column_input: SpinBox
var inspector_plugin: EditorInspectorPlugin
var dialog: FileDialog
var purpose := ""
var pending_data: Dictionary = {}
var dragging: Node2D
var drag_origin := Vector2.ZERO
var press_position := Vector2.ZERO

func _enter_tree() -> void:
	dock = VBoxContainer.new()
	dock.name = "Campus Tools"
	dock.custom_minimum_size.x = 250
	var heading := Label.new()
	heading.text = "CAMPUS LEVEL TOOLS"
	heading.add_theme_color_override("font_color", Color("e9c778"))
	dock.add_child(heading)
	_hint("Build your level in the 2D viewport. Select a lane to edit its traffic in the Inspector.")
	var file_row := HBoxContainer.new()
	dock.add_child(file_row)
	_button(file_row, "New level", _new_level)
	_button(file_row, "Validate", _validate)
	dock.add_child(HSeparator.new())
	row_input = _coordinate("Row", 15, 12)
	column_input = _coordinate("Column", 21, 11)
	_button(dock, "Move selection to this cell", _move_selection)
	_button(dock, "+ Road lane at this row", _add_lane)
	var terrain_row := HBoxContainer.new()
	dock.add_child(terrain_row)
	_button(terrain_row, "Paint grass row", func() -> void: _paint_terrain("grass"))
	_button(terrain_row, "Paint path row", func() -> void: _paint_terrain("path"))
	dock.add_child(HSeparator.new())
	var objects := GridContainer.new()
	objects.columns = 2
	dock.add_child(objects)
	for kind in ["planter", "bench", "barrier", "item", "start", "goal"]:
		_button(objects, "+ " + kind.capitalize(), func() -> void: _add_piece(kind))
	var traffic := HBoxContainer.new()
	dock.add_child(traffic)
	_button(traffic, "+ Bicycle", func() -> void: _add_selected_vehicle("bicycle"))
	_button(traffic, "+ Scooter", func() -> void: _add_selected_vehicle("scooter"))
	dock.add_child(HSeparator.new())
	var grid := CheckBox.new()
	grid.text = "Show preview grid"
	grid.button_pressed = true
	grid.toggled.connect(func(value: bool) -> void:
		var root := _level()
		if root != null: root.show_grid = value; root.refresh_preview())
	dock.add_child(grid)
	_button(dock, "Select level settings", func() -> void:
		var root := _level()
		if root != null: _select(root))
	var interchange := HBoxContainer.new()
	dock.add_child(interchange)
	_button(interchange, "Import JSON", _import_json)
	_button(interchange, "Export JSON", _export_json)
	_hint("Ctrl+S saves the .tscn scene.\nCtrl+Z uses Godot's native undo.\nF6 plays this scene. F5 plays the main scene.\nIn preview, vehicle icons show spawn order, not their starting positions.")
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size.x = 235
	status.text = "Open scenes/crossing/campus_intro.tscn to begin."
	dock.add_child(status)
	dock_shell = EditorDock.new()
	dock_shell.title = "Campus Tools"
	dock_shell.layout_key = "AggieCrossingTools"
	dock_shell.default_slot = EditorDock.DOCK_SLOT_LEFT_BR
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.x = 255
	dock.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(dock)
	dock_shell.add_child(scroll)
	add_dock(dock_shell)
	inspector_plugin = LaneInspector.new()
	inspector_plugin.plugin = self
	add_inspector_plugin(inspector_plugin)
	dialog = FileDialog.new()
	dialog.size = Vector2i(850, 560)
	dialog.file_selected.connect(_file_selected)
	get_editor_interface().get_base_control().add_child(dialog)
	get_editor_interface().get_selection().selection_changed.connect(_selection_changed)
	set_input_event_forwarding_always_enabled()
	if "--test-native-editor" in OS.get_cmdline_user_args():
		load("res://tests/crossing/native_editor_test.gd").run.call_deferred(self)

func _exit_tree() -> void:
	if is_instance_valid(dragging): dragging.position = drag_origin
	remove_inspector_plugin(inspector_plugin)
	remove_dock(dock_shell)
	dock_shell.queue_free()
	dialog.queue_free()

func _hint(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 235
	dock.add_child(label)

func _button(parent: Node, text: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(callback)
	parent.add_child(button)

func _coordinate(title: String, maximum: int, initial: int) -> SpinBox:
	var row := HBoxContainer.new()
	dock.add_child(row)
	var label := Label.new()
	label.text = title + " (1-based)"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var spin := SpinBox.new()
	spin.min_value = 1
	spin.max_value = maximum
	spin.value = initial
	spin.custom_minimum_size.x = 95
	row.add_child(spin)
	return spin

func _level() -> CrossingCampusLevel:
	var root := get_editor_interface().get_edited_scene_root()
	return root as CrossingCampusLevel

func _cell_position() -> Vector2:
	return Vector2(column_input.value - 1, row_input.value - 1) * 40

func _selected() -> Node:
	var selection := get_editor_interface().get_selection().get_selected_nodes()
	return selection[0] if selection.size() == 1 else null

func _select(node: Node) -> void:
	get_editor_interface().get_selection().clear()
	get_editor_interface().get_selection().add_node(node)
	get_editor_interface().edit_node(node)

func _selection_changed() -> void:
	var node := _selected()
	if node is CrossingRoadLane or node is CrossingLevelPiece:
		row_input.value = roundi(node.position.y / 40) + 1
		column_input.value = roundi(node.position.x / 40) + 1 if node is CrossingLevelPiece else column_input.value
		status.text = "Selected: " + str(node.name)
	update_overlays()

func _add_node(node: Node2D, title: String) -> void:
	var root := _level()
	if root == null:
		node.free()
		status.text = "Open a CrossingCampusLevel scene first."
		return
	var history := get_undo_redo()
	history.create_action(title, UndoRedo.MERGE_DISABLE, root)
	history.add_do_method(root, "add_child", node, true)
	history.add_do_property(node, "owner", root)
	history.add_do_reference(node)
	history.add_undo_method(root, "remove_child", node)
	history.commit_action()
	_select(node)

func _add_lane() -> void:
	var root := _level()
	if root == null: status.text = "Open a CrossingCampusLevel scene first."; return
	var row := int(row_input.value) - 1
	for child in root.get_children():
		if child is CrossingRoadLane and roundi(child.position.y / 40) == row:
			_select(child)
			status.text = "This row already has a road lane."
			return
	var lane := CrossingRoadLane.new()
	lane.name = "RoadLane"
	lane.position = Vector2(0, row * 40)
	for i in 2:
		var event := CrossingVehicleEvent.new()
		event.resource_local_to_scene = true
		event.vehicle_type = "bicycle" if i == 0 else "scooter"
		event.spawn_time = i * 2.5
		lane.events.append(event)
	_add_node(lane, "Add road lane")

func _add_piece(kind: String) -> void:
	var root := _level()
	if root == null: status.text = "Open a CrossingCampusLevel scene first."; return
	for child in root.get_children():
		if child is CrossingLevelPiece:
			if kind in ["start", "goal"] and child.kind == kind:
				_move_node(child, _cell_position())
				_select(child)
				return
			if child.position == _cell_position() and (child.kind == kind or (not kind in ["start", "goal"] and not child.kind in ["start", "goal"])):
				status.text = "This cell already contains an object. Move or delete it first."
				_select(child)
				return
	var node := CrossingLevelPiece.new()
	node.name = kind.capitalize()
	node.kind = kind
	node.position = _cell_position()
	_add_node(node, "Add " + kind)

func _move_selection() -> void:
	var node := _selected()
	if node is CrossingRoadLane or node is CrossingLevelPiece:
		_move_node(node, Vector2(0, _cell_position().y) if node is CrossingRoadLane else _cell_position())
	else: status.text = "Select a road lane, obstacle, item, start, or goal."

func _move_node(node: Node2D, target: Vector2) -> void:
	if node.position == target: return
	var history := get_undo_redo()
	history.create_action("Move crossing object", UndoRedo.MERGE_DISABLE, node)
	history.add_do_property(node, "position", target)
	history.add_undo_property(node, "position", node.position)
	history.commit_action()

func _paint_terrain(kind: String) -> void:
	var root := _level()
	if root == null: status.text = "Open a CrossingCampusLevel scene first."; return
	var terrain := root.ground_rows.duplicate()
	terrain[int(row_input.value) - 1] = kind
	var history := get_undo_redo()
	history.create_action("Paint ground row", UndoRedo.MERGE_DISABLE, root)
	history.add_do_property(root, "ground_rows", terrain)
	history.add_undo_property(root, "ground_rows", root.ground_rows)
	history.commit_action()
	status.text = "Ground painted. Road nodes render above the ground; delete the lane to remove a road."

func _add_selected_vehicle(kind: String) -> void:
	var node := _selected()
	if node is CrossingRoadLane: add_vehicle(node, kind)
	else: status.text = "Select a road lane first."

func add_vehicle(lane: CrossingRoadLane, kind: String) -> void:
	if lane.events.size() >= 64: status.text = "A lane supports up to 64 events."; return
	var events: Array[CrossingVehicleEvent] = lane.events.duplicate()
	var event := CrossingVehicleEvent.new()
	event.resource_local_to_scene = true
	event.resource_name = kind.capitalize()
	event.vehicle_type = kind
	event.spawn_time = 0.0 if events.is_empty() else minf(events[-1].spawn_time + 1.0, lane.cycle_seconds - 0.1)
	events.append(event)
	var history := get_undo_redo()
	history.create_action("Add " + kind + " spawn", UndoRedo.MERGE_DISABLE, lane)
	history.add_do_property(lane, "events", events)
	history.add_undo_property(lane, "events", lane.events.duplicate())
	history.add_do_method(lane, "notify_property_list_changed")
	history.add_undo_method(lane, "notify_property_list_changed")
	history.commit_action()

func _validate() -> void:
	var root := _level()
	if root == null: status.text = "Open a CrossingCampusLevel scene first."; return
	var errors := root.validate_scene()
	status.text = "Validation passed. Press F6 to play this level." if errors.is_empty() else "\n".join(errors)
	if errors.is_empty() and not root.allow_horizontal:
		var data := root.to_data()
		for obstacle in data.obstacles:
			if obstacle.cell[0] == data.start[0] and obstacle.cell[1] > mini(data.start[1], data.goal[1]) and obstacle.cell[1] < maxi(data.start[1], data.goal[1]):
				status.text += "\nDesign warning: an obstacle blocks the vertical route."
				break

func _new_level() -> void:
	pending_data = Data.blank()
	_scene_save_dialog()

func _scene_save_dialog() -> void:
	purpose = "scene"
	dialog.access = FileDialog.ACCESS_RESOURCES
	dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	dialog.filters = PackedStringArray(["*.tscn ; Godot level scene"])
	dialog.current_dir = "res://scenes/crossing"
	dialog.current_file = "new_crossing.tscn"
	dialog.title = "Create a native Godot level scene"
	dialog.popup_centered()

func _import_json() -> void:
	purpose = "import"
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.filters = PackedStringArray(["*.json ; Crossing level data"])
	dialog.current_dir = ProjectSettings.globalize_path("res://levels/crossing")
	dialog.title = "Import JSON as a new scene"
	dialog.popup_centered()

func _export_json() -> void:
	var root := _level()
	if root == null: return
	var errors := root.validate_scene()
	if not errors.is_empty(): status.text = "\n".join(errors); return
	pending_data = root.to_data()
	purpose = "export"
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	dialog.filters = PackedStringArray(["*.json ; Crossing level data"])
	dialog.current_dir = ProjectSettings.globalize_path("res://levels/crossing")
	dialog.current_file = "my_crossing.json"
	dialog.title = "Export level data"
	dialog.popup_centered()

func _file_selected(path: String) -> void:
	match purpose:
		"import":
			var loaded := Data.load_file(path)
			if loaded.has("error"): status.text = loaded.error; return
			pending_data = loaded.level
			_scene_save_dialog.call_deferred()
		"scene":
			var result := Codec.save_scene(path, pending_data)
			if result != OK: status.text = "Could not save scene: " + str(result); return
			get_editor_interface().get_resource_filesystem().scan()
			get_editor_interface().open_scene_from_path(path)
			status.text = "Created " + path.get_file()
		"export":
			var error := Data.save_file(path, pending_data)
			status.text = "Exported " + path.get_file() if error.is_empty() else error

func _handles(object: Object) -> bool:
	return object is CrossingCampusLevel or object is CrossingRoadLane or object is CrossingLevelPiece

func _make_visible(visible: bool) -> void:
	if visible and is_instance_valid(dock_shell): dock_shell.make_visible()

func _forward_canvas_gui_input(event: InputEvent) -> bool:
	var root := _level()
	if root == null or not event is InputEventMouse: return false
	# The 2D editor's canvas transform includes pan and zoom.
	var viewport := get_editor_interface().get_editor_viewport_2d()
	var local: Vector2 = root.get_global_transform().affine_inverse() * (viewport.global_canvas_transform.affine_inverse() * event.position)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if event.alt_pressed or event.ctrl_pressed or event.shift_pressed: return false
			if not Rect2(Vector2.ZERO, Data.SIZE).has_point(local): return false
			var cell := Vector2i(floori(local.x / 40), floori(local.y / 40))
			var target: Node2D = null
			for node in root.get_children():
				if node is CrossingLevelPiece and node.cell() == [cell.x, cell.y]: target = node; break
				if node is CrossingRoadLane and roundi(node.position.y / 40) == cell.y: target = node
			row_input.value = cell.y + 1
			column_input.value = cell.x + 1
			if target != null:
				dragging = target
				drag_origin = target.position
				press_position = local
				_select(target)
			else:
				_select(root)
			return true
		elif is_instance_valid(dragging):
			var target := dragging.position
			dragging.position = drag_origin
			_move_node(dragging, target)
			dragging = null
			return true
	elif event is InputEventMouseMotion and is_instance_valid(dragging):
		var target := (drag_origin + local - press_position).snapped(Vector2(40, 40))
		target.x = 0 if dragging is CrossingRoadLane else clampf(target.x, 0, 800)
		target.y = clampf(target.y, 0, 560)
		dragging.position = target
		update_overlays()
		return true
	return false

func _forward_canvas_draw_over_viewport(overlay: Control) -> void:
	var root := _level()
	var node := _selected()
	if root == null or not (node is CrossingRoadLane or node is CrossingLevelPiece): return
	var transform := get_editor_interface().get_editor_viewport_2d().global_canvas_transform * root.get_global_transform()
	var bounds := Rect2(node.position, Vector2(840, 40) if node is CrossingRoadLane else Vector2(40, 40))
	var rect := Rect2(transform * bounds.position, bounds.size * transform.get_scale())
	overlay.draw_rect(rect, Color("efc970"), false, 2)
