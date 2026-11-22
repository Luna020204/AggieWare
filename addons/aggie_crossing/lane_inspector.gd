@tool
extends EditorInspectorPlugin
const Timeline = preload("res://scripts/crossing/timeline.gd")
var plugin: EditorPlugin

func _can_handle(object: Object) -> bool:
	return object is CrossingRoadLane

func _parse_begin(object: Object) -> void:
	var lane: CrossingRoadLane = object
	var box := VBoxContainer.new()
	var title := Label.new()
	title.text = "TRAFFIC SCHEDULE"
	title.add_theme_color_override("font_color", Color("e9c778"))
	box.add_child(title)
	var timeline := Timeline.new()
	timeline.font = EditorInterface.get_editor_theme().default_font
	if timeline.font == null: timeline.font = ThemeDB.fallback_font
	timeline.custom_minimum_size = Vector2(230, 68)
	timeline.lane = lane.to_data()
	timeline.source_lane = lane
	timeline.tooltip_text = "Drag a diamond to change the spawn time. Time repeats once per Cycle Seconds."
	box.add_child(timeline)
	var selected := Label.new()
	selected.text = "Click a diamond to inspect that vehicle."
	selected.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	selected.custom_minimum_size.x = 200
	box.add_child(selected)
	var source_index := func(index: int) -> int:
		if index < 0 or index >= timeline.lane.events.size(): return -1
		return str(timeline.lane.events[index].id).trim_prefix("event_").to_int()
	timeline.event_selected.connect(func(index: int) -> void:
		var actual: int = source_index.call(index)
		if actual >= 0 and actual < lane.events.size() and lane.events[actual] != null:
			selected.text = "#%d  %s  /  %.1fs" % [actual + 1, lane.events[actual].vehicle_type, lane.events[actual].spawn_time])
	timeline.event_moved.connect(func(index: int, time: float) -> void:
		var actual: int = source_index.call(index)
		if actual < 0 or actual >= lane.events.size() or lane.events[actual] == null: return
		var history := plugin.get_undo_redo()
		history.create_action("Change vehicle spawn time", UndoRedo.MERGE_DISABLE, lane)
		history.add_do_property(lane.events[actual], "spawn_time", time)
		history.add_undo_property(lane.events[actual], "spawn_time", lane.events[actual].spawn_time)
		history.add_do_method(lane, "notify_property_list_changed")
		history.add_undo_method(lane, "notify_property_list_changed")
		history.commit_action())
	var row := HBoxContainer.new()
	box.add_child(row)
	for kind in ["bicycle", "scooter"]:
		var button := Button.new()
		button.text = "+ " + kind.capitalize()
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func() -> void: plugin.add_vehicle(lane, kind))
		row.add_child(button)
	var edit := Button.new()
	edit.text = "Inspect selected vehicle resource"
	edit.pressed.connect(func() -> void:
		var actual: int = source_index.call(timeline.selected)
		if actual >= 0 and actual < lane.events.size() and lane.events[actual] != null:
			EditorInterface.inspect_object(lane.events[actual]))
	box.add_child(edit)
	var hint := Label.new()
	hint.text = "Expand Events below to edit each resource.\nSpeed Override = 0: bicycles use Default Speed; scooters use 1.5x Default Speed.\nA nonzero override is the exact speed in px/s."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size.x = 200
	box.add_child(hint)
	add_custom_control(box)
