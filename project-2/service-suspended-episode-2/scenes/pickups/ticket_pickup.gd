extends Area2D

@onready var sprite: Sprite2D = $Sprite2D

var _hover_tween: Tween

func _ready() -> void:
	collision_layer = 4   # layer 3
	collision_mask = 1    # detect player (layer 1)
	body_entered.connect(_on_body_entered)
	_start_hover()

func _start_hover() -> void:
	_hover_tween = create_tween().set_loops()
	_hover_tween.tween_property(sprite, "position:y", -3.0, 0.6).set_trans(Tween.TRANS_SINE)
	_hover_tween.tween_property(sprite, "position:y", 3.0, 0.6).set_trans(Tween.TRANS_SINE)

func _on_body_entered(_body: Node2D) -> void:
	# Disable further collisions
	set_deferred("monitoring", false)
	GameState.collect_ticket()

	# Flash and scale up then free
	var tween = create_tween()
	tween.tween_property(sprite, "scale", Vector2(1.5, 1.5), 0.15)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.15)
	tween.tween_callback(queue_free)
