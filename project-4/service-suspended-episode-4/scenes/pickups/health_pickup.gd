extends Area2D

const PickupSorting = preload("res://scripts/pickup_sorting.gd")

var _pickup_sound = preload("res://assets/sounds/health_pickup.mp3")

@export var persistent_drop_id: String = ""

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	PickupSorting.sync_from_collision(self)
	collision_layer = 4   # layer 3
	collision_mask = 1    # detect player (layer 1)
	body_entered.connect(_on_body_entered)
	_start_glow_pulse()
	_check_overlap.call_deferred()

func _check_overlap() -> void:
	for body in get_overlapping_bodies():
		if body and body.has_method("pickup"):
			_on_body_entered(body)
			return

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

func _on_body_entered(body: Node2D) -> void:
	if body == null or not body.has_method("pickup"):
		return
	if GameState.player_health >= GameState.max_health:
		return
	set_deferred("monitoring", false)
	_play_sfx(_pickup_sound)
	GameState.heal_player(1)
	GameState.remove_jungle_persistent_enemy_drop(persistent_drop_id)

	var tween = create_tween()
	tween.tween_property(sprite, "scale", Vector2(1.5, 1.5), 0.15)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.15)
	tween.tween_callback(queue_free)
