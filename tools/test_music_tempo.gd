extends "res://tools/test_collection.gd"
## Measure decoded MP3 seconds per second of mixed PCM through the real week flow.

var capture := AudioEffectCapture.new()
var music: AudioStreamPlayer

func _run() -> void:
	create_timer(45.0, true, false, true).timeout.connect(func() -> void: quit(1))
	var flow: Variant = _mount_flow()
	music = root.get_node("AudioManager/MusicPlayer")
	capture.buffer_length = 3.0
	AudioServer.add_bus_effect(0, capture)
	_check(music.stream is AudioStreamMP3 and music.playing, "The real title track is playing")
	flow._show_stage_select()
	flow._start_stage(0)
	for day: int in flow.week_plan.stages.size():
		var stage: StageDefinition = flow.week_plan.stages[day]
		for wins: int in stage.win_goal():
			var game: Variant = _prepare_round(flow)
			DRIVER.tick(game, 0.02)
			_check(is_equal_approx(music.pitch_scale, game.playback_speed), "Music and active game share the stage ramp")
			if day == 0 or wins == 0:
				await _measure("%s win %d tier %d" % [stage.title, wins, game.difficulty], game.playback_speed)
			if day == 1 and wins == 0:
				var before_loss: float = game.playback_speed
				DRIVER.finish(game, false)
				await _wait_result(flow)
				_finish_bike(flow)
				game = _prepare_round(flow)
				DRIVER.tick(game, 0.02)
				_check(flow.day_wins == 0 and flow.lives == 2, "Loss keeps the win count")
				await _measure("Tuesday retry", before_loss)
			if day == 4 and wins == 0:
				var state := root.get_node("GameState")
				state.set_setting(&"timer_assist", 1.5)
				_check(is_equal_approx(Engine.time_scale, game.playback_speed / 1.5), "Assist changes the active game clock")
				await _measure("Friday with 50% timer assist", Engine.time_scale)
				state.set_setting(&"timer_assist", 1.0)
			var kind := stage.games[flow.current_round].scene_path.get_file().get_basename()
			_win_game(kind, game)
			await _wait_result(flow)
			if wins + 1 < stage.win_goal():
				_finish_bike(flow)
		flow._advance_after_clear()
		if day + 1 < flow.week_plan.stages.size():
			_finish_bike(flow)
	var state := root.get_node("GameState")
	state.set_setting(&"music_enabled", false)
	_check(not music.playing, "Muting stops the track")
	state.set_setting(&"music_enabled", true)
	_check(is_equal_approx(music.pitch_scale, 1.0), "Unmuting restores title tempo after Friday")
	await _measure("Back at title", 1.0)
	AudioServer.remove_bus_effect(0, AudioServer.get_bus_effect_count(0) - 1)
	await _dispose(flow)
	state.set_setting(&"music_enabled", false)
	state.set_setting(&"music_enabled", true)
	_check(not music.playing, "Leaving the week releases music ownership")
	print("Music tempo checks: %d; failures: %d" % [checks, failures])
	if failures == 0:
		print("MUSIC_TEMPO_OK")
	quit(1 if failures else 0)

func _measure(label: String, expected: float) -> void:
	# Let the mixer finish its current block before sampling the new rate.
	await create_timer(0.15, true, false, true).timeout
	capture.clear_buffer()
	var start := music.get_playback_position()
	await create_timer(1.25, true, false, true).timeout
	var seconds := music.get_playback_position() - start
	var frames := capture.get_frames_available()
	if not _check(frames > 0, label + " produced mixed PCM frames"):
		return
	var measured := seconds * AudioServer.get_mix_rate() / frames
	var peak := 0.0
	for sample: Vector2 in capture.get_buffer(frames):
		peak = maxf(peak, maxf(absf(sample.x), absf(sample.y)))
	print("TEMPO %s: expected %.4fx, measured %.4fx, peak %.4f" % [label, expected, measured, peak])
	_check(peak > 0.001 and music.playing, label + " contains audible track samples")
	_check(absf(measured - expected) < 0.025, label + " advances the MP3 playhead at the expected rate")
