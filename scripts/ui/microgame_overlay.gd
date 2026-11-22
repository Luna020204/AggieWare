class_name MicrogameOverlay
extends Control

## The text layer every microgame shares, following the AggieWare format
## standard: no boxes, a centred intro title and instruction, and result
## messages that pop up in the middle and fade. The scene dims behind both so
## they read over the art.
##
## Add it as the last child of the microgame so it draws on top, then call
## build(). The microgame decides when the intro shows (set_intro) and when
## a message pops (pop); the overlay handles fading and dimming.

const POP_SECONDS := 1.4
const POP_FADE := 0.4
const INTRO_DIM := 0.45
const POP_DIM := 0.55

## The intro's title and instruction.
var intro: VBoxContainer
## The current pop message.
var status_label: Label

var _dim: ColorRect
var _pop_left := 0.0


func build(title: String, instruction: String) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Above anything a microgame raises with z_index (a dragged card, say).
	z_index = 10

	_dim = ColorRect.new()
	_dim.color = Color(0.0, 0.0, 0.0, 0.0)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_dim)

	status_label = PixelText.label(28, Color.WHITE)
	status_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.modulate.a = 0.0
	add_child(status_label)

	intro = VBoxContainer.new()
	intro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	intro.alignment = BoxContainer.ALIGNMENT_CENTER
	intro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	intro.add_theme_constant_override("separation", 24)
	var title_label := PixelText.label(70, Color("#ffbf00"), title)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro.add_child(title_label)
	var instruction_label := PixelText.label(28, Color.WHITE, instruction)
	instruction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro.add_child(instruction_label)
	add_child(intro)


## Shows the intro text at `alpha`, or hides it.
func set_intro(showing: bool, alpha: float = 1.0) -> void:
	intro.visible = showing
	intro.modulate.a = clampf(alpha, 0.0, 1.0)
	_update_dim()


## Pops a message in the middle of the screen; it fades on its own.
func pop(message: String, color: Color, font_size: int) -> void:
	status_label.text = message
	status_label.add_theme_color_override("font_color", color)
	status_label.add_theme_font_size_override("font_size", font_size)
	PixelText.set_shadow(status_label, font_size)
	status_label.modulate.a = 1.0
	_pop_left = POP_SECONDS
	_update_dim()


func clear_pop() -> void:
	_pop_left = 0.0
	status_label.text = ""
	status_label.modulate.a = 0.0
	_update_dim()


func _process(delta: float) -> void:
	if _pop_left > 0.0:
		_pop_left = maxf(0.0, _pop_left - delta)
		status_label.modulate.a = clampf(_pop_left / POP_FADE, 0.0, 1.0)
		_update_dim()


func _update_dim() -> void:
	var title_alpha := intro.modulate.a if intro.visible else 0.0
	_dim.color.a = maxf(INTRO_DIM * title_alpha, POP_DIM * status_label.modulate.a)
