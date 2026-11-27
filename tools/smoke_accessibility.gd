extends SceneTree

## SCRUM-41 / SCRUM-57 smoke test: accessibility and control options.
## Run with: godot --headless --path . --script res://tools/smoke_accessibility.gd
## Prints ACCESSIBILITY_SMOKE_OK when every check passes.

const TEST_SETTINGS := "user://smoke_settings.cfg"
const DRIVER = preload("res://tools/microgame_test_driver.gd")

var _failed := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	# Never touch the player's real settings file.
	_store().path = TEST_SETTINGS
	await _accessibility_options()
	await _native_host_options()
	await _control_options()
	_reset_settings()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS))
	if not _failed:
		print("ACCESSIBILITY_SMOKE_OK")
	quit(1 if _failed else 0)


# --- SCRUM-41 ----------------------------------------------------------------

func _accessibility_options() -> void:
	_reset_settings()
	_assert(is_equal_approx(Accessibility.timer_assist(), 1.0), "timer assist defaults to off")
	_assert(Accessibility.result_cues_enabled(), "result symbols default to enabled")
	var menu: Variant = load("res://scenes/ui/settings_pause_menu.tscn").instantiate()
	root.add_child(menu)
	menu._timer_assist_option.select(2)
	menu._timer_assist_option.item_selected.emit(2)
	_assert(is_equal_approx(Accessibility.timer_assist(), 1.5), "menu sets +50% time")
	menu._result_cues_toggle.button_pressed = false
	_assert(not Accessibility.result_cues_enabled(), "menu disables optional result symbols")
	menu._on_reset_pressed()
	_assert(is_equal_approx(Accessibility.timer_assist(), 1.0) and Accessibility.result_cues_enabled(), "menu restores accessibility defaults")
	menu.queue_free()
	await process_frame

	_gs().set_setting(&"timer_assist", 1.25)
	var flow: Variant = load("res://scenes/core/game_flow.tscn").instantiate()
	flow.result_delay = 0.2
	root.add_child(flow)
	flow._start_stage(0)
	var game: Variant = flow._active_scene
	game.set_process(false)
	_assert(is_equal_approx(Engine.time_scale, 1.0), "introduction keeps normal speed")
	var before: float = game.get_seconds_left()
	game._process(0.2)
	_assert(is_equal_approx(game.get_seconds_left(), before), "introduction holds the round clock")
	game.skip_intro()
	_assert(is_equal_approx(Engine.time_scale, 0.8), "+25% time applies only after introduction")
	game.set_process(true)
	await create_timer(0.5, true, false, true).timeout
	game.set_process(false)
	var used: float = before - game.get_seconds_left()
	_assert(used > 0.25 and used < 0.49, "half a real second consumes assisted game time: %.2f" % used)
	game._finish_round(false, "TEST RESULT")
	_assert(is_equal_approx(Engine.time_scale, 1.0), "result restores normal speed")
	_assert(flow.state == flow.FlowState.RESULT, "flow waits for result presentation")
	game._process(0.1)
	_assert(flow.state == flow.FlowState.RESULT, "result remains until its configured duration")
	game._process(0.11)
	_assert(flow.state == flow.FlowState.TRANSITION, "result completion advances the host")

	# Turning symbols off still preserves mandatory text and its presentation time.
	_gs().set_setting(&"result_cues", false)
	flow.week_plan = flow.week_plan.duplicate(true)
	flow.week_plan.stages[3].required_wins = 1
	flow._start_round(3, 0)
	game = flow._active_scene
	game.set_process(false)
	game.skip_intro()
	game._finish_round(true, "TEST CLEAR")
	_assert(flow.state == flow.FlowState.RESULT, "result text still has its presentation phase with symbols off")
	game._process(0.21)
	_assert(flow.state == flow.FlowState.STAGE_CLEAR, "result completion works with symbols off")
	flow.queue_free()
	await process_frame

	# Independent F6 rounds apply assist too, and leaving a round restores speed.
	_gs().set_setting(&"timer_assist", 1.5)
	var standalone: Variant = load("res://scenes/microgames/canvas.tscn").instantiate()
	standalone.prompt_seconds = 0.0
	root.add_child(standalone)
	_assert(is_equal_approx(Engine.time_scale, 1.0 / 1.5), "standalone round applies timer assist")
	standalone._start_round()
	_assert(is_equal_approx(Engine.time_scale, 1.0 / 1.5), "standalone retry does not compound timer assist")
	root.remove_child(standalone)
	standalone.queue_free()
	_assert(is_equal_approx(Engine.time_scale, 1.0), "standalone cancellation restores speed")

	var launcher: Variant = load("res://scenes/debug/microgame_launcher.tscn").instantiate()
	root.add_child(launcher)
	launcher.launch(0, 0, 5)
	_assert(is_equal_approx(Engine.time_scale, 1.0), "launcher introduction runs at normal speed")
	launcher._active.skip_intro()
	_assert(is_equal_approx(Engine.time_scale, 2.0 / 1.5), "launcher speed stacks with timer assist")
	var obsolete: Node = launcher._active
	var old_token: int = launcher._run_token
	launcher.launch(1, 0, 3)
	launcher._active.skip_intro()
	Accessibility.end_microgame(obsolete)
	_assert(is_equal_approx(Engine.time_scale, 1.25 / 1.5), "stale owner does not reset replacement round speed")
	launcher._on_result_finished(old_token)
	_assert(launcher._running and not launcher._menu.visible, "stale result cannot stop replacement game")
	launcher._active.set_process(false)
	launcher._active._finish_round(true, "TEST CLEAR")
	_assert(is_equal_approx(Engine.time_scale, 1.0), "launcher result restores speed")
	launcher._active._process(launcher.RESULT_DELAY + 0.01)
	_assert(launcher._menu.visible and not launcher._running, "launcher returns after shared result fade")
	launcher.show_prompt = false
	launcher.launch(0, 0, 1)
	_assert(is_equal_approx(Engine.time_scale, 0.75 / 1.5), "skip-intro launcher applies assist immediately")
	launcher.stop()
	_assert(is_equal_approx(Engine.time_scale, 1.0), "stopping launcher restores speed")
	launcher.queue_free()
	await process_frame


