extends "res://scenes/enemies/sword_enemy.gd"

func _ready() -> void:
	add_to_group("jungle_boss_target")
	super._ready()
	remove_from_group("jungle_hunt_target")
