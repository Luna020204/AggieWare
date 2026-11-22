class_name PixelText
extends RefCounted

## AggiePixel text helpers for microgames, following the AggieWare format
## standard: the AggiePixel font scaled by whole pixels, and a one-pixel dark
## drop shadow instead of boxes behind text.
##
## The font is 7 px tall, so font sizes should be multiples of 7
## (14, 21, 28, 35, 42, 70).

const FONT := preload("res://assets/fonts/aggie_pixel.fnt")
const SHADOW := Color("#14121a")


## Makes AggiePixel the default font for `control` and its children.
static func apply_theme(control: Control, default_size: int = 21) -> void:
	var font: FontFile = FONT
	font.fixed_size_scale_mode = TextServer.FIXED_SIZE_SCALE_INTEGER_ONLY
	if font.fallbacks.is_empty():
		font.fallbacks = [ThemeDB.fallback_font]
	var pixel_theme := Theme.new()
	pixel_theme.default_font = font
	pixel_theme.default_font_size = default_size
	control.theme = pixel_theme


## A label in AggiePixel with the standard drop shadow; it ignores the mouse.
static func label(font_size: int, color: Color, text: String = "") -> Label:
	var result := Label.new()
	result.text = text
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", color)
	set_shadow(result, font_size)
	return result


## A dark drop shadow one font pixel down and right.
static func set_shadow(target: Label, font_size: int) -> void:
	var offset := maxi(font_size / 7, 1)
	target.add_theme_color_override("font_shadow_color", SHADOW)
	target.add_theme_constant_override("shadow_offset_x", offset)
	target.add_theme_constant_override("shadow_offset_y", offset)


## Draws a string with the standard shadow from inside a draw callback.
static func draw_shadowed(canvas: CanvasItem, font: Font, at: Vector2, text: String, font_size: int, color: Color) -> void:
	var offset := float(maxi(font_size / 7, 1))
	canvas.draw_string(font, at + Vector2(offset, offset), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, SHADOW)
	canvas.draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
