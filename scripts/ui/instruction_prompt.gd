class_name InstructionPrompt
extends Control

## SCRUM-39: instant instruction prompt shown before each microgame.
##
## One verb ("SWIPE!") plus a drawn control icon and a short hint
## ("MOUSE · DRAG"). The host (game flow or test launcher) adds the
## microgame with its processing disabled, shows this overlay, and starts the
## microgame when `finished` fires. The overlay blocks mouse input meanwhile.
##
## Prompt data lives in MicrogameCatalog (verb + icon per microgame).

signal finished

const DEFAULT_SECONDS := 1.0
const ICON_HINTS: Dictionary = {
	"click": "MOUSE · CLICK",
	"drag": "MOUSE · DRAG",
	"arrows_lr": "LEFT / RIGHT",
	"arrows": "ARROW KEYS",
}

var verb := "GO!"
var icon := "click"
var seconds := DEFAULT_SECONDS

var _icon_view: Control
var _verb_label: Label
var _done := false


## Creates a prompt for a catalog entry. Missing data falls back to "GO!".
static func for_entry(entry: Dictionary, show_seconds: float = DEFAULT_SECONDS) -> InstructionPrompt:
	var prompt := InstructionPrompt.new()
	prompt.verb = entry.get("verb", "GO!")
	prompt.icon = entry.get("icon", "click")
	prompt.seconds = show_seconds
	return prompt


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_PAUSABLE

	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.03, 0.08, 0.72)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)

	_verb_label = Label.new()
	_verb_label.text = verb
	_verb_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_verb_label.position = Vector2(0.0, 190.0)
	_verb_label.size = Vector2(1280.0, 140.0)
	_verb_label.pivot_offset = Vector2(640.0, 70.0)
	_verb_label.add_theme_font_size_override("font_size", 110)
	_verb_label.add_theme_color_override("font_color", Color("#ffd166"))
	_verb_label.add_theme_color_override("font_outline_color", Color("#0d1324"))
	_verb_label.add_theme_constant_override("outline_size", 18)
	add_child(_verb_label)

	_icon_view = Control.new()
	_icon_view.position = Vector2(560.0, 360.0)
	_icon_view.size = Vector2(160.0, 140.0)
	_icon_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon_view.draw.connect(_draw_icon)
	add_child(_icon_view)

	var hint := Label.new()
	hint.text = ICON_HINTS.get(icon, "")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.position = Vector2(0.0, 510.0)
	hint.size = Vector2(1280.0, 40.0)
	hint.add_theme_font_size_override("font_size", 26)
	hint.add_theme_color_override("font_color", Color("#f5f7ff"))
	add_child(hint)

	_verb_label.scale = Vector2(0.4, 0.4)
	var tween := create_tween()
	tween.tween_property(_verb_label, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Real-time wait so game speed / timer assist don't stretch the prompt;
	# still pausable so the pause menu freezes it.
	get_tree().create_timer(seconds, false, false, true).timeout.connect(finish)


## Ends the prompt early (also used by tests).
func finish() -> void:
	if _done:
		return
	_done = true
	finished.emit()
	queue_free()


func _draw_icon() -> void:
	var ink := Color("#f5f7ff")
	var accent := Color("#ffd166")
	match icon:
		"arrows_lr":
			_key(Vector2(20.0, 50.0), "◀", ink)
			_key(Vector2(90.0, 50.0), "▶", ink)
		"arrows":
			_key(Vector2(55.0, 0.0), "▲", ink)
			_key(Vector2(-15.0, 70.0), "◀", ink)
			_key(Vector2(55.0, 70.0), "▼", ink)
			_key(Vector2(125.0, 70.0), "▶", ink)
		_:
			# Mouse body with the left button highlighted.
			var body := Rect2(50.0, 10.0, 60.0, 96.0)
			_icon_view.draw_rect(body, ink, false, 4.0)
			_icon_view.draw_rect(Rect2(body.position + Vector2(3.0, 3.0), Vector2(27.0, 36.0)), accent)
			_icon_view.draw_line(Vector2(80.0, 10.0), Vector2(80.0, 46.0), ink, 3.0)
			_icon_view.draw_line(Vector2(50.0, 46.0), Vector2(110.0, 46.0), ink, 3.0)
			if icon == "drag":
				_icon_view.draw_line(Vector2(120.0, 60.0), Vector2(158.0, 60.0), accent, 6.0)
				_icon_view.draw_colored_polygon(PackedVector2Array([Vector2(160.0, 48.0), Vector2(160.0, 72.0), Vector2(176.0, 60.0)]), accent)
			else:
				for ray: Vector2 in [Vector2(-1.0, -1.0), Vector2(-1.4, 0.0), Vector2(-1.0, 1.0)]:
					var start := Vector2(42.0, 30.0) + ray * 8.0
					_icon_view.draw_line(start, start + ray * 18.0, accent, 4.0)


func _key(at: Vector2, glyph: String, ink: Color) -> void:
	var rect := Rect2(at, Vector2(60.0, 60.0))
	_icon_view.draw_rect(rect, Color("#22304f"))
	_icon_view.draw_rect(rect, ink, false, 3.0)
	_icon_view.draw_string(get_theme_default_font(), at + Vector2(14.0, 44.0), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, 32, ink)
