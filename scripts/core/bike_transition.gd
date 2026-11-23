extends Control

## SCRUM-18: Short bike/loading interstitial between microgames.
##
## The core stage manager can listen to transition_finished and decide which
## microgame to load next. Keeping the scene independent lets it be tested on
## its own while the manager is still under construction.

signal transition_finished(next_scene_path: String)

const UI := preload("res://scripts/ui/microgame_ui.gd")
const MAX_STEP := 1.0 / 120.0
const OBSTACLE_SPEED := 420.0
const STUMBLE_SECONDS := 0.45
const OBSTACLE_TIMES: Array[float] = [0.0, 1.15, 1.15]
const OBSTACLE_LANES: Array[int] = [1, 0, 2]
const OBSTACLE_NAMES: Array[String] = ["SCOOTER", "BIKE", "WALKER"]

@export var next_prompt: String = "CANVAS"
@export_range(1.0, 10.0, 0.5) var transition_duration: float = 3.0
@export var auto_advance: bool = true
@export_file("*.tscn") var next_scene_path: String = ""
@export_range(0, 9, 1) var lives: int = 3
@export var score: int = 0
@export var managed_by_flow := false

var _elapsed := 0.0
var _current_lane := 1
var _finished := false
var _next_obstacle := 0
var _stumble_left := 0.0
var _stumbles := 0
var _obstacles: Array[PanelContainer] = []
var _bike: PanelContainer
var _progress: ProgressBar
var _status_label: Label
var _lives_label: Label
var _score_label: Label
var _goal_label: Label

const TRACK_RECT := Rect2(120.0, 205.0, 1040.0, 300.0)
const LANE_Y := [245.0, 350.0, 455.0]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	UI.apply_theme(self)
	_build_ui()
	if not managed_by_flow:
		var pause_scene: PackedScene = load("res://scenes/ui/settings_pause_menu.tscn")
		add_child(pause_scene.instantiate())
	_reset_transition()


func _process(delta: float) -> void:
	if _finished or not is_inside_tree() or get_tree().paused:
		return
	var remaining := maxf(delta, 0.0)
	while remaining > 0.0 and not _finished:
		var step := minf(remaining, MAX_STEP)
		remaining -= step
		if _stumble_left > 0.0:
			_stumble_left = maxf(0.0, _stumble_left - step)
			if _stumble_left == 0.0:
				_bike.modulate = Color.WHITE
				_status_label.text = "KEEP DODGING!  STUMBLES: %d" % _stumbles
		else:
			_elapsed += step
			var fraction := clampf(_elapsed / maxf(transition_duration, 0.001), 0.0, 1.0)
			_progress.value = fraction * 100.0
			_bike.position.x = TRACK_RECT.position.x + 34.0 + fraction * (TRACK_RECT.size.x - 110.0)
			_spawn_due_obstacles()
		_move_obstacles(step)
		if _stumble_left <= 0.0:
			_check_obstacle_hits()
		if auto_advance and _elapsed >= transition_duration:
			_finish_transition()


func _unhandled_key_input(event: InputEvent) -> void:
	if _finished or get_tree().paused or (event is InputEventKey and event.echo):
		return
	var viewport := get_viewport()
	if event.is_action_pressed(InputActions.ACTION_UP):
		_set_lane(_current_lane - 1)
	elif event.is_action_pressed(InputActions.ACTION_DOWN):
		_set_lane(_current_lane + 1)
	else:
		return
	viewport.set_input_as_handled()


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color("#081426")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var header := HBoxContainer.new()
	header.position = Vector2(48.0, 30.0)
	header.size = Vector2(1184.0, 74.0)
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_theme_constant_override("separation", 36)
	add_child(header)

	var title := Label.new()
	title.text = "BIKE TO NEXT CLASS"
	title.add_theme_font_size_override("font_size", 28)
	UI.shadow(title, 28)
	title.add_theme_color_override("font_color", Color("#f5f7ff"))
	header.add_child(title)

	_lives_label = Label.new()
	_lives_label.add_theme_font_size_override("font_size", 21)
	UI.shadow(_lives_label, 21)
	_lives_label.add_theme_color_override("font_color", Color("#ff9e9e"))
	header.add_child(_lives_label)

	_score_label = Label.new()
	_score_label.add_theme_font_size_override("font_size", 21)
	UI.shadow(_score_label, 21)
	_score_label.add_theme_color_override("font_color", Color("#ffd166"))
	header.add_child(_score_label)

	var next_label := Label.new()
	next_label.position = Vector2(0.0, 112.0)
	next_label.size = Vector2(1280.0, 52.0)
	next_label.text = "NEXT UP:  " + next_prompt
	next_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	next_label.add_theme_font_size_override("font_size", 28)
	UI.shadow(next_label, 28)
	next_label.add_theme_color_override("font_color", Color("#73b7ff"))
	add_child(next_label)
	_goal_label = Label.new()
	_goal_label.position = Vector2(0.0, 165.0)
	_goal_label.size = Vector2(1280.0, 38.0)
	_goal_label.text = "DODGE THE TRAFFIC  ·  UP / DOWN TO CHANGE LANES"
	_goal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_goal_label.add_theme_font_size_override("font_size", 23)
	UI.shadow(_goal_label, 23)
	_goal_label.add_theme_color_override("font_color", Color("#ffbf00"))
	add_child(_goal_label)

	var track := PanelContainer.new()
	track.position = TRACK_RECT.position
	track.size = TRACK_RECT.size
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.add_theme_stylebox_override("panel", _panel_style(Color("#132848"), Color("#38537d")))
	add_child(track)

	for lane_y: float in LANE_Y:
		var lane := ColorRect.new()
		lane.position = Vector2(TRACK_RECT.position.x + 24.0, lane_y + 30.0)
		lane.size = Vector2(TRACK_RECT.size.x - 48.0, 4.0)
		lane.color = Color("#2d4b74")
		lane.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(lane)

	_bike = PanelContainer.new()
	_bike.size = Vector2(82.0, 54.0)
	_bike.z_index = 2
	_bike.add_theme_stylebox_override("panel", _panel_style(Color("#d8753d"), Color("#ffcc66")))
	add_child(_bike)
	var bike_label := Label.new()
	bike_label.text = "BIKE"
	bike_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bike_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bike_label.add_theme_color_override("font_color", Color("#fff7e0"))
	_bike.add_child(bike_label)

	_progress = ProgressBar.new()
	_progress.position = Vector2(160.0, 548.0)
	_progress.size = Vector2(960.0, 24.0)
	_progress.show_percentage = false
	add_child(_progress)

	_status_label = Label.new()
	_status_label.position = Vector2(0.0, 600.0)
	_status_label.size = Vector2(1280.0, 42.0)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 21)
	UI.shadow(_status_label, 21)
	_status_label.add_theme_color_override("font_color", Color("#b8c7e6"))
	add_child(_status_label)


