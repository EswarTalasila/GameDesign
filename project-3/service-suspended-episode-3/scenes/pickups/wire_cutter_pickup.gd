extends Area2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player" and not GameState.has_wire_cutter:
		GameState.collect_wire_cutter()
		queue_free()
