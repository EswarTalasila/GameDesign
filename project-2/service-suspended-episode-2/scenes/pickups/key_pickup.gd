extends Area2D

var _pickup_sound = preload("res://assets/sounds/key_pickup.mp3")

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

func _play_sfx(stream: AudioStream) -> void:
	var sfx = AudioStreamPlayer.new()
	sfx.stream = stream
	get_tree().root.add_child(sfx)
	sfx.play()
	sfx.finished.connect(sfx.queue_free)

func _on_body_entered(_body: Node2D) -> void:
	set_deferred("monitoring", false)
	_play_sfx(_pickup_sound)
	GameState.collect_key()

	# Flash and scale up then free
	var tween = create_tween()
	tween.tween_property(sprite, "scale", Vector2(0.55, 0.55), 0.15)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.15)
	tween.tween_callback(queue_free)
