extends RefCounted
## Shared presentation matching the producer's Microgame Format Standard v1.0.
const PIXEL_FONT = preload("res://assets/fonts/aggie_pixel.fnt")
const PIXEL_SCALE := 5
const BG := Color("#022851")
const TEXT := Color.WHITE
const MUTED := Color("#c9d8dd")
const ACCENT := Color("#ffd166")
const GOLD := Color("#ffbf00")
const SUCCESS := Color("#73e6a8")
const ERROR := Color("#ff9e9e")
const REJECT := Color("#ffb38a")
const SHADOW := Color("#14121a")
const PANEL := BG
const BORDER := Color("#8ba6ba")

static func apply_theme(control: Control) -> void:
	var font: FontFile = PIXEL_FONT
	font.fixed_size_scale_mode = TextServer.FIXED_SIZE_SCALE_INTEGER_ONLY
	if font.fallbacks.is_empty():
		font.fallbacks = [ThemeDB.fallback_font]
	var pixel_theme := Theme.new()
	pixel_theme.default_font = font
	pixel_theme.default_font_size = 21
	for type_name in ["Label", "Button", "CheckButton", "OptionButton", "RichTextLabel"]:
		pixel_theme.set_color("font_shadow_color", type_name, SHADOW)
		pixel_theme.set_constant("shadow_offset_x", type_name, 3)
		pixel_theme.set_constant("shadow_offset_y", type_name, 3)
	control.theme = pixel_theme
	control.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

static func shadow(control: Control, font_size: int) -> void:
	control.add_theme_color_override("font_shadow_color", SHADOW)
	control.add_theme_constant_override("shadow_offset_x", maxi(font_size / 7, 1))
	control.add_theme_constant_override("shadow_offset_y", maxi(font_size / 7, 1))

static func label(parent: Node, text: String, position: Vector2, font_size: int = 21, color: Color = TEXT, label_size: Vector2 = Vector2(1184, 35)) -> Label:
	var result := Label.new()
	result.text = text
	result.position = position
	result.size = label_size
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pixel_size := maxi(7, roundi(float(font_size) / 7.0) * 7)
	result.add_theme_font_override("font", PIXEL_FONT)
	result.add_theme_font_size_override("font_size", pixel_size)
	result.add_theme_color_override("font_color", color)
	shadow(result, pixel_size)
	parent.add_child(result)
	return result

## Header metadata belongs to the shared intro, never a permanent gameplay bar.
static func build_header(parent: Control, title: String, instruction: String, show_timer: bool = true) -> Dictionary:
	apply_theme(parent)
	if str(parent.get("game_title")).is_empty(): parent.set("game_title", title)
	if str(parent.get("instruction_text")).is_empty(): parent.set("instruction_text", instruction)
	var title_label := label(parent, title, Vector2.ZERO, 70, GOLD)
	var instruction_label := label(parent, instruction, Vector2.ZERO, 28)
	title_label.hide()
	instruction_label.hide()
	var timer_label := label(parent, "", Vector2(30, 25), 28, ACCENT, Vector2(500, 35))
	timer_label.name = "InternalTimer"
	timer_label.visible = show_timer
	return {"title": title_label, "instruction": instruction_label, "timer": timer_label}

static func status_label(parent: Control) -> Label:
	var result := label(parent, "", Vector2.ZERO)
	result.set_meta("feedback_only", true)
	result.hide()
	return result

static func set_status(target: Label, text: String, tone: String = "neutral") -> void:
	target.text = text
	var color := MUTED
	match tone:
		"success": color = SUCCESS
		"error", "warning": color = REJECT
	target.add_theme_color_override("font_color", color)
	if target.has_meta("feedback_only"):
		target.hide()
		var game := target.get_parent()
		if tone != "neutral" and game.has_method("can_interact") and game.can_interact():
			game.show_feedback(text, color)

static func flat_button(button: Button, font_size: int = 28) -> void:
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	button.add_theme_font_override("font", PIXEL_FONT)
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", TEXT)
	button.add_theme_color_override("font_hover_color", GOLD)
	button.add_theme_color_override("font_pressed_color", GOLD)
	button.add_theme_color_override("font_disabled_color", MUTED)
	shadow(button, font_size)

## Render authored world geometry at one fifth resolution, then upscale exactly 5x.
## Interactive Controls stay outside the surface, keeping native input coordinates.
static func pixel_canvas(parent: Node, draw_callback: Callable = Callable(), rect: Rect2 = Rect2(0, 0, 1280, 720)) -> Control:
	var viewport := SubViewport.new()
	viewport.name = "PixelViewport"
	viewport.size = Vector2i(ceil(rect.size.x / PIXEL_SCALE), ceil(rect.size.y / PIXEL_SCALE))
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.gui_disable_input = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	parent.add_child(viewport)
	var canvas := Control.new()
	canvas.name = "PixelCanvas"
	canvas.size = rect.size
	canvas.scale = Vector2.ONE / PIXEL_SCALE
	canvas.position = -rect.position / PIXEL_SCALE
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	apply_theme(canvas)
	viewport.add_child(canvas)
	if draw_callback.is_valid(): canvas.draw.connect(draw_callback)
	var display := TextureRect.new()
	display.name = "PixelArt"
	display.position = rect.position
	display.size = rect.size
	display.texture = viewport.get_texture()
	display.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	display.stretch_mode = TextureRect.STRETCH_SCALE
	display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(display)
	return canvas

static func add_backdrop(parent: Node, kind: String) -> Control:
	var canvas := pixel_canvas(parent)
	var art: Script = load("res://scripts/ui/pixel_backdrop.gd")
	canvas.set_script(art)
	canvas.set("kind", kind)
	canvas.queue_redraw()
	return canvas

## Layout-only compatibility helper. Gameplay no longer draws a panel behind text.
static func panel(parent: Node, rect: Rect2, _background: Color = PANEL, _border: Color = BORDER, _radius: int = 0) -> PanelContainer:
	var result := PanelContainer.new()
	result.position = rect.position
	result.size = rect.size
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	parent.add_child(result)
	return result

static func panel_style(background: Color, border: Color, _radius: int = 0, border_width: int = 2) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	return style

static func clear_nodes(nodes: Array) -> void:
	for node: Node in nodes:
		if is_instance_valid(node):
			if node.get_parent() != null: node.get_parent().remove_child(node)
			node.queue_free()
	nodes.clear()
