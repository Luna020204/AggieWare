extends Control
signal exited
const UI = preload("res://scripts/ui/microgame_ui.gd")
var selected_index := 0
var difficulty := 0
var active: Control
var menu: VBoxContainer
var result: Label
var game_picker: OptionButton
var tier_picker: OptionButton
var token := 0
var back: Button

func _ready() -> void:
	UI.apply_theme(self)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("172746")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	menu = VBoxContainer.new()
	menu.custom_minimum_size = Vector2(680, 400)
	menu.add_theme_constant_override("separation", 24)
	center.add_child(menu)
	var title := Label.new()
	title.text = "PRACTICE"
	title.add_theme_font_size_override("font_size", 42)
	menu.add_child(title)
	var hint := Label.new()
	hint.text = "Replay any game. Your week progress stays unchanged."
	hint.add_theme_font_size_override("font_size", 14)
	menu.add_child(hint)
	game_picker = OptionButton.new()
	for entry: Dictionary in MicrogameCatalog.ENTRIES:
		game_picker.add_item(entry.title)
	game_picker.item_selected.connect(func(i: int): selected_index = i)
	menu.add_child(game_picker)
	tier_picker = OptionButton.new()
	for tier: String in MicrogameCatalog.DIFFICULTY_NAMES: tier_picker.add_item(tier)
	tier_picker.item_selected.connect(func(i: int): difficulty = i)
	menu.add_child(tier_picker)
	var play := Button.new()
	play.text = "PLAY / REPLAY"
	play.pressed.connect(launch)
	menu.add_child(play)
	result = Label.new()
	result.text = "Choose a game and difficulty."
	result.add_theme_font_size_override("font_size", 21)
	menu.add_child(result)
	var leave := Button.new()
	leave.text = "BACK TO TITLE"
	leave.pressed.connect(func(): exited.emit())
	menu.add_child(leave)
	back = Button.new()
	back.text = "BACK TO PRACTICE"
	back.position = Vector2(20, 665)
	back.pressed.connect(stop)
	add_child(back)
	back.hide()
	game_picker.grab_focus()

func launch() -> void:
	stop()
	active = MicrogameCatalog.instantiate(MicrogameCatalog.ENTRIES[selected_index], difficulty)
	if active == null:
		result.text = "This game could not be opened. Choose another."
		return
	active.show_internal_timer = true
	active.round_completed.connect(_completed.bind(token))
	active.result_finished.connect(_finished.bind(token))
	menu.hide()
	add_child(active)
	move_child(back, get_child_count()-1)
	back.show()
	back.release_focus()

func _completed(success: bool, run: int) -> void:
	if run != token: return
	result.text = "SUCCESS! Play again?" if success else "TRY AGAIN! No lives lost."

func _finished(run: int) -> void:
	_stop_finished_run.call_deferred(run)

func _stop_finished_run(run: int) -> void:
	# Recheck when deferred work runs: the player may already have replayed.
	if run == token: stop()

func stop() -> void:
	token += 1
	if is_instance_valid(active):
		remove_child(active)
		active.queue_free()
	active = null
	if menu != null:
		menu.show()
		back.hide()
		game_picker.grab_focus()
