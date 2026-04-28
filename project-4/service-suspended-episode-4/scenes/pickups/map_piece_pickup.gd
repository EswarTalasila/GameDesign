extends Area2D

const PickupSorting = preload("res://scripts/pickup_sorting.gd")

@export_range(1, 4, 1) var piece_id: int = 1

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	PickupSorting.sync_from_collision(self)
	collision_layer = 4
	collision_mask = 1
	if GameState.has_map_piece(piece_id):
		queue_free()
		return
	body_entered.connect(_on_body_entered)
	_check_overlap.call_deferred()

func _check_overlap() -> void:
	for body in get_overlapping_bodies():
		if body and (body.name == "Player" or body.is_in_group("Player")):
			_on_body_entered(body)
			return

func _on_body_entered(body: Node2D) -> void:
	if body == null or (body.name != "Player" and not body.is_in_group("Player")):
		return
	GameState.collect_map_piece(piece_id)
	var collected_count := GameState.collected_map_pieces.size()
	QuestManager.set_progress("find_map_pieces", collected_count, 4)
	if collected_count >= 4 and QuestManager.has_objective("find_map_pieces"):
		QuestManager.complete("find_map_pieces")
		QuestManager.add_sub("talk_cat", "Talk to the cat", "escape")
	set_deferred("monitoring", false)
	var tween := create_tween()
	tween.tween_property(sprite, "scale", Vector2(1.18, 1.18), 0.15)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.15)
	tween.tween_callback(queue_free)
