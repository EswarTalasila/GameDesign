extends Node2D

@export var closed_texture: AtlasTexture
@export var open_texture: AtlasTexture
@export var closed_collision_size := Vector2(20, 16)
@export var closed_collision_offset := Vector2(0, 8)
@export var open_collision_size := Vector2(20, 16)
@export var open_collision_offset := Vector2(0, 8)
@export var interaction_zone_size := Vector2(52, 50)
@export var interaction_zone_offset := Vector2(0, 9)
@export var locked: bool = false

var _open: bool = false
var _player_nearby: bool = false
var _looted: bool = false
var _player_body: CharacterBody2D = null

var _loot_scenes: Array[PackedScene] = [
	preload("res://scenes/pickups/ticket_pickup.tscn"),
	preload("res://scenes/pickups/key_pickup.tscn"),
	preload("res://scenes/pickups/health_pickup.tscn"),
]

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _prompt: AnimatedSprite2D = $Area2D/PressEPrompt
@onready var _lock_prompt: AnimatedSprite2D = $Area2D/LockPrompt
@onready var _body_col: CollisionShape2D = $StaticBody2D/CollisionShape2D
@onready var _zone_col: CollisionShape2D = $Area2D/CollisionShape2D

func _ready() -> void:
	$Area2D.body_entered.connect(_on_zone_entered)
	$Area2D.body_exited.connect(_on_zone_exited)
	(_body_col.shape as RectangleShape2D).size = closed_collision_size
	_body_col.position = closed_collision_offset
	(_zone_col.shape as RectangleShape2D).size = interaction_zone_size
	_zone_col.position = interaction_zone_offset
	_lock_prompt.visible = false
	_prompt.visible = false

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and _player_nearby:
		if locked:
			if GameState.use_key():
				unlock()
			return
		if _open:
			_close_chest()
		else:
			_open_chest()

	# Key cursor click-to-unlock
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if locked and _player_nearby and GameState.key_mode:
			if _is_click_on_zone(event):
				if GameState.use_key():
					unlock()
					GameState.set_key_mode(false)

func _is_click_on_zone(_event: InputEventMouseButton) -> bool:
	var mouse_world = get_global_mouse_position()
	var zone_pos = $Area2D.global_position + _zone_col.position
	var shape = _zone_col.shape as RectangleShape2D
	var rect = Rect2(zone_pos - shape.size / 2.0, shape.size)
	return rect.has_point(mouse_world)

func _on_zone_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		_player_nearby = true
		_player_body = body
		if locked:
			_lock_prompt.visible = true
			_lock_prompt.play("locked")
		else:
			_prompt.visible = true

func _on_zone_exited(body: Node2D) -> void:
	if body is CharacterBody2D:
		_player_nearby = false
		_prompt.visible = false
		_lock_prompt.visible = false

func _open_chest() -> void:
	_open = true
	_sprite.texture = open_texture
	(_body_col.shape as RectangleShape2D).size = open_collision_size
	_body_col.position = open_collision_offset
	if not _looted:
		_looted = true
		_spawn_loot()

func _close_chest() -> void:
	_open = false
	_prompt.visible = true
	_sprite.texture = closed_texture
	(_body_col.shape as RectangleShape2D).size = closed_collision_size
	_body_col.position = closed_collision_offset

func _spawn_loot() -> void:
	var scene = _loot_scenes[randi() % _loot_scenes.size()]
	var item = scene.instantiate()
	get_parent().add_child(item)
	# Spawn toward the player (1 tile in their direction from chest center)
	var dir = (_player_body.global_position - global_position).normalized()
	# Snap to dominant axis for clean tile alignment
	if abs(dir.x) > abs(dir.y):
		dir = Vector2(sign(dir.x), 0)
	else:
		dir = Vector2(0, sign(dir.y))
	item.global_position = global_position + dir * 16.0

func unlock() -> void:
	locked = false
	_lock_prompt.play("opening")
	await _lock_prompt.animation_finished
	_lock_prompt.visible = false
	await get_tree().create_timer(0.3).timeout
	if _player_nearby:
		_prompt.visible = true