func _native_host_options() -> void:
	_reset_settings()
	_gs().set_setting(&"timer_assist", 1.25)
	var catalog: Script = load("res://scripts/core/microgame_catalog.gd")
	var launcher: Variant = load("res://scenes/debug/microgame_launcher.tscn").instantiate()
	root.add_child(launcher)
	for game_id: String in ["scope", "swipe", "awake", "microscope"]:
		launcher.launch(catalog.find_index(game_id), 1, 4)
		var session: Variant = launcher._active
		DRIVER.freeze(session)
		_check_native_theme(session, catalog.ENTRIES[catalog.find_index(game_id)]["scene"], game_id)
		_assert(session.uses_native_hud() and not launcher._hud.visible, game_id + ": native HUD is the only visible timer")
		if session.get_intro_seconds() > 0.0:
			_assert(is_equal_approx(Engine.time_scale, 1.0) and not session.is_playing(), game_id + ": native intro precedes assistance")
			var intro_time: float = session.get_seconds_left()
			DRIVER.tick(session, 0.25)
			_assert(is_equal_approx(session.get_seconds_left(), intro_time), game_id + ": native intro holds its timer")
		else:
			_assert(session.is_playing(), game_id + ": no artificial intro was inserted")
		DRIVER.skip_intro(session)
		_assert(is_equal_approx(Engine.time_scale, 1.2), game_id + ": native speed combines with timer assistance")
		var before: float = session.get_seconds_left()
		DRIVER.tick(session, 0.25 * Engine.time_scale)
		_assert(is_equal_approx(before - session.get_seconds_left(), 0.3), game_id + ": native timer follows the assisted engine delta")
		if game_id == "swipe":
			var native: Variant = DRIVER.body(session)
			native.begin_drag(native._card.position + Vector2(5, 5))
			_assert(native._dragging, "swipe: drag began before pause")
		_gs().pause_game()
		before = session.get_seconds_left()
		DRIVER.tick(session, 2.0)
		_assert(is_equal_approx(before, session.get_seconds_left()), game_id + ": paused native clock does not advance")
		if game_id == "swipe":
			_assert(not DRIVER.body(session)._dragging and DRIVER.body(session)._held == null, "swipe: pause cancels held card and timing")
		_gs().resume_game()
		var old_body: Variant = DRIVER.body(session)
		session.restart_round()
		DRIVER.freeze(session)
		DRIVER.skip_intro(session)
		before = session.get_seconds_left()
		old_body.round_completed.emit(false)
		old_body.time_changed.emit(0.0, 999.0)
		_assert(not session.is_round_finished() and is_equal_approx(before, session.get_seconds_left()), game_id + ": restarted round ignores old native callbacks")
		_assert(is_equal_approx(Engine.time_scale, 1.2), game_id + ": restart does not compound assistance")
		session.result_seconds = 0.01
		DRIVER.finish(session, true, "NATIVE RESULT")
		_assert(is_equal_approx(Engine.time_scale, 1.0), game_id + ": native result restores playback speed")
		_gs().pause_game()
		DRIVER.tick(session, 3.0)
		_assert(not launcher._menu.visible, game_id + ": pause holds the native result")
		_gs().resume_game()
		DRIVER.tick(session, 1.39)
		_assert(not launcher._menu.visible, game_id + ": host cannot shorten native result visibility")
		DRIVER.tick(session, 0.02)
		_assert(launcher._menu.visible, game_id + ": host returns only after native result presentation")
		await process_frame
	# A stale native-session owner must not reset a replacement's speed.
	launcher.show_prompt = false
	launcher.launch(catalog.find_index("swipe"), 0, 5)
	var obsolete: Node = launcher._active
	var old_token: int = launcher._run_token
	launcher.launch(catalog.find_index("microscope"), 0, 4)
	DRIVER.freeze(launcher._active)
	Accessibility.end_microgame(obsolete)
	launcher._on_result_finished(old_token)
	_assert(is_equal_approx(Engine.time_scale, 1.2) and launcher._running, "native stale owner/result cannot alter replacement speed or navigation")
	launcher.stop()
	_assert(is_equal_approx(Engine.time_scale, 1.0), "native cancellation restores prior engine speed")
	launcher.queue_free()
	await process_frame


