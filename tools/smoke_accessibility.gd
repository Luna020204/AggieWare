extends SceneTree

## SCRUM-41 / SCRUM-57 smoke test: accessibility and control options.
## Run with: godot --headless --path . --script res://tools/smoke_accessibility.gd
## Prints ACCESSIBILITY_SMOKE_OK when every check passes.

const TEST_SETTINGS := "user://smoke_settings.cfg"

var _failed := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	# Never touch the player's real settings file.
	_store().path = TEST_SETTINGS
	await _accessibility_options()
	await _control_options()
	_reset_settings()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS))
	if not _failed:
		print("ACCESSIBILITY_SMOKE_OK")
	quit(1 if _failed else 0)


# --- SCRUM-41 ----------------------------------------------------------------

func _accessibility_options() -> void:
	_reset_settings()
	_assert(is_equal_approx(Accessibility.timer_assist(), 1.0), "a11y: timer assist not off by default")
	_assert(Accessibility.result_cues_enabled(), "a11y: result cues not on by default")

	# The pause/settings menu edits the real settings.
	var menu: Variant = load("res://scenes/ui/settings_pause_menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	menu._timer_assist_option.select(2)
	menu._timer_assist_option.item_selected.emit(2)
	_assert(is_equal_approx(Accessibility.timer_assist(), 1.5), "a11y: menu did not set +50% time")
	menu._result_cues_toggle.button_pressed = false
	_assert(not Accessibility.result_cues_enabled(), "a11y: menu did not turn result cues off")
	menu._on_reset_pressed()
	_assert(is_equal_approx(Accessibility.timer_assist(), 1.0) and Accessibility.result_cues_enabled(), "a11y: reset defaults did not reset accessibility")
	menu.queue_free()
	await process_frame

	# Week flow: timer assist slows the microgame only while it runs.
	_gs().set_setting(&"timer_assist", 1.25)
	var flow: Variant = load("res://scenes/core/game_flow.tscn").instantiate()
	root.add_child(flow)
	await process_frame
	flow._start_stage(0)
	await process_frame
	_assert(is_equal_approx(Engine.time_scale, 1.0), "a11y: game slowed during the prompt")
	flow._prompt.finish()
	await process_frame
	_assert(is_equal_approx(Engine.time_scale, 0.8), "a11y: +25%% time did not slow the microgame (%.2f)" % Engine.time_scale)
	var before: float = flow._active_scene._time_left
	await create_timer(0.5, true, false, true).timeout
	var used: float = before - flow._active_scene._time_left
	_assert(used < 0.47 and used > 0.3, "a11y: 0.5 s real time used %.2f s of round time" % used)
	flow._active_scene._finish_round(false, "test")
	await process_frame
	_assert(is_equal_approx(Engine.time_scale, 1.0), "a11y: speed not restored after the round")
	_assert(is_instance_valid(flow._result_cue) and flow._result_cue.get_word() == "MISS", "a11y: no MISS result cue")
	await create_timer(0.9, true, false, true).timeout
	_assert(not is_instance_valid(flow._result_cue), "a11y: result cue not cleared after the round")

	# Cues off: no banner, no warning glyph.
	_gs().set_setting(&"result_cues", false)
	flow._start_stage(3)
	await process_frame
	flow._prompt.finish()
	await process_frame
	flow._active_scene._finish_round(true, "test")
	await process_frame
	_assert(not is_instance_valid(flow._result_cue), "a11y: cue shown with cues off")
	flow.queue_free()
	await process_frame

	var hud: Variant = load("res://scenes/ui/game_hud.tscn").instantiate()
	root.add_child(hud)
	await process_frame
	hud.set_round_status(2.0, 8.0, 3, 0, 0, 5)
	_assert(not hud._timer_label.text.contains("⚠"), "a11y: HUD warning shown with cues off")
	_gs().set_setting(&"result_cues", true)
	hud.set_round_status(2.0, 8.0, 3, 0, 0, 5)
	_assert(hud._timer_label.text.contains("⚠"), "a11y: HUD low-time warning missing")
	hud.set_round_status(6.0, 8.0, 3, 0, 0, 5)
	_assert(not hud._timer_label.text.contains("⚠"), "a11y: HUD warning shown with time left")
	hud.queue_free()

	# Launcher: assist stacks on the test speed; a WIN shows CLEAR.
	_gs().set_setting(&"timer_assist", 1.5)
	var launcher: Variant = load("res://scenes/debug/microgame_launcher.tscn").instantiate()
	root.add_child(launcher)
	await process_frame
	launcher.launch(0, 0, 2)
	await process_frame
	_assert(is_equal_approx(Engine.time_scale, 1.0 / 1.5), "a11y: launcher ignored timer assist (%.2f)" % Engine.time_scale)
	launcher._active._finish_round(true, "test")
	await process_frame
	_assert(is_instance_valid(launcher._result_cue) and launcher._result_cue.get_word() == "CLEAR", "a11y: launcher shows no CLEAR cue")
	launcher.queue_free()
	await process_frame
	Engine.time_scale = 1.0


# --- SCRUM-57 ----------------------------------------------------------------

func _control_options() -> void:
	_reset_settings()
	var store := _store()
	store.reset_bindings()
	var menu: Variant = load("res://scenes/ui/settings_pause_menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	_gs().pause_game()
	await process_frame
	menu._show_controls(true)
	for i: int in 3:
		await process_frame  # let the containers lay the panel out
	_assert(menu._controls_panel.visible and not menu._main_panel.visible, "controls: panel did not open")
	_assert(menu._bind_buttons[&"game_up"].text.contains("W"), "controls: Up does not show its default key (%s)" % menu._bind_buttons[&"game_up"].text)

	# Rebind Up to I through the menu with a real key event.
	await _click(menu._bind_buttons[&"game_up"].get_global_rect().get_center())
	_assert(menu._waiting_action == &"game_up", "controls: clicking Up did not start rebinding")
	await _key(KEY_I)
	_assert(_bound(&"game_up", KEY_I) and not _bound(&"game_up", KEY_W), "controls: Up was not rebound to I")
	_assert(menu._bind_buttons[&"game_up"].text == "I", "controls: button text not updated (%s)" % menu._bind_buttons[&"game_up"].text)
	Input.action_release(&"game_up")
	var press := InputEventKey.new()
	press.physical_keycode = KEY_I
	_assert(InputMap.event_is_action(press, &"game_up"), "controls: I does not trigger game_up")

	# Escape cancels without unbinding or unpausing.
	menu._start_rebind(&"game_down")
	await _key(KEY_ESCAPE)
	_assert(_bound(&"game_down", KEY_S) and menu._waiting_action == &"", "controls: Escape did not cancel rebinding")
	_assert(_gs().is_paused, "controls: Escape during rebinding unpaused the game")

	# Conflicts are reported.
	menu._start_rebind(&"game_left")
	await _key(KEY_D)
	_assert(menu._controls_status.text.contains("also used by Right"), "controls: conflict not reported: %s" % menu._controls_status.text)

	# Bindings and options persist across a reload.
	_gs().set_setting(&"timer_assist", 1.5)
	_gs().set_setting(&"mash_hold", true)
	store.save_settings()
	# Simulate a fresh session: wipe the in-memory state without auto-saving.
	store._loading = true
	InputActions_reset_all()
	_gs().set_setting(&"timer_assist", 1.0)
	_gs().set_setting(&"mash_hold", false)
	store._loading = false
	store.load_settings()
	_assert(_bound(&"game_up", KEY_I), "controls: rebinding not restored from the settings file")
	_assert(is_equal_approx(float(_gs().get_setting(&"timer_assist")), 1.5) and _gs().get_setting(&"mash_hold") == true, "controls: options not restored from the settings file")

	# Reset keys restores defaults.
	store.reset_bindings()
	_assert(_bound(&"game_up", KEY_W) and _bound(&"game_up", KEY_UP) and not _bound(&"game_up", KEY_I), "controls: reset did not restore Up")
	_gs().resume_game()
	menu.queue_free()
	await process_frame

	# Hold instead of mash: holding the key keeps producing presses.
	var inputs := root.get_node("InputActions")
	_gs().set_setting(&"mash_hold", true)
	Input.action_press(&"game_mash")
	var ticks := 0
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < 600:
		await process_frame
		if inputs.is_just_pressed(&"game_mash"):
			ticks += 1
	Input.action_release(&"game_mash")
	_assert(ticks >= 3, "controls: holding mash gave only %d presses" % ticks)
	_gs().set_setting(&"mash_hold", false)
	Input.action_press(&"game_mash")
	ticks = 0
	start = Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < 600:
		await process_frame
		if inputs.is_just_pressed(&"game_mash"):
			ticks += 1
	Input.action_release(&"game_mash")
	_assert(ticks <= 1, "controls: mash repeats with hold off (%d)" % ticks)


func InputActions_reset_all() -> void:
	var inputs := root.get_node("InputActions")
	for action: StringName in _store().REBINDABLE:
		inputs.reset_action(action)


func _bound(action: StringName, keycode: int) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey and event.physical_keycode == keycode:
			return true
	return false


func _key(keycode: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	event.keycode = keycode
	event.pressed = true
	root.push_input(event)
	await process_frame
	var up := event.duplicate()
	up.pressed = false
	root.push_input(up)
	await process_frame


func _click(at: Vector2) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = at
		event.global_position = at
		root.push_input(event, true)
		await process_frame


func _store() -> Node:
	return root.get_node("SettingsStore")


func _reset_settings() -> void:
	_gs().set_setting(&"timer_assist", 1.0)
	_gs().set_setting(&"result_cues", true)
	_gs().set_setting(&"mash_hold", false)
	Engine.time_scale = 1.0


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error(message)


## Autoload singletons are not compile-time identifiers in a --script run.
func _gs() -> Node:
	return root.get_node("GameState")
