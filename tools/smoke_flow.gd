extends SceneTree

## Run with: godot --headless --path . --script res://tools/smoke_flow.gd


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var flow: Variant = load("res://scenes/core/game_flow.tscn").instantiate()
	root.add_child(flow)
	await process_frame
	flow._show_stage_select()
	flow._start_stage(0)
	await process_frame
	_assert(flow.state == flow.FlowState.PLAYING, "Monday did not start")
	_assert(is_instance_valid(flow._hud), "HUD was not mounted")
	_assert(flow._hud._progress_label.text == "DAY  1 / 5", "HUD progress is wrong")
	var canvas: Variant = flow._active_scene
	_assert(canvas != null and canvas._time_left > 0.0, "Canvas round was not started")
	canvas._finish_round(true, "Submitted")
	await create_timer(0.85, false).timeout
	_assert(flow.state == flow.FlowState.STAGE_CLEAR, "Successful round did not clear stage")
	_assert(flow.score == 100, "Score did not update")
	flow._advance_after_clear()
	await process_frame
	_assert(flow.state == flow.FlowState.TRANSITION, "Bike transition was skipped")
	_assert(flow._active_scene.lives == 3 and flow._active_scene.score == 100, "Bike context is wrong")
	flow._active_scene._finish_transition()
	await process_frame
	_assert(flow.state == flow.FlowState.PLAYING and flow.current_stage == 1, "Tuesday did not start")
	var schedule: Variant = flow._active_scene
	_assert(schedule.name == "ScheduleBuilder", "Tuesday did not load Schedule Builder")
	schedule._register(0)
	_assert(schedule._registered == 0, "Early registration was accepted")
	schedule._seconds_left = schedule.WINDOWS[schedule.difficulty]
	for index: int in schedule._buttons.size():
		schedule._register(index)
	_assert(schedule._ended and schedule._registered == 3, "Schedule did not complete")
	await create_timer(0.85, false).timeout
	_assert(flow.state == flow.FlowState.STAGE_CLEAR, "Schedule win did not clear stage")
	flow._advance_after_clear()
	await process_frame
	flow._active_scene._finish_transition()
	await process_frame
	_assert(flow.current_stage == 2 and flow._active_scene.name == "StayFocused", "Wednesday did not load Stay Focused")
	var focus: Variant = flow._active_scene
	focus._spawn_thought()
	focus._thoughts[0].position = focus._shield.position
	focus._process(0.01)
	_assert(focus._blocked == 1, "Shield did not block a thought")
	for index: int in 3:
		flow._active_scene._finish_round(false, "Time's up")
		await create_timer(0.85, false).timeout
		if index < 2:
			_assert(flow.state == flow.FlowState.TRANSITION, "Retry transition missing")
			flow._active_scene._finish_transition()
			await process_frame
	_assert(flow.state == flow.FlowState.GAME_OVER, "Three losses did not end game")
	flow._retry_stage()
	await process_frame
	_assert(flow.state == flow.FlowState.PLAYING and flow.lives == 3, "Retry did not reset lives")
	flow._start_stage(3)
	await process_frame
	_assert(flow._active_scene.name == "Gates", "Thursday did not load Gates")
	var gates: Variant = flow._active_scene
	var correct_gate: Button
	for card: Button in gates._cards:
		if card.get_meta("kind") == "GATE" and card.get_meta("value") == gates._gate_name:
			correct_gate = card
	_assert(correct_gate != null, "Correct gate is unavailable")
	for card: Button in gates._cards:
		if card == correct_gate or card.get_meta("kind") == "A" or card.get_meta("kind") == "B":
			var zone: PanelContainer = gates._zones[card.get_meta("kind")]
			card.position = zone.position
			gates._dragging = card
			gates._finish_drag()
	_assert(gates._ended, "Completed circuit did not finish")
	await create_timer(0.85, false).timeout
	_assert(flow.state == flow.FlowState.STAGE_CLEAR, "Gates win did not clear stage")
	flow._advance_after_clear()
	await process_frame
	flow._active_scene._finish_transition()
	await process_frame
	_assert(flow.current_stage == 4 and flow._active_scene.name == "CanvasMicrogame", "Friday did not start")
	flow._active_scene._finish_round(true, "Submitted")
	await create_timer(0.85, false).timeout
	_assert(flow.state == flow.FlowState.STAGE_CLEAR, "Friday did not clear")
	flow._advance_after_clear()
	_assert(flow.state == flow.FlowState.TITLE, "Finished week did not return to title")
	print("FLOW_SMOKE_OK")
	quit()


func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		quit(1)
