extends MicrogameBase
## Adapter between native crossing levels and AggieWare's common round lifecycle.
const Simulation = preload("res://scripts/crossing/simulation.gd")
const Hooks = preload("res://scripts/crossing/game_hooks.gd")
const UI = preload("res://scripts/ui/microgame_ui.gd")
const DURATIONS: Array[float] = [9.0, 8.0, 7.0]

@export var level_scene: PackedScene = preload("res://scenes/crossing/campus_intro.tscn")

var simulation := Simulation.new()
var hooks: Node
## Supplied directly when pressing F6 on an authored CrossingCampusLevel scene.
var level_node: CrossingCampusLevel
var _status_label: Label
var _timer_label: Label
var _inventory_label: Label
var _progress_label: Label
var _play_hud: Control
var _hud_art: Control
var _retry_button: Button
var _level_error := ""

func get_round_seconds() -> float:
	return DURATIONS[clampi(difficulty, 0, 2)]

func _build_ui() -> void:
	var external_level := is_instance_valid(level_node)
	var header := UI.build_header(self, "CAMPUS CROSSING", "DODGE TRAFFIC. REACH THE FLAG.", show_internal_timer)
	_timer_label = header.timer
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
		level_node.position = Vector2.ZERO
		level_node.scale = Vector2.ONE
		var world := UI.pixel_canvas(self)
		level_node.remove_child(level_node.preview)
		world.add_child(level_node.preview)
		level_node.preview.configure_runtime_view(Vector2(1280, 720))
		level_node.preview.font = UI.PIXEL_FONT
		level_node.preview.show_state_overlay = false
		level_node.runtime_ready.emit(self)
	# World art fills the viewport; the compact overlay stays above that art.
	move_child(_timer_label, get_child_count() - 1)
	_play_hud = Control.new()
	_play_hud.name = "CrossingHUD"
	_play_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_play_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_play_hud)
	_hud_art = UI.pixel_canvas(_play_hud, _draw_progress)
	_progress_label = UI.label(_play_hud, "", Vector2(30, 65), 14, UI.TEXT, Vector2(270, 20))
	_inventory_label = UI.label(_play_hud, "", Vector2(30, 88), 14, UI.TEXT, Vector2(345, 20))
	_play_hud.hide()
	var actions := CanvasLayer.new()
	actions.name = "CrossingResultActions"
	actions.layer = 51
	add_child(actions)
	_retry_button = Button.new()
	_retry_button.position = Vector2(390, 610)
	_retry_button.size = Vector2(500, 60)
	_retry_button.focus_mode = Control.FOCUS_NONE
	UI.flat_button(_retry_button, 28)
	_retry_button.pressed.connect(_start_round)
	actions.add_child(_retry_button)
	_retry_button.hide()
	_status_label = UI.status_label(self)

func _reset_game() -> void:
	_play_hud.hide()
	_retry_button.hide()
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
		_:
			# Notices persist in the simulation; show each change only once.
			if _status_label.text != simulation.notice:
				UI.set_status(_status_label, simulation.notice, "success" if simulation.notice.begins_with("Collected:") else "neutral")

func _update_intro_progress(elapsed: float, duration: float) -> void:
	_play_hud.visible = elapsed >= duration and not _ended

func _on_timeout() -> void:
	simulation.state = "timed_out"
	_finish_round(false, "Time's up!")

func _show_result(success: bool, message: String) -> void:
	if simulation.state == "playing": simulation.state = "finished"
	_play_hud.hide()
	_retry_button.text = "PLAY AGAIN [%s]" % InputActions.action_label(InputActions.ACTION_RETRY).to_upper()
	_retry_button.visible = not managed_by_flow
	UI.set_status(_status_label, message, "success" if success else "error")

func _update_inventory() -> void:
	_inventory_label.text = "TOKENS %s   SHIELDS %s" % [str(hooks.variables.get("tokens", 0)), str(hooks.variables.get("shields", 0))]
	_progress_label.text = "CROSSED %d%%" % roundi(get_crossing_progress() * 100.0)
	_hud_art.queue_redraw()

func _draw_progress() -> void:
	var filled := roundi(get_crossing_progress() * 16.0)
	for segment in 16:
		_hud_art.draw_rect(Rect2(205 + segment * 10, 70, 5, 10), UI.GOLD if segment < filled else Color("#465356"))

func get_crossing_progress() -> float:
	if simulation.level.is_empty(): return 0.0
	var start_y := (float(simulation.level.start[1]) + 0.5) * 40.0
	var goal_y := (float(simulation.level.goal[1]) + 0.5) * 40.0
	if is_equal_approx(start_y, goal_y): return 1.0 if simulation.state == "won" else 0.0
	return clampf((start_y - simulation.player.y) / (start_y - goal_y), 0.0, 1.0)
