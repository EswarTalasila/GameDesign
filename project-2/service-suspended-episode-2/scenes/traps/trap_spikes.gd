extends Area2D

@export var cycle_time: float = 0.0  # 0 = always active, >0 = timed on/off
@export var peak_frame: int = 2      # frame 2 = atlas (8,4) = fully extended spike
@export var collision_size := Vector2(16, 16)
@export var collision_offset := Vector2(0, 0)

var _active: bool = false
var _player_inside: bool = false
var _player_ref: CharacterBody2D = null

@onready var _col: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	_col.shape = _col.shape.duplicate()
	(_col.shape as RectangleShape2D).size = collision_size
	_col.position = collision_offset
	collision_layer = 8
	collision_mask = 1
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	$AnimatedSprite2D.play("activate")

	# Grace period
	await get_tree().create_timer(1.0).timeout
	_active = true

	if cycle_time > 0.0:
		_start_cycle()

func _physics_process(_delta: float) -> void:
	if not _active or not _player_inside or _player_ref == null:
		return
	if _player_ref.get("_dead"):
		return
	if $AnimatedSprite2D.frame == peak_frame and _player_ref.has_method("take_hit"):
		_player_ref.take_hit(2)

func _start_cycle() -> void:
	while true:
		await get_tree().create_timer(cycle_time).timeout
		_active = not _active
		if _active:
			$AnimatedSprite2D.play("activate")
		else:
			$AnimatedSprite2D.play_backwards("activate")

func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		_player_inside = true
		_player_ref = body

func _on_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		_player_inside = false
		_player_ref = null
