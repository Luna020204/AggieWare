extends MicrogameBase
## Adapter between native crossing levels and AggieWare's common round lifecycle.
const Simulation = preload("res://scripts/crossing/simulation.gd")
const Hooks = preload("res://scripts/crossing/game_hooks.gd")
const UI = preload("res://scripts/ui/microgame_ui.gd")
const DURATIONS: Array[float] = [14.0, 12.0, 10.0]

@export var level_scene: PackedScene = preload("res://scenes/crossing/campus_intro.tscn")

var simulation := Simulation.new()
var hooks: Node
## Supplied directly when pressing F6 on an authored CrossingCampusLevel scene.
var level_node: CrossingCampusLevel
var _status_label: Label
var _timer_label: Label
var _inventory_label: Label
var _level_error := ""

func get_round_seconds() -> float:
	return DURATIONS[clampi(difficulty, 0, 2)]

func _build_ui() -> void:
	# Header helper creates the background. For authored-scene F6 the board lives
	# in the lower canvas, so keep that background transparent.
	var external_level := is_instance_valid(level_node)
	var header := UI.build_header(self, "CAMPUS CROSSING", "Dodge the bikes and scooters. Reach the library before time runs out.", show_internal_timer)
	_timer_label = header.timer
	if external_level:
		for child in get_children():
			if child is ColorRect: child.visible = false
	hooks = Hooks.new()
	hooks.name = "GameHooks"
	add_child(hooks)
	if not external_level:
		if level_scene == null:
			_level_error = "No crossing level scene is configured."
		else:
			var candidate := level_scene.instantiate()
			if candidate is CrossingCampusLevel:
				level_node = candidate
				level_node.embedded_runtime = true
				add_child(level_node)
			else:
				candidate.free()
				_level_error = "Level Scene must contain a CrossingCampusLevel root."
	if is_instance_valid(level_node):
		level_node.position = Vector2(304, 190)
		level_node.scale = Vector2(0.8, 0.8)
		level_node.preview.show_state_overlay = false
		level_node.runtime_ready.emit(self)
	UI.panel(self, Rect2(48, 248, 220, 270))
	UI.label(self, "CROSS CAMPUS", Vector2(66, 264), 20, UI.ACCENT, Vector2(184, 32))
	var instructions := UI.label(self, "Move in all four directions.\n\nWait for a gap in traffic.\n\nReach the flag to win.", Vector2(66, 310), 17, UI.TEXT, Vector2(184, 160))
	instructions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_inventory_label = UI.label(self, "", Vector2(64, 540), 18, UI.MUTED, Vector2(205, 72))
	_status_label = UI.label(self, "", Vector2(304, 676), 18, UI.MUTED, Vector2(900, 36))
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _reset_game() -> void:
	if is_instance_valid(level_node):
		var errors := level_node.validate_scene()
		_level_error = "\n".join(errors)
	if not _level_error.is_empty():
		push_error("Crossing level: " + _level_error)
		_finish_round(false, "Invalid level. Check Campus Tools > Validate.")
		return
	simulation.start(level_node.to_data(), hooks)
	level_node.preview.level = simulation.level
	level_node.preview.simulation = simulation
	level_node.preview.edit_mode = false
	level_node.preview.grid_visible = false
	UI.set_status(_status_label, "Find a safe gap and head north.")
	_update_inventory()
	_timer_label.text = "Time: %.1f" % _seconds_left

func _update_game(delta: float) -> void:
	var movement := InputActions.movement_vector()
	# Simulation bounds individual calls for collision stability; consume the
	# complete round delta so traffic and the common timer share the same clock.
	var remaining := delta
	while remaining > 0.000001 and simulation.state == "playing":
		var step := minf(remaining, 0.25)
		simulation.tick(step, movement)
		remaining -= step
	_timer_label.text = "Time: %.1f" % _seconds_left
	_update_inventory()
	match simulation.state:
		"won": _finish_round(true, "You made it to the library!")
		"crashed": _finish_round(false, "Traffic collision!")
		_: UI.set_status(_status_label, simulation.notice)

func _on_timeout() -> void:
	simulation.state = "timed_out"
	_finish_round(false, "Time's up!")

func _show_result(success: bool, message: String) -> void:
	if simulation.state == "playing": simulation.state = "finished"
	UI.set_status(_status_label, message, "success" if success else "error")

func _update_inventory() -> void:
	_inventory_label.text = "TOKENS  %s\nSHIELDS  %s" % [str(hooks.variables.get("tokens", 0)), str(hooks.variables.get("shields", 0))]
