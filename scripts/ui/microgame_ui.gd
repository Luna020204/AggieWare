extends RefCounted

## Shared presentation for the collection's Control-based microgames.
const BG := Color("#101a2d")
const TEXT := Color("#f5f7ff")
const MUTED := Color("#b8c7e6")
const ACCENT := Color("#ffd166")
const SUCCESS := Color("#73e6a8")
const ERROR := Color("#ff9e9e")
const PANEL := Color("#172746")
const BORDER := Color("#38537d")


static func build_header(parent: Control, title: String, instruction: String, show_timer: bool = true) -> Dictionary:
	var background := ColorRect.new()
	background.color = BG
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(background)
	var title_label := label(parent, title, Vector2(48, 35), 34, TEXT, Vector2(560, 48))
	# The collection HUD occupies y24..132; instructions belong below it.
	var instruction_label := label(parent, instruction, Vector2(48, 145), 20, MUTED)
	var timer_label := label(parent, "", Vector2(48, 190), 23, ACCENT)
	timer_label.visible = show_timer
	return {"title": title_label, "instruction": instruction_label, "timer": timer_label}


static func label(parent: Node, text: String, position: Vector2, font_size: int = 20, color: Color = TEXT, label_size: Vector2 = Vector2(1184, 32)) -> Label:
	var result := Label.new()
	result.text = text
	result.position = position
	result.size = label_size
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", color)
	parent.add_child(result)
	return result


static func panel(parent: Node, rect: Rect2, background: Color = PANEL, border: Color = BORDER, radius: int = 10) -> PanelContainer:
	var result := PanelContainer.new()
	result.position = rect.position
	result.size = rect.size
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.add_theme_stylebox_override("panel", panel_style(background, border, radius))
	parent.add_child(result)
	return result


static func panel_style(background: Color, border: Color, radius: int = 10, border_width: int = 2) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 12.0
	style.content_margin_top = 8.0
	style.content_margin_right = 12.0
	style.content_margin_bottom = 8.0
	return style


static func set_status(target: Label, text: String, tone: String = "neutral") -> void:
	var color := MUTED
	match tone:
		"success": color = SUCCESS
		"error": color = ERROR
		"warning": color = ACCENT
	target.text = text
	target.add_theme_color_override("font_color", color)


static func clear_nodes(nodes: Array) -> void:
	for node: Node in nodes:
		if is_instance_valid(node):
			if node.get_parent() != null:
				node.get_parent().remove_child(node)
			node.queue_free()
	nodes.clear()
