extends Area2D

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	collision_layer = 16  # layer 5
	collision_mask = 1    # detect player (layer 1)
	body_entered.connect(_on_body_entered)
	visible = false
	monitoring = false

func appear() -> void:
	visible = true
	sprite.scale = Vector2.ZERO
	var tween = create_tween()
	tween.tween_property(sprite, "scale", Vector2(2, 2), 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func(): monitoring = true)

func _on_body_entered(_body: Node2D) -> void:
	monitoring = false
	GameState.complete_dungeon()

	# Transition via loading screen to next cart
	var loading = preload("res://scenes/ui/loading_screen.tscn").instantiate()
	get_tree().root.add_child(loading)
	loading.transition_to("res://scenes/rooms/train_cart_hub.tscn")
