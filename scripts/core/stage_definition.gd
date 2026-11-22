@tool
class_name StageDefinition
extends Resource
## A named day can contain one or more rounds without changing the flow code.
@export var title := "DAY"
@export var games: Array[MicrogameDefinition] = []
