extends Area2D

## Map piece pickup. Set piece_id in the editor (1-4).
## All pieces look the same but track which piece they are.

@export var piece_id: int = 1

func _ready() -> void:
	if GameState.has_map_piece(piece_id):
		queue_free()
		return
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		GameState.collect_map_piece(piece_id)
		queue_free()
