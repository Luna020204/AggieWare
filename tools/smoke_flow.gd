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
	print("FLOW_SMOKE_OK")
	quit()


func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		quit(1)
