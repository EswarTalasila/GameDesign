extends Node2D

@export var closed_texture: AtlasTexture
@export var open_texture: AtlasTexture
@export var locked: bool = false

var _open: bool = false
var _player_nearby: bool = false

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _body_col: CollisionShape2D = $StaticBody2D/CollisionShape2D
@onready var _prompt: AnimatedSprite2D = $Area2D/PressEPrompt
@onready var _lock_prompt: AnimatedSprite2D = $Area2D/LockPrompt
@onready var _zone_col: CollisionShape2D = $Area2D/CollisionShape2D

func _ready() -> void:
	$Area2D.body_entered.connect(_on_zone_entered)
	$Area2D.body_exited.connect(_on_zone_exited)
	_lock_prompt.visible = false
	_prompt.visible = false

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and _player_nearby:
		if locked:
			if GameState.use_key():
				unlock()
			return
		if _open:
			_close_door()
		else:
			_open_door()

	# Key cursor click-to-unlock
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if locked and _player_nearby and GameState.key_mode:
			if _is_click_on_zone(event):
				if GameState.use_key():
					unlock()
					GameState.set_key_mode(false)

func _is_click_on_zone(event: InputEventMouseButton) -> bool:
	var mouse_world = get_global_mouse_position()
	var zone_pos = $Area2D.global_position + _zone_col.position
	var shape = _zone_col.shape as RectangleShape2D
	var rect = Rect2(zone_pos - shape.size / 2.0, shape.size)
	return rect.has_point(mouse_world)

func _on_zone_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		_player_nearby = true
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

func _open_door() -> void:
	_open = true
	_sprite.texture = open_texture
	_body_col.set_deferred("disabled", true)

func _close_door() -> void:
	_open = false
	_sprite.texture = closed_texture
	_body_col.set_deferred("disabled", false)

func unlock() -> void:
	locked = false
	_lock_prompt.play("opening")
	await _lock_prompt.animation_finished
	_lock_prompt.visible = false
	await get_tree().create_timer(0.3).timeout
	if _player_nearby:
		_prompt.visible = true
