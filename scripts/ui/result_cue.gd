class_name ResultCue
extends Control
## Unboxed centered feedback; its owner advances the fade and round boundary.
const UI = preload("res://scripts/ui/microgame_ui.gd")
var success := true
var word_label: Label
var message_label: Label
var shade: ColorRect

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.apply_theme(self)
	shade = ColorRect.new()
	shade.color = Color(0, 0, 0, 0.55)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	word_label = UI.label(self, "", Vector2(80, 240), 28, UI.TEXT, Vector2(1120, 45))
	word_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label = UI.label(self, "", Vector2(80, 300), 42, UI.TEXT, Vector2(1120, 140))
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hide()

func present(message: String, color: Color, size_px: int = 42, final_result: bool = true, was_success: bool = false) -> void:
	success = was_success
	message_label.text = message
	message_label.add_theme_font_size_override("font_size", size_px)
	message_label.add_theme_color_override("font_color", color)
	UI.shadow(message_label, size_px)
	word_label.text = ("● ✓ CLEAR" if success else "□ ✗ MISS") if final_result and Accessibility.result_cues_enabled() else ""
	modulate.a = 1.0
	show()

func set_remaining(remaining: float, duration: float) -> void:
	modulate.a = clampf(remaining / maxf(minf(0.4, duration), 0.001), 0.0, 1.0)
	visible = remaining > 0.0

func get_word() -> String:
	return "CLEAR" if success else "MISS"
