extends Node2D
class_name GhostHand

@export var open_animation: StringName = &"open"
@export var grab_animation: StringName = &"grab"

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
var _pending_animation: StringName = &"open"
var _pending_flip_h: bool = false

func _ready() -> void:
	_apply_pose()

func set_pose_open() -> void:
	_pending_animation = open_animation
	_pending_flip_h = false
	_apply_pose()

func set_pose_grab(flip_h: bool = false) -> void:
	_pending_animation = grab_animation
	_pending_flip_h = flip_h
	_apply_pose()

func face_point(world_point: Vector2) -> void:
	rotation = (world_point - global_position).angle()

func _apply_pose() -> void:
	if _sprite == null:
		return
	_sprite.play(_pending_animation)
	_sprite.pause()
	_sprite.flip_h = _pending_flip_h
	_sprite.frame = 0
	_sprite.frame_progress = 0.0
