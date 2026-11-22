@tool
extends Node2D
class_name CrossingCampusLevel
## A normal Godot scene: native children are the authoritative level data.
const Data = preload("res://scripts/crossing/level_data.gd")
const Preview = preload("res://scripts/crossing/campus_canvas.gd")
signal runtime_ready(controller: Node)

@export var level_name := "Untitled crossing"
@export_range(40, 400, 5) var player_speed := 150.0
@export var allow_horizontal := true
@export var initial_variables: Dictionary = {"tokens": 0, "shields": 0}
@export var ground_rows: PackedStringArray = PackedStringArray(["path", "grass", "grass", "grass", "grass", "grass", "grass", "grass", "grass", "grass", "grass", "grass", "grass", "grass", "path"])
@export var level_metadata: Dictionary = {}

var preview: Control
var preview_timer := 0.0
var show_grid := true
## Set by the collection adapter before this scene enters the tree.
var embedded_runtime := false

func _ready() -> void:
	preview = Preview.new()
	preview.name = "_MapPreview"
	preview.size = Data.SIZE
	preview.font = ThemeDB.fallback_font
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(preview, false, Node.INTERNAL_MODE_BACK)
	refresh_preview()
	if not Engine.is_editor_hint() and not embedded_runtime:
		# F6 on an authored level uses the same adapter/lifecycle as the collection.
		var standalone_ui := CanvasLayer.new()
		standalone_ui.name = "StandaloneGameLayer"
		add_child(standalone_ui)
		var controller: Control = load("res://scripts/microgames/crossing.gd").new()
		controller.name = "GameController"
		controller.level_node = self
		controller.prompt = "CROSS"
		controller.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		standalone_ui.add_child(controller)
	set_process(Engine.is_editor_hint())

func _process(delta: float) -> void:
	preview_timer += delta
	if preview_timer >= 0.08:
		preview_timer = 0.0
		refresh_preview()

func refresh_preview() -> void:
	if is_instance_valid(preview):
		preview.level = to_data()
		# Runtime adapter takes ownership once its simulation has been initialized.
		preview.edit_mode = true
		preview.grid_visible = show_grid
		preview.queue_redraw()

func to_data() -> Dictionary:
	var data := Data.blank()
	data.name = level_name
	data.rules = {"player_speed": player_speed, "allow_horizontal": allow_horizontal}
	data.variables = initial_variables.duplicate(true)
	data.metadata = level_metadata.duplicate(true)
	for i in mini(15, ground_rows.size()):
		data.terrain[i] = str(ground_rows[i])
	for node in get_children():
		if node is CrossingRoadLane:
			var lane: Dictionary = node.to_data()
			if int(lane.row) >= 0 and int(lane.row) < 15:
				data.terrain[int(lane.row)] = "road"
			data.lanes.append(lane)
		elif node is CrossingLevelPiece:
			match node.kind:
				"start", "goal": data[node.kind] = node.cell()
				"item": data.items.append(node.to_data())
				_: data.obstacles.append(node.to_data())
	return data

func validate_scene() -> PackedStringArray:
	var errors := Data.validate(to_data())
	for node in get_children():
		if node is CrossingRoadLane:
			for event in node.events:
				if event == null: errors.append("%s has an empty vehicle event resource." % node.name)
	for kind in ["start", "goal"]:
		var count := 0
		for node in get_children():
			if node is CrossingLevelPiece and node.kind == kind: count += 1
		if count != 1: errors.append("The scene needs exactly one %s marker; found %d." % [kind, count])
	return errors

func _get_configuration_warnings() -> PackedStringArray:
	return validate_scene()
