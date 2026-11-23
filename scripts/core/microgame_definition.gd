@tool
class_name MicrogameDefinition
extends Resource
## One playable round in a day. Paths are loaded on demand by the host.
@export var id: StringName
@export var title := "Microgame"
@export var prompt := "PLAY"
## Opt-in teaching for framework games only; ordinary rounds keep timed intros.
@export var tutorial_enabled := false
@export_file("*.tscn") var scene_path := ""
@export_range(0, 2, 1) var difficulty := 0
@export_range(0.0, 120.0, 0.1) var round_seconds_override := 0.0

func load_scene() -> PackedScene:
	return load(scene_path) as PackedScene if ResourceLoader.exists(scene_path) else null
