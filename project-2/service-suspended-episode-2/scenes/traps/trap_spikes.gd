extends Area2D

@export var cycle_time: float = 0.0  # 0 = always active, >0 = timed on/off

var _active: bool = true

func _ready() -> void:
	collision_layer = 8   # layer 4
	collision_mask = 1    # detect player (layer 1)
	body_entered.connect(_on_body_entered)

	if cycle_time > 0.0:
		_start_cycle()

func _start_cycle() -> void:
	while true:
		await get_tree().create_timer(cycle_time).timeout
		_active = not _active
		monitoring = _active
		$Sprite2D.modulate.a = 1.0 if _active else 0.3

func _on_body_entered(_body: Node2D) -> void:
	if _active:
		GameState.on_player_death()