func _reset_transition() -> void:
	_elapsed = 0.0
	_finished = false
	_current_lane = 1
	_next_obstacle = 0
	_stumble_left = 0.0
	_stumbles = 0
	_bike.modulate = Color.WHITE
	for obstacle: PanelContainer in _obstacles:
		remove_child(obstacle)
		obstacle.queue_free()
	_obstacles.clear()
	_progress.value = 0.0
	_lives_label.text = "Lives: %d" % lives
	_score_label.text = "Score: %d" % score
	_bike.position.x = TRACK_RECT.position.x + 34.0
	_set_lane(_current_lane)
	_status_label.text = "Avoid a stumble on the way to class."
	_spawn_due_obstacles()


func _set_lane(lane: int) -> void:
	_current_lane = clampi(lane, 0, LANE_Y.size() - 1)
	_bike.position = Vector2(_bike.position.x, LANE_Y[_current_lane])


func _spawn_due_obstacles() -> void:
	while _next_obstacle < OBSTACLE_TIMES.size() and _elapsed >= OBSTACLE_TIMES[_next_obstacle]:
		var index := _next_obstacle
		_next_obstacle += 1
		var obstacle := PanelContainer.new()
		obstacle.size = Vector2(110.0, 54.0)
		obstacle.position = Vector2(TRACK_RECT.end.x - 120.0, LANE_Y[OBSTACLE_LANES[index]])
		obstacle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		obstacle.add_theme_stylebox_override("panel", _panel_style(Color("#7b3441"), Color("#ffbf00")))
		var label := Label.new()
		label.text = OBSTACLE_NAMES[index]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_color", Color.WHITE)
		obstacle.add_child(label)
		add_child(obstacle)
		_obstacles.append(obstacle)


func _move_obstacles(delta: float) -> void:
	for obstacle: PanelContainer in _obstacles.duplicate():
		obstacle.position.x -= OBSTACLE_SPEED * delta
		if obstacle.position.x + obstacle.size.x < TRACK_RECT.position.x:
			_remove_obstacle(obstacle)


func _check_obstacle_hits() -> void:
	var bike_rect := Rect2(_bike.position, _bike.size)
	for obstacle: PanelContainer in _obstacles.duplicate():
		if bike_rect.intersects(Rect2(obstacle.position, obstacle.size)):
			_remove_obstacle(obstacle)
			_stumbles += 1
			_stumble_left = STUMBLE_SECONDS
			_bike.modulate = Color("#ff9e9e")
			_status_label.text = "STUMBLE! +%.2f s delay  ·  HITS: %d" % [STUMBLE_SECONDS, _stumbles]
			break


func _remove_obstacle(obstacle: PanelContainer) -> void:
	_obstacles.erase(obstacle)
	remove_child(obstacle)
	obstacle.queue_free()


func _finish_transition() -> void:
	if _finished:
		return
	_finished = true
	_progress.value = 100.0
	_status_label.text = "Arrived — loading %s" % next_prompt
	transition_finished.emit(next_scene_path)
	if not managed_by_flow and is_inside_tree() and next_scene_path != "" and ResourceLoader.exists(next_scene_path):
		get_tree().change_scene_to_file.call_deferred(next_scene_path)


func _panel_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	return style
