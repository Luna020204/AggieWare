class_name ResultCue
extends Control

## SCRUM-41: colour-independent round result banner.
##
## A filled circle with a check and the word CLEAR, or a hollow square with a
## cross and the word MISS. Shape, symbol and word all differ, so it reads
## the same with any colour vision or in greyscale. Shown by the week flow
## and the launcher when Accessibility.result_cues_enabled() is on.

var success := true


static func create(was_success: bool) -> ResultCue:
	var cue := ResultCue.new()
	cue.success = was_success
	return cue


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	queue_redraw()


func get_word() -> String:
	return "CLEAR" if success else "MISS"


func _draw() -> void:
	var center := Vector2(640.0, 330.0)
	var panel := Rect2(center - Vector2(250.0, 110.0), Vector2(500.0, 220.0))
	draw_rect(panel, Color(0.04, 0.05, 0.1, 0.88))
	draw_rect(panel, Color("#f5f7ff"), false, 4.0)
	var icon := center + Vector2(-140.0, 0.0)
	var ink := Color("#f5f7ff")
	if success:
		draw_circle(icon, 62.0, Color("#2f7d57"))
		draw_arc(icon, 62.0, 0.0, TAU, 48, ink, 5.0)
		draw_polyline(PackedVector2Array([icon + Vector2(-30.0, 2.0), icon + Vector2(-8.0, 26.0), icon + Vector2(32.0, -24.0)]), ink, 10.0)
	else:
		var square := Rect2(icon - Vector2(58.0, 58.0), Vector2(116.0, 116.0))
		draw_rect(square, ink, false, 6.0)
		draw_line(icon + Vector2(-30.0, -30.0), icon + Vector2(30.0, 30.0), ink, 10.0)
		draw_line(icon + Vector2(30.0, -30.0), icon + Vector2(-30.0, 30.0), ink, 10.0)
	draw_string(get_theme_default_font(), center + Vector2(-50.0, 26.0), get_word(), HORIZONTAL_ALIGNMENT_LEFT, -1, 72, ink)
