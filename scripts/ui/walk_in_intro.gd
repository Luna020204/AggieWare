class_name WalkInIntro
extends Control

## The establishing scene microgames can open with, per the AggieWare format
## standard: a student walks up to a campus building and in through its door,
## then the screen fades through black into the play scene.
##
## Timeline (seconds): the walk until WALK_END, the open door until DOOR_END,
## fade to black until BLACK_AT, fade in until DURATION. The microgame keeps
## its own clock, calls show_at(t) each frame, and uses the returned alpha for
## its title and instruction (they fade out while the door opens).
##
## Add it above the play scene and below the MicrogameOverlay, then call
## build(). Positions and sizes are in scene pixels (1/5 of the screen).

const DURATION := 3.2
const WALK_END := 2.2
const DOOR_END := 2.5
const BLACK_AT := 2.85
const STEP_SECONDS := 0.14
const STEP_FRAMES := [1, 0, 2, 0]
const PX := 5.0

## The outside scene: background, open door and walker. Hidden after the fade.
var scene: Control
var walker: TextureRect
var door: TextureRect

var _fade: ColorRect
var _walker_textures: Array
var _walker_size := Vector2.ZERO
var _path: Array[Vector2] = []


## `walker_textures` are the standing frame then two stepping frames. `path`
## is where the walker's feet go, from start to the door.
func build(exterior: Texture2D, door_open: Texture2D, door_rect: Rect2, walker_textures: Array,
		walker_size: Vector2, path: Array[Vector2]) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_walker_textures = walker_textures
	_walker_size = walker_size
	_path = path

	scene = Control.new()
	scene.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scene.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scene.add_child(_pixel_rect(exterior, Vector2.ZERO, Vector2(1280.0, 720.0)))
	door = _pixel_rect(door_open, door_rect.position * PX, door_rect.size * PX)
	scene.add_child(door)
	walker = _pixel_rect(walker_textures[0], Vector2.ZERO, walker_size * PX)
	scene.add_child(walker)
	add_child(scene)

	_fade = ColorRect.new()
	_fade.color = Color(0.0, 0.0, 0.0, 0.0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_fade)


## Lays the scene out for time `t` into the intro (DURATION or more hides it)
## and returns the alpha for the microgame's title.
func show_at(t: float) -> float:
	var running := t < DURATION
	scene.visible = running and t < BLACK_AT
	walker.visible = t < WALK_END
	if walker.visible:
		var feet := walk_point(t / WALK_END)
		walker.position = (feet - Vector2(_walker_size.x * 0.5, _walker_size.y)) * PX
		walker.texture = _walker_textures[STEP_FRAMES[int(t / STEP_SECONDS) % STEP_FRAMES.size()]]
	door.visible = t >= WALK_END - 0.1
	var black := 0.0
	if running and t >= DOOR_END:
		if t < BLACK_AT:
			black = (t - DOOR_END) / (BLACK_AT - DOOR_END)
		else:
			black = 1.0 - (t - BLACK_AT) / (DURATION - BLACK_AT)
	_fade.color.a = clampf(black, 0.0, 1.0)
	return clampf((DOOR_END - t) / (DOOR_END - WALK_END), 0.0, 1.0) if running else 0.0


## A point along the path, 0 at the start and 1 at the door.
func walk_point(progress: float) -> Vector2:
	progress = clampf(progress, 0.0, 1.0)
	var lengths: Array[float] = []
	var total := 0.0
	for i: int in _path.size() - 1:
		lengths.append(_path[i].distance_to(_path[i + 1]))
		total += lengths[i]
	var along := progress * total
	for i: int in lengths.size():
		if along <= lengths[i] or i == lengths.size() - 1:
			return _path[i].lerp(_path[i + 1], clampf(along / lengths[i], 0.0, 1.0))
		along -= lengths[i]
	return _path[-1]


func _pixel_rect(texture: Texture2D, at: Vector2, rect_size: Vector2) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.position = at
	rect.size = rect_size
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect
