@tool
class_name AudioLibrary
extends Resource
## Assign imported audio files to these fields in resources/audio_library.tres.

@export_group("Music")
@export var title_music: AudioStream
@export var gameplay_music: AudioStream
@export_range(0.0, 2.0, 0.05) var music_fade_seconds := 0.35
@export_range(1.0, 1.5, 0.01) var max_gameplay_pitch := 1.18

@export_group("Jingles")
@export var startup_jingle: AudioStream
@export var win_jingle: AudioStream
@export var lose_jingle: AudioStream
@export var stage_clear_jingle: AudioStream
@export var game_over_jingle: AudioStream
