@tool
class_name WeekPlan
extends Resource

@export var stages: Array[StageDefinition] = []

func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if stages.is_empty():
		errors.append("The week plan needs at least one day.")
	for stage_index in stages.size():
		var stage := stages[stage_index]
		if stage == null or stage.games.is_empty():
			errors.append("Day %d needs at least one microgame." % (stage_index + 1))
			continue
		for game_index in stage.games.size():
			var game := stage.games[game_index]
			if game == null or game.scene_path.is_empty() or not ResourceLoader.exists(game.scene_path):
				errors.append("Day %d, round %d has no valid scene." % [stage_index + 1, game_index + 1])
	return errors
