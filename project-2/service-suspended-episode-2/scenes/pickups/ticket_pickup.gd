extends Area2D

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	collision_layer = 4   # layer 3
	collision_mask = 1    # detect player (layer 1)
	body_entered.connect(_on_body_entered)
	_start_glow_pulse()

func _start_glow_pulse() -> void:
	var mat = sprite.material as ShaderMaterial
	if not mat or not mat.get_shader_parameter("glow_enabled"):
		return
	var tween = create_tween().set_loops()
	tween.tween_property(mat, "shader_parameter/glow_alpha", 0.3, 0.8).set_trans(Tween.TRANS_SINE)
	tween.tween_property(mat, "shader_parameter/glow_alpha", 0.7, 0.8).set_trans(Tween.TRANS_SINE)

func _on_body_entered(_body: Node2D) -> void:
	set_deferred("monitoring", false)
	GameState.pickup_ticket()

	# Flash and scale up then free
	var tween = create_tween()
	tween.tween_property(sprite, "scale", Vector2(1.5, 1.5), 0.15)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.15)
	tween.tween_callback(queue_free)
