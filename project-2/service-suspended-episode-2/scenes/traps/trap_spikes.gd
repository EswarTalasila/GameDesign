extends Area2D

@export var cycle_time: float = 0.0  # 0 = always active, >0 = timed on/off
@export var peak_frame: int = 2      # frame 2 = atlas (8,0) = fully extended spike

var _active: bool = false
var _player_inside: bool = false
var _killed: bool = false

func _ready() -> void:
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
	if not _active or _killed or not _player_inside:
		return
	if $AnimatedSprite2D.frame == peak_frame:
		_killed = true
		GameState.on_player_death()

func _start_cycle() -> void:
	while true:
		await get_tree().create_timer(cycle_time).timeout
		_active = not _active
		if _active:
			$AnimatedSprite2D.play("activate")
		else:
			$AnimatedSprite2D.play_backwards("activate")

func _on_body_entered(_body: Node2D) -> void:
	_player_inside = true

func _on_body_exited(_body: Node2D) -> void:
	_player_inside = false
