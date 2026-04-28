@tool
extends Area2D

const PickupSorting = preload("res://scripts/pickup_sorting.gd")
const PICKUP_SOUND := preload("res://assets/sounds/key_pickup.mp3")
const PICKUP_FRAME_COUNT := 8
const PICKUP_FRAME_PATH := "res://assets/sprites/stone_puzzle/pickups/%s_stone_pickup_%d.png"
const PIECE_COLORS := {
	"black_1": "black",
	"black_2": "black",
	"red": "red",
	"yellow": "yellow",
	"green": "green",
	"blue": "blue",
	"purple": "purple",
	"white": "white",
}

@export_enum("black_1", "black_2", "red", "yellow", "green", "blue", "purple", "white")
var piece_id: String = "black_1":
	set(value):
		piece_id = value
		_refresh_editor_preview()

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	PickupSorting.sync_from_collision(self)
	if Engine.is_editor_hint():
		_apply_frames()
		return
	collision_layer = 4
	collision_mask = 1
	if (
		GameState.stone_puzzle_solved
		or GameState.has_collected_stone_piece(piece_id)
		or GameState.is_stone_piece_deposited(piece_id)
	):
		queue_free()
		return
	_apply_frames()
	body_entered.connect(_on_body_entered)
	_start_glow_pulse()
	_check_overlap.call_deferred()

func _check_overlap() -> void:
	for body in get_overlapping_bodies():
		if _is_player(body):
			_on_body_entered(body)
			return

func _apply_frames() -> void:
	if sprite == null:
		return
	var color_name := _get_piece_color()
	var frames := SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")
	frames.add_animation("float")
	frames.set_animation_speed("float", 10.0)
	frames.set_animation_loop("float", true)
	for frame_index in range(1, PICKUP_FRAME_COUNT + 1):
		var texture_path := PICKUP_FRAME_PATH % [color_name, frame_index]
		if ResourceLoader.exists(texture_path):
			frames.add_frame("float", load(texture_path))
	sprite.sprite_frames = frames
	sprite.animation = "float"
	sprite.play("float")

func _refresh_editor_preview() -> void:
	if not Engine.is_editor_hint() or not is_node_ready():
		return
	_apply_frames()

func _get_piece_color() -> String:
	return String(PIECE_COLORS.get(piece_id, "black"))

func _start_glow_pulse() -> void:
	var mat := sprite.material as ShaderMaterial
	if not mat or not mat.get_shader_parameter("glow_enabled"):
		return
	var tween := create_tween().set_loops()
	tween.tween_property(mat, "shader_parameter/glow_alpha", 0.28, 0.82).set_trans(Tween.TRANS_SINE)
	tween.tween_property(mat, "shader_parameter/glow_alpha", 0.68, 0.82).set_trans(Tween.TRANS_SINE)

func _play_sfx(stream: AudioStream) -> void:
	var sfx := AudioStreamPlayer.new()
	sfx.stream = stream
	get_tree().root.add_child(sfx)
	sfx.play()
	sfx.finished.connect(sfx.queue_free)

func _on_body_entered(body: Node2D) -> void:
	if not _is_player(body):
		return
	if not GameState.collect_stone_piece(piece_id):
		return
	set_deferred("monitoring", false)
	_play_sfx(PICKUP_SOUND)
	var tween := create_tween()
	tween.tween_property(sprite, "scale", sprite.scale * 1.18, 0.14)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.16)
	tween.tween_callback(queue_free)

func _is_player(body: Node) -> bool:
	return body is CharacterBody2D and (body.name == "Player" or body.is_in_group("Player"))
