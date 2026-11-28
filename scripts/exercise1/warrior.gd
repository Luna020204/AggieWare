extends CharacterBody2D

var is_boss_in_range: bool
var can_move := false

func _ready() -> void:
	is_boss_in_range = false
	can_move = true


func _physics_process(delta: float) -> void:
	var microgame = get_parent().get_parent()
	if Input.is_action_just_pressed("game_mash") and not is_boss_in_range:
		microgame.WarriorSprite.play("Attack")
		microgame.success = false
		microgame._finish_round(false, "STRUCK TOO SOON!")
	if Input.is_action_just_pressed("game_mash") and is_boss_in_range:
		microgame.success = true
		microgame.WarriorSprite.play("Attack")
		microgame.BringerSprite.play("Death")
		microgame._finish_round(true, "BOSS HAS BEEN DEFEATED!")

func _on_win_con_body_entered(body: Node2D) -> void:
	is_boss_in_range = true
