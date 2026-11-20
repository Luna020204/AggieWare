extends SceneTree

## SCRUM-41 / SCRUM-57 smoke test: accessibility and control options.
## Run with: godot --headless --path . --script res://tools/smoke_accessibility.gd
## Prints ACCESSIBILITY_SMOKE_OK when every check passes.

var _failed := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await _accessibility_options()
	_reset_settings()
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


func _reset_settings() -> void:
	_gs().set_setting(&"timer_assist", 1.0)
	_gs().set_setting(&"result_cues", true)
	Engine.time_scale = 1.0


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error(message)


## Autoload singletons are not compile-time identifiers in a --script run.
func _gs() -> Node:
	return root.get_node("GameState")
