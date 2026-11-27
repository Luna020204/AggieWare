@tool
class_name StageDefinition
extends Resource

@export var title := "DAY"
@export var theme := ""
@export var games: Array[MicrogameDefinition] = []
@export var randomize_games := false
## Zero uses the authored list length (including future additions).
@export_range(0, 100, 1, "or_greater") var required_wins := 0

func win_goal() -> int:
	return required_wins if required_wins > 0 else games.size()

## Exclude the scene itself: two variants may use different IDs for the same game.
func next_game(wins: int, previous_scene: String) -> int:
	if not randomize_games:
		return wins % games.size()
	var candidates: Array[int] = []
	for index in games.size():
		if games[index].scene_path != previous_scene:
			candidates.append(index)
	if candidates.is_empty():
		return randi_range(0, games.size() - 1)
	return candidates.pick_random()
