extends Control

## SCRUM-18: Short bike/loading interstitial between microgames.
##
## The core stage manager can listen to transition_finished and decide which
## microgame to load next. Keeping the scene independent lets it be tested on
## its own while the manager is still under construction.

signal transition_finished(next_scene_path: String)

@export var next_prompt: String = "CANVAS"
@export_range(1.0, 10.0, 0.5) var transition_duration: float = 3.0
@export var auto_advance: bool = true
@export_file("*.tscn") var next_scene_path: String = ""
@export_range(0, 9, 1) var lives: int = 3
@export var score: int = 0

var _elapsed := 0.0
var _current_lane := 1
var _finished := false
var _bike: PanelContainer
var _progress: ProgressBar
var _status_label: Label
var _lives_label: Label
var _score_label: Label

const TRACK_RECT := Rect2(120.0, 205.0, 1040.0, 300.0)
const LANE_Y := [245.0, 350.0, 455.0]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_build_ui()
	_reset_transition()


func _process(delta: float) -> void:
	if _finished:
		return

	if InputActions.is_just_pressed(InputActions.ACTION_UP):
		_set_lane(_current_lane - 1)
	if InputActions.is_just_pressed(InputActions.ACTION_DOWN):
		_set_lane(_current_lane + 1)
	if InputActions.is_just_pressed(InputActions.ACTION_CONFIRM):
		_finish_transition()

	_elapsed += delta
	var fraction := clampf(_elapsed / transition_duration, 0.0, 1.0)
	_progress.value = fraction * 100.0
	_bike.position.x = TRACK_RECT.position.x + 34.0 + fraction * (TRACK_RECT.size.x - 110.0)
	if auto_advance and _elapsed >= transition_duration:
		_finish_transition()


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
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color("#f5f7ff"))
	header.add_child(title)

	_lives_label = Label.new()
	_lives_label.add_theme_font_size_override("font_size", 20)
	_lives_label.add_theme_color_override("font_color", Color("#ff9e9e"))
	header.add_child(_lives_label)

	_score_label = Label.new()
	_score_label.add_theme_font_size_override("font_size", 20)
	_score_label.add_theme_color_override("font_color", Color("#ffd166"))
	header.add_child(_score_label)

	var next_label := Label.new()
	next_label.position = Vector2(0.0, 112.0)
	next_label.size = Vector2(1280.0, 52.0)
	next_label.text = "NEXT UP:  " + next_prompt
	next_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	next_label.add_theme_font_size_override("font_size", 28)
	next_label.add_theme_color_override("font_color", Color("#73b7ff"))
	add_child(next_label)

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
	_status_label.add_theme_font_size_override("font_size", 18)
	_status_label.add_theme_color_override("font_color", Color("#b8c7e6"))
	add_child(_status_label)


func _reset_transition() -> void:
	_elapsed = 0.0
	_finished = false
	_current_lane = 1
	_progress.value = 0.0
	_lives_label.text = "Lives: %d" % lives
	_score_label.text = "Score: %d" % score
	_status_label.text = "Use Up / Down to choose your lane · Confirm to skip"
	_set_lane(_current_lane)


func _set_lane(lane: int) -> void:
	_current_lane = clampi(lane, 0, LANE_Y.size() - 1)
	_bike.position = Vector2(_bike.position.x, LANE_Y[_current_lane])
	_status_label.text = "Riding to the next activity..."


func _finish_transition() -> void:
	if _finished:
		return
	_finished = true
	_progress.value = 100.0
	_status_label.text = "Arrived — loading %s" % next_prompt
	transition_finished.emit(next_scene_path)
	if next_scene_path != "" and ResourceLoader.exists(next_scene_path):
		get_tree().change_scene_to_file.call_deferred(next_scene_path)


func _panel_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	return style