func _check_native_theme(session: Variant, scene_path: String, game_id: String) -> void:
	var original: Variant = load(scene_path).instantiate()
	original.difficulty = session.difficulty
	root.add_child(original)
	DRIVER.freeze(original)
	var hosted: Variant = DRIVER.body(session)
	_assert(hosted.get_theme_default_font() == original.get_theme_default_font(), game_id + ": default font matches raw F6")
	for property_name: String in ["_timer_label", "_status_label"]:
		var expected: Label = original.get(property_name)
		var actual: Label = hosted.get(property_name)
		_assert(actual.get_theme_font("font") == expected.get_theme_font("font"), game_id + ": native label font survives host theme")
		_assert(actual.get_theme_color("font_shadow_color") == expected.get_theme_color("font_shadow_color"), game_id + ": native label shadow color matches raw F6")
		for axis: String in ["shadow_offset_x", "shadow_offset_y"]:
			_assert(actual.get_theme_constant(axis) == expected.get_theme_constant(axis), game_id + ": native label shadow offset matches raw F6")
	if game_id == "swipe" or game_id == "awake":
		_assert(hosted._timer_label.get_theme_font("font") == load("res://assets/fonts/aggie_pixel.fnt"), game_id + ": native PixelText still resolves AggiePixel")
		_assert(hosted.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, game_id + ": native pixel filter is retained")
	else:
		_assert(session.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR, game_id + ": wrapper isolates the host's nearest filter")
	if game_id == "scope":
		_assert(hosted._choice_buttons[0].get_theme_font("font").resource_path == "res://assets/fonts/aggie_mono.fnt", "scope: authored case-sensitive choice font (AggieMono) is kept")
	root.remove_child(original)
	original.free()

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
	var retry_key := InputEventKey.new()
	retry_key.physical_keycode = KEY_T
	store.rebind(&"game_retry", retry_key)
	store.highest_unlocked_day = 0
	store.unlock_day(3)
	store.unlock_day(1)
	store.save_settings()
	# Simulate a fresh session: wipe the in-memory state without auto-saving.
	store._loading = true
	store.highest_unlocked_day = 0
	InputActions_reset_all()
	_gs().set_setting(&"timer_assist", 1.0)
	_gs().set_setting(&"mash_hold", false)
	store._loading = false
	store.load_settings()
	_assert(store.highest_unlocked_day == 3, "Cleared days survive reload and replaying an earlier day")
	_assert(_bound(&"game_up", KEY_I), "controls: rebinding not restored from the settings file")
	_assert(_bound(&"game_retry", KEY_T), "controls: standalone retry binding was not restored")
	_assert(is_equal_approx(float(_gs().get_setting(&"timer_assist")), 1.5) and _gs().get_setting(&"mash_hold") == true, "controls: options not restored from the settings file")
	var malformed := ConfigFile.new()
	malformed.set_value("settings", "timer_assist", "invalid")
	malformed.set_value("settings", "mash_hold", "invalid")
	malformed.set_value("bindings", "game_up", "invalid")
	malformed.set_value("bindings", "game_down", [KEY_NONE, KEY_ESCAPE, "invalid"])
	malformed.save(TEST_SETTINGS)
	store.load_settings()
	_assert(store.highest_unlocked_day == 0, "Older saves without day progress start on Monday")
	_assert(_bound(&"game_up", KEY_I) and _bound(&"game_down", KEY_S), "controls: malformed saved bindings preserve valid controls")
	_assert(is_equal_approx(Accessibility.timer_assist(), 1.5) and _gs().get_setting(&"mash_hold") == true, "controls: malformed saved options preserve valid settings")

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
	Accessibility.end_microgame()
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
