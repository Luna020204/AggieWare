class_name InstructionPrompt
extends Control
## A single clock-free title/instruction presentation driven by MicrogameBase.
const UI = preload("res://scripts/ui/microgame_ui.gd")
const DEFAULT_SECONDS := 3.2
signal finished
var title_text := "PLAY"
var instruction := ""
var text_rect := Rect2(80, 230, 1120, 230)
var dimmed := true
var title_label: Label
var instruction_label: Label
var shade: ColorRect

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	UI.apply_theme(self)
	shade = ColorRect.new()
	shade.color = Color(0, 0, 0, 0.55 if dimmed else 0.0)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	title_label = UI.label(self, title_text, text_rect.position, 70, UI.GOLD, Vector2(text_rect.size.x, 100))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instruction_label = UI.label(self, instruction, text_rect.position + Vector2(0, 110), 28, UI.TEXT, Vector2(text_rect.size.x, 70))
	instruction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instruction_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func set_progress(elapsed: float, duration: float) -> void:
	var fade := minf(0.7, duration)
	if dimmed:
		modulate.a = clampf((duration - elapsed) / maxf(fade, 0.001), 0.0, 1.0)
	else:
		modulate.a = clampf((duration - 0.7 - elapsed) / 0.3, 0.0, 1.0)
	visible = elapsed < duration

func finish() -> void:
	finished.emit()
