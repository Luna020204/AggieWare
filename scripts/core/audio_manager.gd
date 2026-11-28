
extends Node
# Centralized music and jingle playback for the whole game

const AUDIO_LIBRARY: AudioLibrary = preload("res://resources/audio_library.tres")

var title_music: AudioStream
var gameplay_music: AudioStream
var win_jingle: AudioStream
var lose_jingle: AudioStream
var stage_clear_jingle: AudioStream
var game_over_jingle: AudioStream
var music_fade_seconds := 0.35
var max_gameplay_pitch := 1.18

var _music_player: AudioStreamPlayer
var _sfx_player: AudioStreamPlayer
var _music_tween: Tween
var _current_music: AudioStream
var _desired_music: AudioStream
var _progress := 0.0


func _ready() -> void:
	title_music = AUDIO_LIBRARY.title_music
	gameplay_music = AUDIO_LIBRARY.gameplay_music
	win_jingle = AUDIO_LIBRARY.win_jingle
	lose_jingle = AUDIO_LIBRARY.lose_jingle
	stage_clear_jingle = AUDIO_LIBRARY.stage_clear_jingle
	game_over_jingle = AUDIO_LIBRARY.game_over_jingle
	music_fade_seconds = AUDIO_LIBRARY.music_fade_seconds
	max_gameplay_pitch = AUDIO_LIBRARY.max_gameplay_pitch

	process_mode = Node.PROCESS_MODE_PAUSABLE

	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	_music_player.bus = "Master"
	_music_player.finished.connect(_on_music_finished)
	add_child(_music_player)

	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.name = "JinglePlayer"
	_sfx_player.bus = "Master"
	add_child(_sfx_player)

	GameState.setting_changed.connect(_on_setting_changed)
	_refresh_volumes()
	play_title_music()


func play_title_music() -> void:
	_play_music(title_music, 1.0)


func play_gameplay_music() -> void:
	_play_music(gameplay_music, _gameplay_pitch())


func play_win() -> void:
	_play_jingle(win_jingle)


func play_lose() -> void:
	_play_jingle(lose_jingle)


func play_stage_clear() -> void:
	_stop_music_for_end_jingle()
	_play_jingle(stage_clear_jingle)


func play_game_over() -> void:
	_stop_music_for_end_jingle()
	_play_jingle(game_over_jingle)


func set_progress(progress: float) -> void:
	_progress = clampf(progress, 0.0, 1.0)
	if _current_music == gameplay_music and is_instance_valid(_music_player):
		_music_player.pitch_scale = _gameplay_pitch()


func stop_music(fade_seconds: float = -1.0) -> void:
	if not is_instance_valid(_music_player) or _music_player.stream == null:
		return

	var duration := music_fade_seconds if fade_seconds < 0.0 else maxf(fade_seconds, 0.0)

	if duration <= 0.0:
		_kill_music_tween()
		_music_player.stop()
		_music_player.volume_db = 0.0
		_current_music = null
		return

	_kill_music_tween()
	_music_tween = create_tween()
	_music_tween.tween_property(_music_player, "volume_db", -40.0, duration)
	_music_tween.tween_callback(func() -> void:
		_music_player.stop()
		_music_player.volume_db = 0.0
		_current_music = null
	)


func _play_music(stream: AudioStream, pitch: float) -> void:
	_desired_music = stream

	if stream == null or not bool(GameState.get_setting(&"music_enabled", true)):
		return

	if _current_music == stream and _music_player.playing:
		_music_player.pitch_scale = pitch
		return

	_kill_music_tween()
	_current_music = stream
	_music_player.stream = stream
	_music_player.pitch_scale = pitch
	_music_player.volume_db = -40.0
	_music_player.play()

	if music_fade_seconds > 0.0:
		_music_tween = create_tween()
		_music_tween.tween_property(_music_player, "volume_db", 0.0, music_fade_seconds)
	else:
		_music_player.volume_db = 0.0


func _play_jingle(stream: AudioStream) -> void:
	if stream == null or not bool(GameState.get_setting(&"sfx_enabled", true)):
		return

	_sfx_player.stream = stream
	_sfx_player.play()


func _stop_music_for_end_jingle() -> void:
	_desired_music = null
	_current_music = null
	_kill_music_tween()

	if is_instance_valid(_music_player):
		_music_player.stop()
		_music_player.volume_db = 0.0


func _on_music_finished() -> void:
	if _current_music == gameplay_music \
	and _desired_music == gameplay_music \
	and bool(GameState.get_setting(&"music_enabled", true)):
		_music_player.pitch_scale = _gameplay_pitch()
		_music_player.play()


func _gameplay_pitch() -> float:
	return lerpf(1.0, max_gameplay_pitch, _progress)


func _kill_music_tween() -> void:
	if _music_tween != null and _music_tween.is_running():
		_music_tween.kill()
	_music_tween = null


func _on_setting_changed(setting_name: StringName, _value: Variant) -> void:
	if setting_name == &"music_enabled":
		if bool(GameState.get_setting(&"music_enabled", true)):
			if _desired_music == gameplay_music:
				play_gameplay_music()
			elif _desired_music == title_music:
				play_title_music()
		else:
			stop_music(0.0)

	elif setting_name == &"sfx_enabled" and not bool(GameState.get_setting(&"sfx_enabled", true)):
		_sfx_player.stop()


func _refresh_volumes() -> void:
	if not bool(GameState.get_setting(&"music_enabled", true)):
		_music_player.stop()

	if not bool(GameState.get_setting(&"sfx_enabled", true)):
		_sfx_player.stop()
